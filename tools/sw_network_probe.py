#!/usr/bin/env python3
"""Dependency-free IPv4 endpoint checks for issues #8 and #17.

UDP sizes include the 32-byte probe header. A server must echo each datagram
unchanged. This checks the endpoint carrying the traffic; a pass does not prove
that the endpoint uses lwIP or that RF, DMA, or IP forwarding works.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import ipaddress
import json
import math
import os
from pathlib import Path
import platform
import re
import select
import socket
import statistics
import struct
import subprocess
import sys
import time
import uuid


# =============================================================================
# Probe payloads and shared report fields
# =============================================================================

MAGIC = b"CAPUDP01"
HEADER = struct.Struct("!8s16sII")
MAX_DATAGRAM = 65507


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def make_payload(run_id: bytes, sequence: int, size: int) -> bytes:
    """Make reproducible, nonconstant bytes, including run/sequence/length."""
    header = HEADER.pack(MAGIC, run_id, sequence, size)
    return header + hashlib.shake_256(header).digest(size - HEADER.size)


def rtt_summary(samples: list[float]) -> dict:
    if not samples:
        return {"count": 0, "min_ms": None, "mean_ms": None,
                "median_ms": None, "p95_ms": None, "max_ms": None}
    ordered = sorted(samples)
    return {"count": len(samples), "min_ms": min(samples),
            "mean_ms": statistics.mean(samples),
            "median_ms": statistics.median(samples),
            "p95_ms": ordered[math.ceil(len(ordered) * 0.95) - 1],
            "max_ms": max(samples)}


def base_report(kind: str, build_id: str, config_id: str) -> dict:
    return {"schema_version": 1, "kind": kind, "started_utc": utc_now(),
            "build_id": build_id, "config_id": config_id,
            "host_platform": platform.platform(),
            "python_version": platform.python_version()}


# =============================================================================
# Paced UDP echo measurement
# =============================================================================

@dataclass(frozen=True)
class UdpConfig:
    host: str
    port: int = 5001
    count: int = 1000
    sizes: tuple[int, ...] = (64, 512, 1400)
    rate: float = 100.0
    timeout: float = 1.0
    drain: float = 0.2
    bind: str = "0.0.0.0"
    max_loss_fraction: float = 0.0
    max_duplicates: int = 0
    max_out_of_order: int = 0
    build_id: str = "unspecified"
    config_id: str = "unspecified"


def validate_udp(config: UdpConfig) -> None:
    if not 1 <= config.port <= 65535:
        raise ValueError("port must be in 1..65535")
    if not 1 <= config.count <= 2**32:
        raise ValueError("count must be in 1..4294967296")
    if not config.sizes or any(not HEADER.size <= n <= MAX_DATAGRAM
                               for n in config.sizes):
        raise ValueError(f"sizes must be in {HEADER.size}..{MAX_DATAGRAM}")
    for name in ("rate", "timeout", "drain"):
        value = getattr(config, name)
        if not math.isfinite(value) or value <= 0:
            raise ValueError(f"{name} must be finite and positive")
    if not 0 <= config.max_loss_fraction <= 1:
        raise ValueError("max_loss_fraction must be in 0..1")
    if config.max_duplicates < 0 or config.max_out_of_order < 0:
        raise ValueError("duplicate/order thresholds must be nonnegative")
    ipaddress.IPv4Address(config.bind)


def run_udp(config: UdpConfig) -> dict:
    """Send paced probes, accepting unique valid replies until a fixed deadline.

    After the final send, wait at most timeout + drain seconds. If every reply
    arrives sooner, keep receiving for drain seconds to count late duplicates.
    Traffic never extends either deadline. No retransmission is performed.
    """
    validate_udp(config)
    endpoint = (socket.gethostbyname(config.host), config.port)
    run_id = uuid.uuid4().bytes
    report = base_report("udp_echo", config.build_id, config.config_id)
    report.update({"run_id": str(uuid.UUID(bytes=run_id)),
                   "remote": {"requested_host": config.host,
                              "ip": endpoint[0], "port": endpoint[1]},
                   "settings": {"count": config.count,
                                "sizes_bytes": list(config.sizes),
                                "configured_rate_pps": config.rate,
                                "timeout_after_last_send_s": config.timeout,
                                "final_drain_s": config.drain,
                                "bind_address": config.bind,
                                "retransmissions": 0}})
    counters = {name: 0 for name in (
        "sent", "sent_bytes", "received_datagrams", "delivered_unique",
        "delivered_bytes", "duplicates", "corrupt", "out_of_order",
        "unexpected_source", "unexpected_run", "unexpected_sequence",
        "socket_errors")}
    sent: dict[int, tuple[float, int]] = {}
    received: set[int] = set()
    rtts = []
    errors = []
    highest_sequence = -1
    first_send = last_send = None
    completed_at = None
    started = time.monotonic()
    next_send = started
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind((config.bind, 0))
        sock.setblocking(False)
        report["local"] = {"bind_ip": sock.getsockname()[0],
                           "port": sock.getsockname()[1]}
        while True:
            # Send one scheduled probe before draining replies. Missed replies
            # never trigger retransmission or delay the next send.
            now = time.monotonic()
            if counters["sent"] < config.count and now >= next_send:
                seq = counters["sent"]
                size = config.sizes[seq % len(config.sizes)]
                payload = make_payload(run_id, seq, size)
                sent_at = time.monotonic()
                try:
                    written = sock.sendto(payload, endpoint)
                    if written != len(payload):
                        raise OSError("partial UDP send")
                except OSError as exc:
                    counters["socket_errors"] += 1
                    errors.append(str(exc))
                    break
                sent[seq] = (sent_at, size)
                if first_send is None:
                    first_send = sent_at
                last_send = sent_at
                counters["sent"] += 1
                counters["sent_bytes"] += size
                next_send += 1 / config.rate

            now = time.monotonic()
            if counters["sent"] == config.count:
                deadline = last_send + config.timeout + config.drain
                if completed_at is not None:
                    deadline = min(deadline, completed_at + config.drain)
                if now >= deadline:
                    break
                wait = deadline - now
            else:
                wait = max(0, next_send - now)
            readable, _, _ = select.select([sock], [], [], wait)
            if not readable:
                continue
            # Bound work per iteration so a noisy peer cannot starve sending or
            # prevent the fixed receive deadline from being checked.
            for _ in range(256):
                try:
                    data, source = sock.recvfrom(65535)
                except BlockingIOError:
                    break
                except OSError as exc:
                    counters["socket_errors"] += 1
                    if len(errors) < 20:
                        errors.append(str(exc))
                    break
                arrived_at = time.monotonic()
                counters["received_datagrams"] += 1
                if source != endpoint:
                    counters["unexpected_source"] += 1
                    continue
                if len(data) < HEADER.size:
                    counters["corrupt"] += 1
                    continue
                magic, incoming_run, seq, size = HEADER.unpack_from(data)
                if magic != MAGIC:
                    counters["corrupt"] += 1
                    continue
                if incoming_run != run_id:
                    counters["unexpected_run"] += 1
                    continue
                if seq not in sent:
                    counters["unexpected_sequence"] += 1
                    continue
                sent_at, expected_size = sent[seq]
                if size != expected_size or data != make_payload(
                        run_id, seq, expected_size):
                    counters["corrupt"] += 1
                    continue
                # Validate before duplicate accounting: a corrupt copy of an
                # already delivered sequence must still fail integrity checks.
                if seq in received:
                    counters["duplicates"] += 1
                    continue
                if seq < highest_sequence:
                    counters["out_of_order"] += 1
                highest_sequence = max(highest_sequence, seq)
                received.add(seq)
                counters["delivered_unique"] += 1
                counters["delivered_bytes"] += len(data)
                rtts.append((arrived_at - sent_at) * 1000)
                if len(received) == config.count:
                    completed_at = arrived_at

    duration = time.monotonic() - started
    missing = sorted(set(sent) - received)
    counters["missing"] = len(missing)
    counters["not_sent"] = config.count - counters["sent"]
    loss = len(missing) / counters["sent"] if counters["sent"] else 1.0
    send_span = last_send - first_send if first_send is not None else 0.0
    observed_send_rate = (counters["sent"] - 1) / send_span if send_span else None
    gates = {"all_probes_sent": counters["not_sent"] == 0,
             "loss": loss <= config.max_loss_fraction,
             "integrity": counters["corrupt"] == 0,
             "duplicates": counters["duplicates"] <= config.max_duplicates,
             "order": counters["out_of_order"] <= config.max_out_of_order,
             "expected_traffic": not any(counters[k] for k in (
                 "unexpected_source", "unexpected_run", "unexpected_sequence")),
             "socket_errors": counters["socket_errors"] == 0}
    report.update({"finished_utc": utc_now(), "duration_s": duration,
                   "send_span_s": send_span,
                   "observed_send_rate_pps": observed_send_rate,
                   "delivered_goodput_bps": counters["delivered_bytes"] * 8 / duration,
                   "counters": counters, "loss_fraction": loss,
                   "missing_sequences": missing,
                   "rtt": rtt_summary(rtts), "errors": errors,
                   "thresholds": {"max_loss_fraction": config.max_loss_fraction,
                                  "max_duplicates": config.max_duplicates,
                                  "max_out_of_order": config.max_out_of_order,
                                  "max_corrupt": 0,
                                  "max_unexpected_traffic": 0},
                   "gates": gates, "passed": all(gates.values())})
    return report


# =============================================================================
# Optional echo server and system ping measurement
# =============================================================================

def serve(bind: str, port: int, max_packets: int = 0) -> None:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind((bind, port))
        print(json.dumps({"listening": sock.getsockname()}), flush=True)
        count = 0
        while not max_packets or count < max_packets:
            data, source = sock.recvfrom(65535)
            sock.sendto(data, source)
            count += 1


def parse_ping_reply(output: str, address: str) -> tuple[float, bool] | None:
    """Require a TTL reply from the requested IPv4 endpoint, not a summary.

    Windows can return exit status zero for destination-unreachable responses.
    Those lines do not contain TTL and cannot count as successful echoes.
    """
    for line in output.splitlines():
        if not re.search(r"\bttl[= ]\d+\b", line, re.IGNORECASE):
            continue
        if address not in re.findall(r"\b\d+\.\d+\.\d+\.\d+\b", line):
            continue
        match = re.search(r"([=<])\s*(\d+(?:[.,]\d+)?)\s*ms\b", line)
        if match:
            return float(match.group(2).replace(",", ".")), match.group(1) == "<"
    return None


def run_icmp(args: argparse.Namespace) -> dict:
    address = socket.gethostbyname(args.host)
    windows = platform.system() == "Windows"
    if platform.system() not in ("Windows", "Linux"):
        raise ValueError("icmp supports Windows and Linux ping")
    report = base_report("icmp_echo", args.build_id, args.config_id)
    report.update({"remote": {"requested_host": args.host, "ip": address},
                   "settings": {"count": args.count, "warmup": args.warmup,
                                "interval_s": args.interval,
                                "timeout_s": args.timeout, "bind": args.bind}})
    if windows:
        command = ["ping", "-4", "-n", "1", "-w", str(math.ceil(args.timeout * 1000))]
        if args.bind:
            command += ["-S", args.bind]
    else:
        command = ["ping", "-4", "-n", "-c", "1", "-W", str(math.ceil(args.timeout))]
        if args.bind:
            command += ["-I", args.bind]
    command.append(address)
    report["command_per_request"] = command
    environment = dict(os.environ, LC_ALL="C")
    samples, warmup, rtts, errors = [], [], [], []
    started = time.monotonic()
    for index in range(-args.warmup, args.count):
        request_started = time.monotonic()
        try:
            result = subprocess.run(command, capture_output=True, text=True,
                                    errors="replace", env=environment,
                                    timeout=math.ceil(args.timeout) + 5,
                                    check=False)
            parsed = parse_ping_reply(result.stdout, address)
            ok = result.returncode == 0 and parsed is not None
            sample = {"sequence": index, "reply": ok,
                      "rtt_ms": parsed[0] if ok else None,
                      "rtt_is_upper_bound": parsed[1] if ok else False,
                      "returncode": result.returncode}
            if not ok:
                sample["output"] = (result.stdout + result.stderr).strip()
        except (OSError, subprocess.TimeoutExpired) as exc:
            errors.append(str(exc))
            sample = {"sequence": index, "reply": False, "rtt_ms": None,
                      "error": str(exc)}
        if index < 0:
            warmup.append(sample)
        else:
            samples.append(sample)
            if sample["reply"]:
                rtts.append(sample["rtt_ms"])
        if index != args.count - 1:
            time.sleep(max(0, args.interval - (time.monotonic() - request_started)))
    loss = (args.count - len(rtts)) / args.count
    gates = {"loss": loss <= args.max_loss_fraction,
             "tool_errors": len(errors) == 0}
    report.update({"finished_utc": utc_now(),
                   "duration_s": time.monotonic() - started,
                   "counters": {"sent": args.count, "replies": len(rtts),
                                "missing": args.count - len(rtts),
                                "tool_errors": len(errors)},
                   "warmup_results": warmup, "samples": samples,
                   "rtt": rtt_summary(rtts), "loss_fraction": loss,
                   "thresholds": {"max_loss_fraction": args.max_loss_fraction},
                   "errors": errors, "gates": gates,
                   "passed": all(gates.values())})
    return report


# =============================================================================
# Command-line validation and JSON output
# =============================================================================

def positive_float(value: str) -> float:
    result = float(value)
    if not math.isfinite(result) or result <= 0:
        raise argparse.ArgumentTypeError("must be finite and positive")
    return result


def positive_int(value: str) -> int:
    result = int(value)
    if result <= 0:
        raise argparse.ArgumentTypeError("must be positive")
    return result


def nonnegative_int(value: str) -> int:
    result = int(value)
    if result < 0:
        raise argparse.ArgumentTypeError("must be nonnegative")
    return result


def fraction(value: str) -> float:
    result = float(value)
    if not 0 <= result <= 1:
        raise argparse.ArgumentTypeError("must be in 0..1")
    return result


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    commands = result.add_subparsers(dest="command", required=True)
    udp = commands.add_parser("udp", help="Send sequenced UDP probes to an echo server")
    icmp = commands.add_parser("icmp", help="Count individual ping requests and replies")
    for child in (udp, icmp):
        child.add_argument("--host", required=True)
        child.add_argument("--count", type=positive_int, default=1000)
        child.add_argument("--timeout", type=positive_float, default=1.0)
        child.add_argument("--build-id", default="unspecified")
        child.add_argument("--config-id", default="unspecified")
        child.add_argument("--max-loss-fraction", type=fraction, default=0.0)
        child.add_argument("--output", type=Path, help="Write JSON here; otherwise print JSON")
    udp.add_argument("--port", type=positive_int, default=5001)
    udp.add_argument("--sizes", type=positive_int, nargs="+", default=[64, 512, 1400],
                     help="Total UDP payload sizes, including 32-byte header; cycled per probe")
    udp.add_argument("--rate", type=positive_float, default=100.0, help="Offered datagrams/second")
    udp.add_argument("--drain", type=positive_float, default=0.2,
                     help="Fixed final receive interval to count late duplicate replies")
    udp.add_argument("--bind", default="0.0.0.0", help="Local IPv4 address")
    udp.add_argument("--max-duplicates", type=nonnegative_int, default=0)
    udp.add_argument("--max-out-of-order", type=nonnegative_int, default=0)
    icmp.add_argument("--warmup", type=nonnegative_int, default=2,
                      help="Excluded ARP warm-up requests")
    icmp.add_argument("--interval", type=positive_float, default=0.02,
                      help="Minimum start-to-start spacing; ping process cost may dominate")
    icmp.add_argument("--bind", help="Local IPv4 address")
    server = commands.add_parser("serve", help="Run a UDP echo server; Ctrl+C stops it")
    server.add_argument("--bind", default="127.0.0.1")
    server.add_argument("--port", type=positive_int, default=5001)
    server.add_argument("--max-packets", type=nonnegative_int, default=0,
                        help="Exit after this many packets; zero runs until interrupted")
    sha = commands.add_parser("sha256", help="Hash files for evidence and payload checks")
    sha.add_argument("files", type=Path, nargs="+")
    return result


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        if args.command == "serve":
            serve(args.bind, args.port, args.max_packets)
            return 0
        if args.command == "sha256":
            for path in args.files:
                digest = hashlib.sha256()
                with path.open("rb") as source:
                    for chunk in iter(lambda: source.read(1024 * 1024), b""):
                        digest.update(chunk)
                print(json.dumps({"path": str(path), "sha256": digest.hexdigest()}))
            return 0
        if args.command == "udp":
            settings = {key: value for key, value in vars(args).items()
                        if key not in ("command", "output")}
            settings["sizes"] = tuple(settings["sizes"])
            report = run_udp(UdpConfig(**settings))
        else:
            report = run_icmp(args)
    except (OSError, ValueError) as exc:
        report = {"schema_version": 1, "kind": args.command,
                  "finished_utc": utc_now(), "passed": False, "error": str(exc)}
        if args.command in ("serve", "sha256"):
            print(json.dumps(report), file=sys.stderr)
            return 2
    except KeyboardInterrupt:
        return 130
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"output": str(args.output), "passed": report["passed"],
                          "counters": report.get("counters"),
                          "error": report.get("error")}))
    else:
        print(json.dumps(report, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
