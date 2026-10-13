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
import os
import platform
import resource
import shutil
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
ORIGINALS = {
    "root": "tests/f-app07/run_mc_irr01_allocated_root_restart.sh",
    "sensor": "tests/f-app07/run_mc_irr01_allocated_sensor_restart.sh",
}
COMBINED = "tests/performance/run_mc_irr01_shared_build_experiment.sh"

def launch(command, output_directory, label, env=None):
    before = resource.getrusage(resource.RUSAGE_CHILDREN)
    start = time.monotonic()
    p = subprocess.run(["bash", command], cwd=ROOT, capture_output=True, env=env)
    elapsed = time.monotonic() - start
    (output_directory / (label + ".stdout")).write_bytes(p.stdout)
    (output_directory / (label + ".stderr")).write_bytes(p.stderr)
    after = resource.getrusage(resource.RUSAGE_CHILDREN)
    return {"seconds": elapsed, "exit": p.returncode,
            "user_cpu_seconds": after.ru_utime - before.ru_utime,
            "system_cpu_seconds": after.ru_stime - before.ru_stime,
            "stdout_sha256": hashlib.sha256(p.stdout).hexdigest(),
            "stderr_sha256": hashlib.sha256(p.stderr).hexdigest(),
            "stdout": p.stdout.decode("utf-8", errors="replace")}

def extract(text, marker):
    found = re.findall(r"(?m)^" + re.escape(marker) + r"=([0-9a-f]{64})$", text)
    if len(found) != 1:
        raise ValueError(f"missing/duplicate {marker}")
    return found[0]

def verify_science(arms):
    for case in ORIGINALS:
        if arms['combined'][case+'_science_sha256'] != arms[case]['science_sha256']:
            raise ValueError('science output mismatch for '+case)


