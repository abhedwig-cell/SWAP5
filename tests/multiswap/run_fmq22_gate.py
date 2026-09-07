#!/usr/bin/env python3
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
TEST = ROOT / "tests/multiswap/test_fmq22_fkt06_p14_admission.py"
raise SystemExit(subprocess.call([sys.executable, str(TEST)]))
