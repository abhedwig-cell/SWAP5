#!/usr/bin/env python3
"""Run a supplied, verified SWAP 4.3.1 executable with an existing case directory.

The caller supplies both executable and real legacy case. No synthetic inputs,
no parameter tweaks, no silent run-as-success. Invokes the executable with
the case directory as cwd; optional positional arguments for the exact
documented invocation. Timeout and output are captured for reproducibility.

Example:
python3 run_legacy.py --exe /opt/swap/swap --case-dir /data/kalmthout/swap431 \
    --log-dir /data/kalmthout/runs/one-day --timeout 3600
"""
import argparse
import hashlib
import json
import pathlib
import subprocess
import sys
import time
from datetime import datetime, timezone

def sha(p):
    h = hashlib.sha256()
    with p.open("rb") as f:
        for b in iter(lambda: f.read(1024 * 1024), b""):
            h.update(b)
    return h.hexdigest()

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--exe", type=pathlib.Path, required=True)
    p.add_argument("--case-dir", type=pathlib.Path, required=True)
    p.add_argument("--log-dir", type=pathlib.Path, required=True)
    p.add_argument("--timeout", type=int, default=3600)
    p.add_argument("arguments", nargs="*")
    a = p.parse_args()
    exe = a.exe.resolve()
    case = a.case_dir.resolve()
    if not exe.is_file() or not case.is_dir():
        p.error("Executable or case directory does not exist")
    if a.timeout < 1:
        p.error("timeout must be positive")
    files = sorted(x for x in case.rglob("*") if x.is_file())
    if not files:
        p.error("case directory has no files")
    logs = a.log_dir.resolve()
    if logs == case or case in logs.parents:
        p.error("log directory must be outside case directory to preserve input inventory")
    logs.mkdir(parents=True, exist_ok=True)
    manifest = {
        "model": "SWAP4.3.1", "status": "STARTED", "verified_b0": False,
        "executable": str(exe), "executable_sha256": sha(exe),
        "case_directory": str(case),
        "input_inventory": [{"path": str(f.relative_to(case)), "sha256": sha(f)} for f in files],
        "arguments": a.arguments,
        "start_utc": datetime.now(timezone.utc).isoformat(),
    }
    start = time.monotonic()
    try:
        with (logs / "stdout.log").open("wb") as out, (logs / "stderr.log").open("wb") as err:
            cp = subprocess.run([str(exe), *a.arguments], cwd=case, stdout=out,
                                stderr=err, timeout=a.timeout, check=False)
        manifest["exit_code"] = cp.returncode
        manifest["status"] = "PROCESS_EXIT_0_NOT_PHYSICALLY_QUALIFIED" if cp.returncode == 0 else "PROCESS_FAILED"
    except subprocess.TimeoutExpired:
        manifest["status"] = "TIMEOUT"
        manifest["exit_code"] = None
    except OSError as e:
        manifest["status"] = "EXECUTION_ERROR"
        manifest["error"] = str(e)
        manifest["exit_code"] = None
    finally:
        manifest["elapsed_seconds"] = round(time.monotonic() - start, 3)
        manifest["end_utc"] = datetime.now(timezone.utc).isoformat()
        manifest["output_inventory"] = [{"path": str(f.relative_to(case)), "sha256": sha(f)}
                                        for f in sorted(case.rglob("*")) if f.is_file()]
        (logs / "run_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        print(json.dumps({k: manifest[k] for k in ("status", "exit_code", "elapsed_seconds")}, indent=2))
    return 0 if manifest["status"].startswith("PROCESS_EXIT_0") else 1

if __name__ == "__main__":
    sys.exit(main())
