import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
TEST = ROOT / "tests" / "multiswap" / "test_fmq14_fsi02_admission.py"

result = subprocess.run([sys.executable, str(TEST)], cwd=ROOT)
raise SystemExit(result.returncode)