def native(executable, output, count=3):
    records = []
    for repeat in range(count):
        before = resource.getrusage(resource.RUSAGE_CHILDREN)
        start = time.monotonic()
        p = subprocess.run([str(executable)], cwd=ROOT, capture_output=True)
        elapsed = time.monotonic() - start
        after = resource.getrusage(resource.RUSAGE_CHILDREN)
        (output / (executable.name + f".native-{repeat}.stdout")).write_bytes(p.stdout)
        (output / (executable.name + f".native-{repeat}.stderr")).write_bytes(p.stderr)
        if p.returncode:
            raise ValueError("native run failed")
        records.append({"seconds": elapsed, "user_cpu_seconds": after.ru_utime-before.ru_utime,
                        "system_cpu_seconds": after.ru_stime-before.ru_stime,
                        "stdout_sha256": hashlib.sha256(p.stdout).hexdigest()})
    return records


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--output-dir", required=True)
    ap.add_argument("--repeat", type=int, default=3)
    ap.add_argument("--instrument", action="store_true")
    args = ap.parse_args()
    if args.repeat < 1:
        ap.error("repeat must be positive")
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    def unchanged():
        if subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() != head:
            raise ValueError("HEAD changed during qualification")
        if subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT).strip():
            raise ValueError("working tree changed during qualification")
    unchanged()
    compiler = shutil.which("gfortran")
    compiler_version = subprocess.check_output([compiler, "--version"], text=True).splitlines()[0]
    destination = Path(args.output_dir).resolve()
    destination.mkdir(parents=True, exist_ok=False)
    # Pin full source discovery, fixtures, toolchain files, flags and environment.
    from importlib.util import spec_from_file_location, module_from_spec
    spec = spec_from_file_location("build_identity", ROOT / "tools/performance/irrigation_build_identity.py")
    identity = module_from_spec(spec); spec.loader.exec_module(identity)
    inputs = identity.snapshot()
    (destination / "INPUTS.json").write_text(json.dumps(inputs, sort_keys=True, indent=2)+"\n")
    compiler_paths = [Path(compiler).resolve()]
    for query in ("f951", "as", "cc1", "collect2", "ld"):
        value = subprocess.check_output([compiler, "-print-prog-name="+query], text=True).strip()
        path = Path(value) if "/" in value else Path(shutil.which(value) or "/missing")
        if path.is_file(): compiler_paths.append(path.resolve())
    def toolchain():
        return {str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in compiler_paths}
    chain = toolchain()
    timer_dir = destination / "timer"; timer_dir.mkdir()
    if args.instrument:
        subprocess.run(["cc", "-O2", str(ROOT / "tools/performance/compiler_timer.c"), "-o", str(timer_dir / "gfortran")], check=True)
    result = {"started_utc": datetime.now(timezone.utc).isoformat(), "head": head,
              "compiler": compiler_version, "toolchain": chain,
              "host": platform.uname()._asdict(), "cpuinfo": Path('/proc/cpuinfo').read_text(),
              "affinity": sorted(os.sched_getaffinity(0)), "environment_sha256": hashlib.sha256(
                  json.dumps(dict(os.environ),sort_keys=True).encode()).hexdigest(),
              "instrumented": args.instrument, "trials": [], "equivalent": False}
    success = False
    try:
        for repeat in range(args.repeat):
            order = [*ORIGINALS, "combined"] if repeat % 2 == 0 else ["combined", *reversed(ORIGINALS)]
            trial = {"order":order,"arms":{},"equivalent":False};result["trials"].append(trial)
            for arm in order:
                unchanged()
                if identity.snapshot() != inputs or toolchain() != chain:
                    raise ValueError("input identity changed before arm")
                label = f"trial-{repeat+1}-{arm}"
                env = os.environ.copy()
                if args.instrument:
                    copies = destination / (label + "-executables");copies.mkdir()
                    env.update(PATH=str(timer_dir)+os.pathsep+env['PATH'],
                               SWAP_TIMER_COMPILER=compiler, SWAP_TIMER_EVENTS=str(destination / (label+".compiler.tsv")),
                               SWAP_TIMER_COPIES=str(copies))
                runner = COMBINED if arm == "combined" else ORIGINALS[arm]
                item = launch(runner, destination, label, env)
                trial["arms"][arm] = {k:v for k,v in item.items() if k != "stdout"}
                row = trial["arms"][arm]
                if item["exit"]: raise ValueError(arm + " gate failed")
                if arm == "combined":
                    for case in ORIGINALS:
                        row[case+"_science_sha256"] = extract(item["stdout"],"SHARED_IRR_"+case.upper()+"_SHA256")
                else:
                    row["science_sha256"] = extract(item["stdout"],"MC_IRR01_MANAGEMENT_PHYSICAL_SHA256")
                if args.instrument:
                    events=[]
                    for line in (destination / (label+".compiler.tsv")).read_text().splitlines():
                        fields=line.split('\t')
                        events.append(dict(stage=fields[0],wall_seconds=float(fields[1]),user_cpu_seconds=float(fields[2]),
                                           system_cpu_seconds=float(fields[3]),exit=int(fields[4]),source=fields[5],argv=fields[6:]))
                    row['compiler_events']=events
                    row['compile_count']=sum(e['stage']=='compile' for e in events)
                    row['link_count']=sum(e['stage']=='link' for e in events)
                    row['executables']={exe.name: hashlib.sha256(exe.read_bytes()).hexdigest() for exe in copies.glob('*.exe')}
                    row['execution_events']=[e for e in events if e['stage']=='run']
                    if len(row['execution_events']) != (4 if arm=='combined' else 2):
                        raise ValueError('incomplete executable runtime evidence')
                if identity.snapshot() != inputs or toolchain() != chain:
                    raise ValueError("input identity changed after arm")
                print(label+" PASS seconds="+str(row['seconds']),flush=True)
            verify_science(trial['arms'])
            baseline=sum(trial['arms'][case]['seconds'] for case in ORIGINALS)
            candidate=trial['arms']['combined']['seconds']
            trial['difference_seconds']=baseline-candidate
            trial['original_seconds']=baseline
            trial['combined_seconds']=candidate
            trial['equivalent']=True
        unchanged()
        result['equivalent']=True;success=True
    except (ValueError,OSError,subprocess.SubprocessError) as error:
        result['failure']=f"{type(error).__name__}: {error}"
    finally:
        result['ended_utc']=datetime.now(timezone.utc).isoformat()
        (destination/'CONTROL.json').write_text(json.dumps(result,sort_keys=True,indent=2)+"\n")
    print("SHARED_IRR_COMPARISON="+("PASS" if success else "FAIL"),flush=True)
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
