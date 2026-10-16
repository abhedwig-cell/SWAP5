"""Bounded B19 preservation on a committed MIGMAC10 merge, not B19 readmission."""
import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
CANONICAL = "78acf56f931763d2e1d4924b3dea0742f231d2e8"
p = argparse.ArgumentParser()
p.add_argument("--build", type=Path, required=True)
args = p.parse_args()
assert not subprocess.check_output(["git", "diff", "HEAD", "--", "src", "tests/frost"], cwd=ROOT)
for name in ["tests/frost/test_ppa_wu05b19_divdra_runtime.f90",
             "tests/frost/build_ppa_wu05b19_runtime.py",
             "src/process/mod_frost_divdra_drainage_effect.f90"]:
    assert (ROOT / name).read_bytes() == subprocess.check_output(["git", "show", CANONICAL + ":" + name], cwd=ROOT)
source = subprocess.check_output(["git", "rev-parse", "HEAD:src"], cwd=ROOT, text=True).strip()
receipts = []
def run(item):
    opt, case = item
    exe = args.build / f"o{opt}" / "test"
    result = subprocess.run([str(exe), str(case), "8192"], capture_output=True)
    stem = args.build / f"o{opt}" / f"migmac10-case-{case}"
    stem.with_suffix(".log").write_bytes(result.stdout)
    stem.with_suffix(".err").write_bytes(result.stderr)
    receipt = dict(optimization=opt, case=case, fine_steps=8192, source_tree=source,
                   exit_code=result.returncode, executable_sha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
                   stdout_sha256=hashlib.sha256(result.stdout).hexdigest())
    stem.with_suffix(".json").write_text(json.dumps(receipt, indent=2) + "\n")
    assert result.returncode == 0, receipt
    assert f"B19_CASE_{case}_RUNTIME=PASS".encode() in result.stdout
    assert b"B19_APPLICATION=PASS" in result.stdout
    assert result.stdout.count(b"B19_FINE_COMPARISON") == 1
    print(f"MIGMAC10_B19_O{opt}_CASE_{case}=PASS", flush=True)
    return receipt
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    receipts = list(pool.map(run, [(o, c) for o in (0, 2) for c in range(1, 25)]))
for case in range(1, 25):
    assert (args.build / "o0" / f"migmac10-case-{case}.log").read_bytes() == (args.build / "o2" / f"migmac10-case-{case}.log").read_bytes()
(args.build / "migmac10-preservation.json").write_text(json.dumps(receipts, indent=2) + "\n")
print("MIGMAC10_B19_24_CASES_O0_O2_IDENTITY=PASS", flush=True)
