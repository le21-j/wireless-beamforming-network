#!/usr/bin/env python3
"""Run the three standalone AirComp reference testbenches with Icarus Verilog."""

import argparse
from pathlib import Path
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
CASES = ("route_b_sync", "tx_window_sched", "tx_player")


# =============================================================================
# Compile and run each reference with its matching testbench
# =============================================================================

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--iverilog", default="iverilog", help="Icarus compiler name or path")
    parser.add_argument("--vvp", default="vvp", help="Icarus simulator name or path")
    parser.add_argument("--timeout", type=int, default=30, help="Seconds allowed per command")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    output = ROOT / "build" / "aircomp_references"
    output.mkdir(parents=True, exist_ok=True)
    try:
        for name in CASES:
            top = "tb_" + name
            image = output / (name + ".vvp")
            subprocess.run(
                [args.iverilog, "-g2012", "-s", top, "-o", str(image),
                 str(HERE / "rtl" / ("hw_" + name + ".sv")),
                 str(HERE / "tb" / ("hw_" + top + ".sv"))],
                check=True, timeout=args.timeout,
            )
            result = subprocess.run([args.vvp, str(image)], check=True,
                                    capture_output=True, text=True, timeout=args.timeout)
            text = result.stdout + result.stderr
            print(text, end="" if text.endswith("\n") else "\n")
            # These historical benches can call $finish after a failed check.
            # A zero simulator exit code alone is therefore insufficient.
            if top + " OK" not in text or re.search(r"\b(?:FAIL|FAILED|FATAL|ERROR)\b", text):
                raise RuntimeError(top + " did not pass all checks")
    except (OSError, subprocess.SubprocessError, RuntimeError) as error:
        print(str(error), file=sys.stderr)
        return 1
    print("All 3 AirComp reference simulations passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
