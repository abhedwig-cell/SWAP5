from __future__ import annotations

import argparse
import json
import math
import os
import platform
import re
import resource
import statistics
import subprocess
import time
from pathlib import Path

PAIRS=12
WARMUPS=2
TARGET_RESOLUTION=0.05
K=2.0
ROUTES=("REFERENCE","ROSSFAST")

MARKERS={
    "route":re.compile(r"^F_ROSS18_ROUTE=(REFERENCE|ROSSFAST)$",re.MULTILINE),
    "cases":re.compile(r"^F_ROSS18_CASE_COUNT=(\d+)$",re.MULTILINE),
    "repetitions":re.compile(r"^F_ROSS18_INNER_REPETITIONS=(\d+)$",re.MULTILINE),
    "solve_count":re.compile(r"^F_ROSS18_TIMED_SOLVE_COUNT=(\d+)$",re.MULTILINE),
    "solver_cpu":re.compile(r"^F_ROSS18_SOLVER_CPU_SECONDS=\s*([0-9.Ee+\-]+)$",re.MULTILINE),
    "checksum":re.compile(r"^F_ROSS18_CHECKSUM=\s*([0-9.Ee+\-]+)$",re.MULTILINE),
    "lin":re.compile(r"^F_ROSS18_EXPECTED_LINEAR_SOLVES=(\d+)$",re.MULTILINE),
    "paired":re.compile(r"^F_ROSS18_PAIRED_ADMISSIBLE_COUNT=(\d+)$",re.MULTILINE),
    "disc":re.compile(r"^F_ROSS18_DISCREPANCY_FAIL_COUNT=(\d+)$",re.MULTILINE),
    "gate":re.compile(r"^F_ROSS18_GATE=PASS$",re.MULTILINE),
}

def child_cpu():
    u=resource.getrusage(resource.RUSAGE_CHILDREN)
    return float(u.ru_utime+u.ru_stime)

def parse(text:str,route:str,expected_lin:int)->dict:
    v={}
    for name,p in MARKERS.items():
        m=p.search(text)
        if not m:
            raise RuntimeError(f"missing {name} marker\n{text}")
        v[name]=True if name=="gate" else m.group(1)
    if v["route"]!=route:
        raise RuntimeError(f"route mismatch {v['route']} != {route}")
    if int(v["cases"])!=36 or int(v["repetitions"])!=200 or int(v["solve_count"])!=7200:
        raise RuntimeError("benchmark dimension drift")
    if int(v["lin"])!=expected_lin:
        raise RuntimeError("expected linear solve marker drift")
    cpu=float(v["solver_cpu"])
    if not math.isfinite(cpu) or cpu<=0:
        raise RuntimeError("invalid solver CPU")
    return {
        "route":route,
        "solver_cpu_seconds":cpu,
        "checksum_text":str(v["checksum"]),
        "paired_valid_count":int(v["paired"]),
        "discrepancy_fail_count":int(v["disc"]),
    }

def run_one(exe:Path,route:str,expected_lin:int,cpu:int,cycle:int,measured:bool)->dict:
    env=os.environ.copy()
    env["SWAP5_ROSS18_ROUTE"]=route
    env["SWAP5_ROSS18_EXPECTED_LINEAR_SOLVES"]=str(expected_lin)
    env["OMP_NUM_THREADS"]="1"
    def pin():
        os.sched_setaffinity(0,{cpu})
    cb=child_cpu(); wb=time.perf_counter_ns()
    p=subprocess.run([str(exe.resolve())],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                     text=True,check=False,preexec_fn=pin)
    wa=time.perf_counter_ns(); ca=child_cpu()
    if p.returncode!=0:
        raise RuntimeError(f"{route} failed {p.returncode}\n{p.stdout}")
    row=parse(p.stdout,route,expected_lin)
    row.update({
        "cycle":cycle,"measured":measured,"target_cpu":cpu,
        "child_cpu_seconds":ca-cb,"wall_elapsed_seconds":(wa-wb)/1e9,
    })
    print("F_ROSS18_SAMPLE="+json.dumps(row,sort_keys=True,separators=(",",":")),flush=True)
    return row

def dist(v:list[float])->dict:
    return {"n":len(v),"mean":statistics.fmean(v),"median":statistics.median(v),
            "stdev":statistics.stdev(v) if len(v)>1 else 0.0,"min":min(v),"max":max(v)}

