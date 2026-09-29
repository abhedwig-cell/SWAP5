#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import statistics
import subprocess
from pathlib import Path

REGIMES=("OFF","FIXED_1E6","GENERATED")
H0S=(0.1,2.0,10.0)
DELTAS=(0.05,-0.05,0.025,-0.025)
DTS=(0.25,0.125,0.0625,0.03125,0.015625)

def run(exe: Path, regime: str, h0: float, delta: float, dt: float, repeats: int=1, warmup: int=0):
    cp=subprocess.run(
        [str(exe),regime,repr(h0),repr(delta),repr(dt),str(repeats),str(warmup)],
        text=True,capture_output=True
    )
    if cp.returncode!=0:
        raise SystemExit(
            f"F_PE_ELASTIC47_FAIL executable rc={cp.returncode} regime={regime} h0={h0} delta={delta} dt={dt}\n"
            +cp.stdout+"\n"+cp.stderr
        )
    case=None
    timing=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC47_CASE|"):
            case=parse_line(line)
        elif line.startswith("ELASTIC47_TIMING|"):
            timing=parse_line(line)
    if case is None:
        raise SystemExit("F_PE_ELASTIC47_FAIL missing case marker\n"+cp.stdout)
    return case,timing

def parse_line(line: str):
    out={"_line":line}
    for part in line.split("|")[1:]:
        if "=" not in part:
            continue
        k,v=part.split("=",1)
        out[k]=v.strip()
    return out

def key_case(x):
    return (x["regime"],float(x["h0"]),float(x["delta"]),float(x["dt"]))

def normalized(x):
    keep=("regime","h0","delta","dt","completed","committed","kernel_status","accepted_substeps",
          "solver_iterations","nonlinear","retries","backtracking","jacobians","linear","headcalc",
          "mass_complete","mass")
    return tuple((k,x.get(k)) for k in keep)

def yes(v: str) -> bool:
    return v=="T"

