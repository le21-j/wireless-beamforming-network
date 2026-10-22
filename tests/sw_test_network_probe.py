"""Deterministic localhost fault tests. No board or third-party packages needed."""

from contextlib import contextmanager
from dataclasses import replace
import io
from contextlib import redirect_stdout
import json
import socket
import tempfile
import threading
import time
from pathlib import Path
import unittest

from tools import sw_network_probe as probe


@contextmanager
def echo_peer(handler):
    errors = []
    stop = threading.Event()
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as server:
        server.bind(("127.0.0.1", 0))
        server.settimeout(0.05)

        def worker():
            while not stop.is_set():
                try:
                    data, source = server.recvfrom(65535)
                except socket.timeout:
                    continue
                try:
                    handler(server, data, source)
                except BaseException as exc:
                    errors.append(exc)
                    break

        thread = threading.Thread(target=worker, daemon=True)
        thread.start()
        try:
            yield server.getsockname()[1]
        finally:
            stop.set()
            thread.join(2)
            if thread.is_alive():
                raise AssertionError("echo peer failed to stop")
            if errors:
                raise errors[0]


class UdpTests(unittest.TestCase):
    def config(self, port, **changes):
        return replace(probe.UdpConfig(
            host="127.0.0.1", port=port, count=6,
            sizes=(32, 64, 511, 1400), rate=200,
            timeout=0.1, drain=0.1, build_id="unit-build",
            config_id="localhost"), **changes)

    def test_echo_size_boundaries_and_report(self):
        with echo_peer(lambda server, data, source: server.sendto(data, source)) as port:
            report = probe.run_udp(self.config(port))
        self.assertTrue(report["passed"], report)
        self.assertEqual(report["counters"]["delivered_unique"], 6)
        self.assertEqual(report["counters"]["sent_bytes"], 32 + 64 + 511 + 1400 + 32 + 64)
        self.assertEqual(report["counters"]["missing"], 0)
        self.assertEqual(report["rtt"]["count"], 6)
        self.assertEqual(report["build_id"], "unit-build")
        self.assertEqual(report["config_id"], "localhost")
        self.assertIn("+00:00", report["started_utc"])
        self.assertEqual(len(report["run_id"]), 36)

    def test_drops_and_corruption_cannot_pass(self):
        def fault(server, data, source):
            seq = probe.HEADER.unpack_from(data)[2]
            if seq == 1:
                return
            if seq == 2:
                data = data[:-1] + bytes([data[-1] ^ 1])
            server.sendto(data, source)
        with echo_peer(fault) as port:
            report = probe.run_udp(self.config(port))
        self.assertFalse(report["passed"])
        self.assertEqual(report["missing_sequences"], [1, 2])
        self.assertEqual(report["counters"]["corrupt"], 1)
        self.assertEqual(report["counters"]["delivered_unique"], 4)

    def test_corrupt_copy_does_not_count_as_valid_duplicate(self):
        def fault(server, data, source):
            server.sendto(data, source)
            server.sendto(data[:-1] + bytes([data[-1] ^ 1]), source)
        with echo_peer(fault) as port:
            report = probe.run_udp(self.config(port, sizes=(64,), count=1))
        self.assertFalse(report["passed"])
        self.assertEqual(report["counters"]["delivered_unique"], 1)
        self.assertEqual(report["counters"]["duplicates"], 0)
        self.assertEqual(report["counters"]["corrupt"], 1)

    def test_corrupt_first_then_valid_is_one_delivery(self):
        def fault(server, data, source):
            server.sendto(data[:-1] + bytes([data[-1] ^ 1]), source)
            server.sendto(data, source)
        with echo_peer(fault) as port:
            report = probe.run_udp(self.config(port, sizes=(64,), count=1))
        self.assertFalse(report["passed"])
        self.assertEqual(report["counters"]["delivered_unique"], 1)
        self.assertEqual(report["counters"]["duplicates"], 0)
        self.assertEqual(report["counters"]["missing"], 0)
        self.assertFalse(report["gates"]["integrity"])

    def test_reordering_and_duplicate_accounting(self):
        held = []
        def fault(server, data, source):
            seq = probe.HEADER.unpack_from(data)[2]
            if seq == 0:
                held.append(data)
            else:
                server.sendto(data, source)
                if seq == 1:
                    server.sendto(held.pop(), source)
                    server.sendto(data, source)
        with echo_peer(fault) as port:
            report = probe.run_udp(self.config(port))
        self.assertFalse(report["passed"])
        self.assertEqual(report["counters"]["missing"], 0)
        self.assertEqual(report["counters"]["out_of_order"], 1)
        self.assertEqual(report["counters"]["duplicates"], 1)

    def test_final_drain_counts_late_duplicate_without_hanging(self):
        def fault(server, data, source):
            server.sendto(data, source)
            time.sleep(0.03)
            server.sendto(data, source)
        started = time.monotonic()
        with echo_peer(fault) as port:
            report = probe.run_udp(self.config(port, count=1))
        self.assertLess(time.monotonic() - started, 2)
        self.assertEqual(report["counters"]["duplicates"], 1)
        self.assertFalse(report["passed"])

    def test_unexpected_source_and_run_cannot_count_delivered(self):
        def fault(server, data, source):
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as stranger:
                stranger.sendto(data, source)
            magic, run, seq, size = probe.HEADER.unpack_from(data)
            other_run = bytes([run[0] ^ 1]) + run[1:]
            server.sendto(probe.make_payload(other_run, seq, size), source)
        with echo_peer(fault) as port:
            report = probe.run_udp(self.config(port, count=1))
        self.assertFalse(report["passed"])
        self.assertEqual(report["counters"]["delivered_unique"], 0)
        self.assertEqual(report["counters"]["unexpected_source"], 1)
        self.assertEqual(report["counters"]["unexpected_run"], 1)

    def test_explicit_loss_threshold(self):
        def drop(server, data, source):
            if probe.HEADER.unpack_from(data)[2] != 0:
                server.sendto(data, source)
        with echo_peer(drop) as port:
            report = probe.run_udp(self.config(port, count=4, max_loss_fraction=0.25))
        self.assertTrue(report["passed"])
        self.assertEqual(report["loss_fraction"], 0.25)

    def test_cli_failure_writes_report_and_returns_nonzero(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "failure.json"
            with echo_peer(lambda *_: None) as port, redirect_stdout(io.StringIO()):
                status = probe.main([
                    "udp", "--host", "127.0.0.1", "--port", str(port),
                    "--count", "1", "--timeout", "0.02", "--drain", "0.02",
                    "--output", str(destination)])
            self.assertEqual(status, 1)
            saved = json.loads(destination.read_text(encoding="utf-8"))
            self.assertFalse(saved["passed"])
            self.assertEqual(saved["counters"]["missing"], 1)

    def test_invalid_sizes_and_nonfinite_rates_are_rejected(self):
        for changes in ({"sizes": (31,)}, {"sizes": (65508,)},
                        {"rate": float("nan")}, {"timeout": -1}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                probe.validate_udp(self.config(5001, **changes))


class IcmpParsingTests(unittest.TestCase):
    def test_windows_and_linux_replies(self):
        self.assertEqual(probe.parse_ping_reply(
            "Reply from 192.168.7.7: bytes=32 time<1ms TTL=64", "192.168.7.7"),
            (1.0, True))
        self.assertEqual(probe.parse_ping_reply(
            "64 bytes from 192.168.7.7: icmp_seq=1 ttl=64 time=0.123 ms",
            "192.168.7.7"), (0.123, False))

    def test_unreachable_or_wrong_source_is_not_a_reply(self):
        self.assertIsNone(probe.parse_ping_reply(
            "Reply from 192.168.7.1: Destination host unreachable.\n"
            "Packets: Sent = 1, Received = 1, Lost = 0 (0% loss)", "192.168.7.7"))
        self.assertIsNone(probe.parse_ping_reply(
            "Reply from 192.168.7.70: bytes=32 time=1ms TTL=64", "192.168.7.7"))


if __name__ == "__main__":
    unittest.main()