def cpu_model():
    try:
        for line in Path("/proc/cpuinfo").read_text(errors="replace").splitlines():
            if line.lower().startswith("model name") and ":" in line:
                return line.split(":",1)[1].strip()
    except OSError:
        pass
    return None

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--variant",required=True)
    ap.add_argument("--expected-linear-solves",type=int,required=True)
    ap.add_argument("--executable",type=Path,required=True)
    ap.add_argument("--output",type=Path,required=True)
    args=ap.parse_args()

    visible=sorted(os.sched_getaffinity(0))
    if not visible: raise RuntimeError("no visible CPUs")
    cpu=visible[0]
    checksums={}
    warmups=[]
    for _ in range(WARMUPS):
        for route in ROUTES:
            row=run_one(args.executable,route,args.expected_linear_solves,cpu,-1,False)
            checksums.setdefault(route,row["checksum_text"])
            if checksums[route]!=row["checksum_text"]:
                raise RuntimeError(f"{route} warmup checksum drift")
            warmups.append(row)

    samples=[]
    for cycle in range(PAIRS):
        order=ROUTES if cycle%2==0 else tuple(reversed(ROUTES))
        for route in order:
            row=run_one(args.executable,route,args.expected_linear_solves,cpu,cycle,True)
            checksums.setdefault(route,row["checksum_text"])
            if checksums[route]!=row["checksum_text"]:
                raise RuntimeError(f"{route} measured checksum drift")
            samples.append(row)

    pairs={}
    for row in samples:
        pairs.setdefault(row["cycle"],{})[row["route"]]=row
    if len(pairs)!=PAIRS or any(set(p)!=set(ROUTES) for p in pairs.values()):
        raise RuntimeError("incomplete pairs")

    deltas=[]; speedups=[]; child=[]; wall=[]
    for cycle in sorted(pairs):
        ref=pairs[cycle]["REFERENCE"]; ross=pairs[cycle]["ROSSFAST"]
        deltas.append(ross["solver_cpu_seconds"]/ref["solver_cpu_seconds"]-1.0)
        speedups.append(ref["solver_cpu_seconds"]/ross["solver_cpu_seconds"])
        child.append(ross["child_cpu_seconds"]/ref["child_cpu_seconds"]-1.0)
        wall.append(ross["wall_elapsed_seconds"]/ref["wall_elapsed_seconds"]-1.0)
    d=dist(deltas); mde=K*d["stdev"]/math.sqrt(PAIRS); mean=d["mean"]
    if mean < -mde: outcome="SCREENING_ROSSFAST_FASTER"
    elif mean > mde: outcome="SCREENING_REFERENCE_FASTER"
    else: outcome="SCREENING_NOT_RESOLVED"
    result={
        "schema":"swap5.f-ross18.variant-performance-screen.v1",
        "variant":args.variant,
        "expected_linear_solves":args.expected_linear_solves,
        "host":{"platform":platform.platform(),"cpu_model":cpu_model(),"classification":"GITHUB_HOSTED_SCREENING_ONLY"},
        "measurement":{"warmups":WARMUPS,"pairs":PAIRS,"case_count":36,"inner_repetitions_per_case":200,
                       "timed_solves_per_sample":7200,"target_cpu":cpu,"outlier_deletion":False},
        "route_checksums":checksums,
        "paired_valid_count":samples[0]["paired_valid_count"],
        "discrepancy_fail_count":samples[0]["discrepancy_fail_count"],
        "rossfast_over_reference_relative_delta":{**d,"mde":mde,"target_resolution_relative":TARGET_RESOLUTION,
                                                   "target_resolution_qualified":mde<=TARGET_RESOLUTION},
        "reference_over_rossfast_speedup":dist(speedups),
        "whole_child_cpu_relative_delta":dist(child),
        "wall_elapsed_relative_delta":dist(wall),
        "screening_outcome":outcome,
        "formal_performance_claim":False,
        "samples":samples,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    print(json.dumps(result,indent=2,sort_keys=True))
    print(f"F_ROSS18_VARIANT={args.variant}")
    print(f"F_ROSS18_SCREENING_OUTCOME={outcome}")
    print(f"F_ROSS18_MEAN_RELATIVE_DELTA={mean:.12g}")
    print(f"F_ROSS18_MDE={mde:.12g}")
    print(f"F_ROSS18_MEAN_REFERENCE_OVER_ROSSFAST={statistics.fmean(speedups):.12g}")
    print("F_ROSS18_PERFORMANCE_GATE=PASS")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
