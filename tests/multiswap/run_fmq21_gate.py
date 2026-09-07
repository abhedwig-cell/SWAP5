#!/usr/bin/env python3
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
TEST = ROOT / "tests/multiswap/test_fmq21_fsi06_fvq12_ownership_admission.py"
raise SystemExit(subprocess.call([sys.executable, str(TEST)]))