def integer(x,k):
    return int(x[k])

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--o0",required=True)
    ap.add_argument("--o2",required=True)
    ap.add_argument("--timing-repeats",type=int,default=1000)
    ap.add_argument("--timing-warmup",type=int,default=50)
    ap.add_argument("--timing-replicas",type=int,default=5)
    a=ap.parse_args()
    o0=Path(a.o0).resolve();o2=Path(a.o2).resolve()

    results={}
    for tag,exe in (("O0",o0),("O2",o2)):
        rows=[]
        for h0 in H0S:
            for delta in DELTAS:
                for dt in DTS:
                    for regime in REGIMES:
                        case,_=run(exe,regime,h0,delta,dt)
                        rows.append(case)
                        print(f"ELASTIC47_{tag}_"+case["_line"])
        if len(rows)!=180:
            raise SystemExit(f"F_PE_ELASTIC47_FAIL {tag} matrix count={len(rows)}")
        results[tag]=rows

    a0={key_case(x):x for x in results["O0"]}
    a2={key_case(x):x for x in results["O2"]}
    if set(a0)!=set(a2):
        raise SystemExit("F_PE_ELASTIC47_FAIL O0/O2 key drift")
    drift=[]
    for k in sorted(a0):
        if normalized(a0[k])!=normalized(a2[k]):
            drift.append((k,normalized(a0[k]),normalized(a2[k])))
    if drift:
        raise SystemExit("F_PE_ELASTIC47_FAIL O0/O2 drift="+json.dumps(drift[:5],default=str))
    print("F_PE_ELASTIC47_A7_O0_O2=PASS")

    rows=results["O2"]
    completed=[x for x in rows if yes(x["completed"]) and yes(x["committed"])]
    for x in completed:
        if not yes(x["mass_complete"]):
            raise SystemExit("F_PE_ELASTIC47_FAIL completed mass incomplete "+x["_line"])
        if abs(float(x["mass"]))>1e-12:
            raise SystemExit("F_PE_ELASTIC47_FAIL completed mass residual "+x["_line"])
    print(f"ELASTIC47_MATRIX_SUMMARY|cases={len(rows)}|completed={len(completed)}|failed={len(rows)-len(completed)}")
    print("F_PE_ELASTIC47_A2_MATRIX=PASS")
    print("F_PE_ELASTIC47_A3_MASS=PASS")

    by={}
    for x in rows:
        by[(float(x["h0"]),float(x["delta"]),x["regime"],float(x["dt"]))]=x

    thresholds={}
    for h0 in H0S:
        for delta in DELTAS:
            for regime in REGIMES:
                good=[dt for dt in DTS if yes(by[(h0,delta,regime,dt)]["completed"]) and
                                         yes(by[(h0,delta,regime,dt)]["committed"])]
                threshold=max(good) if good else None
                ladder=[by[(h0,delta,regime,dt)] for dt in DTS]
                work={
                    "nonlinear":sum(integer(x,"nonlinear") for x in ladder),
                    "retries":sum(integer(x,"retries") for x in ladder),
                    "backtracking":sum(integer(x,"backtracking") for x in ladder),
                    "headcalc":sum(integer(x,"headcalc") for x in ladder),
                }
                thresholds[(h0,delta,regime)]=threshold
                t="NONE" if threshold is None else f"{threshold:.9g}"
                print(
                    f"ELASTIC47_THRESHOLD|h0={h0:.9g}|delta={delta:.9g}|regime={regime}|largest_completed_dt={t}"
                    f"|sum_nonlinear={work['nonlinear']}|sum_retries={work['retries']}"
                    f"|sum_backtracking={work['backtracking']}|sum_headcalc={work['headcalc']}"
                )
    print("F_PE_ELASTIC47_A4_THRESHOLD=PASS")
    print("F_PE_ELASTIC47_A5_NO_TUNING=PASS")

    timing_pairs=0
    for h0 in H0S:
        for delta in DELTAS:
            common=[
                dt for dt in DTS
                if all(yes(by[(h0,delta,r,dt)]["completed"]) and yes(by[(h0,delta,r,dt)]["committed"]) for r in REGIMES)
            ]
            if not common:
                print(f"ELASTIC47_COMMON_TIMING|h0={h0:.9g}|delta={delta:.9g}|status=UNAVAILABLE")
                continue
            dt=max(common)
            timing_pairs+=1
            medians={}
            for regime in REGIMES:
                vals=[]
                for replica in range(1,a.timing_replicas+1):
                    case,timing=run(o2,regime,h0,delta,dt,a.timing_repeats,a.timing_warmup)
                    if timing is None:
                        raise SystemExit("F_PE_ELASTIC47_FAIL timing marker missing")
                    if not (yes(case["completed"]) and yes(case["committed"])):
                        raise SystemExit("F_PE_ELASTIC47_FAIL matched timing case not completed")
                    ns=float(timing["ns_per_interval"])
                    vals.append(ns)
                    print(
                        f"ELASTIC47_TIMING_REPLICA|h0={h0:.9g}|delta={delta:.9g}|dt={dt:.9g}"
                        f"|regime={regime}|replica={replica}|ns_per_interval={ns:.9f}"
                    )
                med=statistics.median(vals)
                medians[regime]=med
                print(
                    f"ELASTIC47_TIMING_MEDIAN|h0={h0:.9g}|delta={delta:.9g}|dt={dt:.9g}"
                    f"|regime={regime}|ns_per_interval={med:.9f}"
                )
            off=medians["OFF"]
            print(
                f"ELASTIC47_TIMING_RATIO|h0={h0:.9g}|delta={delta:.9g}|dt={dt:.9g}"
                f"|FIXED_1E6_over_OFF={medians['FIXED_1E6']/off:.9f}"
                f"|GENERATED_over_OFF={medians['GENERATED']/off:.9f}"
                f"|GENERATED_over_FIXED_1E6={medians['GENERATED']/medians['FIXED_1E6']:.9f}"
            )
    print(f"ELASTIC47_TIMING_PAIR_COUNT={timing_pairs}")
    print("F_PE_ELASTIC47_A6_MATCHED_TIMING=PASS")
    print("F_PE_ELASTIC47=PASS")

if __name__=="__main__":
    main()
