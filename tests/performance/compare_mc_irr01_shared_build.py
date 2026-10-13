#!/usr/bin/env python3
"""Compare original root/sensor science gates against combined-build candidate.

No qualification is inherited. All three scientific runs execute afresh.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
ORIGINALS = {
    "root": "tests/f-app07/run_mc_irr01_allocated_root_restart.sh",
    "sensor": "tests/f-app07/run_mc_irr01_allocated_sensor_restart.sh",
}
COMBINED = "tests/performance/run_mc_irr01_shared_build_experiment.sh"

def launch(command, output_directory, label):
    start = time.monotonic()
    p = subprocess.run(["bash", command], cwd=ROOT, capture_output=True)
    elapsed = time.monotonic() - start
    (output_directory / (label + ".stdout")).write_bytes(p.stdout)
    (output_directory / (label + ".stderr")).write_bytes(p.stderr)
    return {"seconds": elapsed, "exit": p.returncode,
            "stdout_sha256": hashlib.sha256(p.stdout).hexdigest(),
            "stderr_sha256": hashlib.sha256(p.stderr).hexdigest(),
            "stdout": p.stdout.decode("utf-8", errors="replace")}

def extract(text, marker):
    found = re.findall(r"(?m)^" + re.escape(marker) + r"=([0-9a-f]{64})$", text)
    if len(found) != 1:
        raise ValueError(f"missing/duplicate {marker}")
    return found[0]

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--output-dir", required=True)
    args = ap.parse_args()
    # Compare one immutable candidate, not two moving working trees.
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    if subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT).strip():
        ap.error("working tree must be clean before the expensive comparison")
    compiler = subprocess.check_output(["gfortran", "--version"], text=True).splitlines()[0]
    destination = Path(args.output_dir).resolve()
    destination.mkdir(parents=True, exist_ok=False)
    result = {"started_utc": datetime.now(timezone.utc).isoformat(),
              "originals": {}, "candidate": None, "equivalent": False,\n              "head": head, "compiler": compiler}
    success = False
    try:
        for case, runner in ORIGINALS.items():
            item = launch(runner, destination, case + "-original")
            result["originals"][case] = {k:v for k,v in item.items() if k != "stdout"}
            if item["exit"] != 0: raise ValueError("original " + case + " failed")
            result["originals"][case]["science_sha256"] = extract(
                item["stdout"], "MC_IRR01_MANAGEMENT_PHYSICAL_SHA256")
        item = launch(COMBINED, destination, "combined")
        result["candidate"] = {k:v for k,v in item.items() if k != "stdout"}
        if item["exit"] != 0: raise ValueError("combined gate failed")
        for case in ORIGINALS:
            actual = extract(item["stdout"], "SHARED_IRR_" + case.upper() + "_SHA256")
            result["candidate"][case + "_science_sha256"] = actual
            if actual != result["originals"][case]["science_sha256"]:
                raise ValueError("science output mismatch for " + case)
        if subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() != head:\n            raise ValueError("HEAD changed during qualification")\n        if subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT).strip():
            raise ValueError("working tree changed during qualification")\n        result["equivalent"] = True
        success = True
    except ValueError as error:
        result["failure"] = str(error)
    finally:
        result["ended_utc"] = datetime.now(timezone.utc).isoformat()
        (destination / "CONTROL.json").write_text(json.dumps(result, sort_keys=True, indent=2) + "\n")
    print("SHARED_IRR_COMPARISON=" + ("PASS" if success else "FAIL"), flush=True)
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
