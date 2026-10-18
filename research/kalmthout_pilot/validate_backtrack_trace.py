#!/usr/bin/env python3
"""Check actual Newton backtracking decisions against source predicate.

Input lines:
KALMTHOUT_BACKTRACK_DECISION iteration backtracks head_mode dt factor sump sumold fmax critdevbalcp T/F route
A T value is the predicate (sump<sumold or fmax<tolerance), NOT hour acceptance.
"""
import argparse
import math
from pathlib import Path

def evaluate(path):
    n=0
    modes={0:0,1:0}
    accepted=0
    for line in path.read_text(errors="replace").splitlines():
        p=line.split()
        if not p or p[0]!="KALMTHOUT_BACKTRACK_DECISION":
            continue
        if len(p)!=12:
            raise ValueError("invalid trace field count")
        it,bt,mode=map(int,p[1:4])
        dt,factor,sump,sumold,fmax,tolerance=map(float,p[4:10])
        predicate=p[10]
        if mode not in modes or predicate not in ("T","F") or not all(map(math.isfinite,(dt,factor,sump,sumold,fmax,tolerance))):
            raise ValueError("invalid trace values")
        if dt<=0 or factor<=0 or it<0 or bt<0:
            raise ValueError("invalid timestep/iteration")
        expected=(sump<sumold or fmax<tolerance)
        if (predicate=="T")!=expected:
            raise ValueError(f"backtracking predicate mismatch at trace record {n+1}")
        n+=1
        modes[mode]+=1
        accepted+=int(expected)
    if not n:
        raise ValueError("no backtracking decision records")
    print(f"BACKTRACK_TRACE_VALID=PASS records={n} predicate_true={accepted} predicate_false={n-accepted} head_mode={modes[1]} flux_mode={modes[0]}")
    print("Predicate is not solver/hour commit acceptance")

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("log",type=Path)
    a=p.parse_args()
    evaluate(a.log)
