#!/usr/bin/env python3
"""Regression probes for the independently evaluated HYD/PDI oracle.
These probes must fail BEFORE any PASS marker can be printed.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

CHECKER = Path(__file__).with_name("check_b111_hydraulic_families.py")

def rejected(label, payload, diagnostic):
    with tempfile.TemporaryDirectory(prefix="sw431-hyd-oracle-") as folder:
        candidate = Path(folder) / "model_output.txt"
        candidate.write_text(payload, encoding="utf-8")
        run = subprocess.run([sys.executable, str(CHECKER), str(candidate)],
                             capture_output=True, text=True, check=False)
        captured = run.stdout + run.stderr
        if run.returncode == 0 or diagnostic not in captured:
            raise AssertionError(
                f"{label}: expected rejection '{diagnostic}', "
                f"rc={run.returncode}, output={captured!r}"
            )
        if "B111_HYDRAULIC_FAMILIES_ORACLE=PASS" in captured or "B111_PDI_VAPOR_SW009_ORACLE=PASS" in captured:
            raise AssertionError(f"{label}: oracle printed an unearned PASS marker")

rejected("empty output", "", "incomplete or reordered hydraulic family coverage")
rejected("blank output", "\n\n", "incomplete or reordered hydraulic family coverage")
rejected("nan theta", "1 -100 NaN 1.25 0.005 0\n", "non-finite hydraulic output")
rejected("infinite K", "1 -100 0.25 Infinity 0.005 0\n", "non-finite hydraulic output")
rejected("absent model", "1 -100 0.25 1.25 0.005 0\n", "incomplete or reordered hydraulic family coverage")
print("SW431_HYD_ORACLE_FAIL_CLOSED=PASS")
