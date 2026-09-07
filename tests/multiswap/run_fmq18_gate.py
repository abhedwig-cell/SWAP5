import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
TEST = ROOT / "tests/multiswap/test_fmq18_fsi04_real_headcalc_admission.py"
raise SystemExit(subprocess.call([sys.executable, str(TEST)]))
