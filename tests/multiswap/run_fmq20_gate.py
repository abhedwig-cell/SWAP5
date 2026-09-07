import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
TEST = ROOT / "tests/multiswap/test_fmq20_fkt05_reusable_checkpoint_admission.py"
raise SystemExit(subprocess.call([sys.executable, str(TEST)]))
