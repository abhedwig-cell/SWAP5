#!/usr/bin/env python3
from __future__ import annotations
import argparse, statistics, subprocess

REGIMES=("OFF","FIXED_1E6","GENERATED")
MODES=("SOLVE_ONLY","INDICATOR_ONLY","SOLVE_PLUS_INDICATOR")
H0=10.0
DELTA=0.05
DT=0.015625
REPEATS={"SOLVE_ONLY":500,"INDICATOR_ONLY":5000,"SOLVE_PLUS_INDICATOR":500}
WARMUP={"SOLVE_ONLY":20,"INDICATOR_ONLY":100,"SOLVE_PLUS_INDICATOR":20}
REPLICAS=7

def parse_line(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    return d

def run(exe,regime,mode,repeats,warmup):
    cp=subprocess.run(
        [exe,regime,repr(H0),repr(DELTA),repr(DT),mode,str(repeats),str(warmup)],
        text=True,capture_output=True
    )
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC59_FAIL rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC59_TIMING|"):
            row=parse_line(line)
    if row is None:
        raise SystemExit("F_PE_ELASTIC59_FAIL missing timing marker")
    return row

def functional_signature(r):
    keys=("regime","mode","full_nonlinear","full_jacobians","full_linear","full_backtracking",
          "indicator_extra_tridiag","indicator_extra_nonlinear")
    return tuple((k,r[k]) for k in keys)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--o0",required=True)
    ap.add_argument("--o2",required=True)
    a=ap.parse_args()

    # Functional O0/O2 agreement with one untimed-style invocation.
    for reg in REGIMES:
        for mode in MODES:
            r0=run(a.o0,reg,mode,1,0)
            r2=run(a.o2,reg,mode,1,0)
            if functional_signature(r0)!=functional_signature(r2):
                raise SystemExit(f"F_PE_ELASTIC59_FAIL O0/O2 drift {reg} {mode}")
            if int(r2["indicator_extra_tridiag"])!=1:
                raise SystemExit(f"F_PE_ELASTIC59_FAIL indicator tridiag {reg} {mode}")
            if int(r2["indicator_extra_nonlinear"])!=0:
                raise SystemExit(f"F_PE_ELASTIC59_FAIL indicator nonlinear {reg} {mode}")
            print("ELASTIC59_FUNCTIONAL|"+("|".join(f"{k}={v}" for k,v in functional_signature(r2))))
    print("F_PE_ELASTIC59_A1_CONVERGENCE=PASS")
    print("F_PE_ELASTIC59_A2_CERTIFICATE_COST_SHAPE=PASS")
    print("F_PE_ELASTIC59_A3_O0_O2=PASS")

    med={}
    counters={}
    for reg in REGIMES:
        for mode in MODES:
            vals=[]
            for rep in range(1,REPLICAS+1):
                r=run(a.o2,reg,mode,REPEATS[mode],WARMUP[mode])
                ns=float(r["ns_per_op"])
                vals.append(ns)
                counters[(reg,mode)]=r
                print(f"ELASTIC59_REPLICA|regime={reg}|mode={mode}|replica={rep}|ns_per_op={ns:.9f}")
            med[(reg,mode)]=statistics.median(vals)
            print(f"ELASTIC59_MEDIAN|regime={reg}|mode={mode}|ns_per_op={med[(reg,mode)]:.9f}")

    for reg in REGIMES:
        solve=med[(reg,"SOLVE_ONLY")]
        ind=med[(reg,"INDICATOR_ONLY")]
        both=med[(reg,"SOLVE_PLUS_INDICATOR")]
        print(
            f"ELASTIC59_RATIO|regime={reg}"
            f"|indicator_over_solve={ind/solve:.9f}"
            f"|combined_over_solve={both/solve:.9f}"
            f"|combined_minus_solve_ns={both-solve:.9f}"
            f"|indicator_ns={ind:.9f}"
        )

    offsolve=med[("OFF","SOLVE_ONLY")]
    fixedboth=med[("FIXED_1E6","SOLVE_PLUS_INDICATOR")]
    genboth=med[("GENERATED","SOLVE_PLUS_INDICATOR")]
    print(
        f"ELASTIC59_CROSS_REGIME|fixed_combined_over_off_solve={fixedboth/offsolve:.9f}"
        f"|generated_combined_over_off_solve={genboth/offsolve:.9f}"
    )
    print("F_PE_ELASTIC59_A4_TIMING_REPLICAS=PASS")
    print("F_PE_ELASTIC59=PASS")

if __name__=="__main__":
    main()
