#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

ALPHA=0.17320259355765216
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(-75.0,-20.0,2.0,10.0)
DELTAS=(-0.05,-0.035,0.035,0.05)
DTS=(0.015625,0.0078125,0.00390625,0.001953125,0.0009765625,0.00048828125,0.000244140625,0.0001220703125,0.00006103515625)
BUDGETS=(0.01,0.1,1.0)

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" in p:
            k,v=p.split("=",1); d[k]=v.strip()
    return d

def run(exe,reg,h,d,dt):
    cp=subprocess.run([exe,reg,repr(h),repr(d),repr(dt)],text=True,capture_output=True)
    if cp.returncode!=0: raise SystemExit(cp.stdout+"\n"+cp.stderr)
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC58_METRIC|"): return parse(line)
    raise SystemExit("F_PE_ELASTIC59_FAIL missing metric row")

def sem(r):
    ks=("full_status","half1_status","half2_status","all_converged","dh_inf","indicator_available","indicator_binf")
    return tuple(r.get(k) for k in ks)

def normalized(binf,budget):
    if not math.isfinite(budget) or budget<=0: return None
    if not math.isfinite(binf) or binf<0: return None
    return ALPHA*binf/budget

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--profile-id",type=int,required=True)
    ap.add_argument("--o0",required=True); ap.add_argument("--o2",required=True)
    a=ap.parse_args()
    rows={}
    for tag,exe in (("O0",a.o0),("O2",a.o2)):
        rr=[]
        for h in HEADS:
            for d in DELTAS:
                for reg in REGIMES:
                    for idx,dt in enumerate(DTS):
                        r=run(exe,reg,h,d,dt); r["_retry"]=idx; rr.append(r)
        rows[tag]=rr
    def key(r): return (r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]))
    a0={key(r):r for r in rows["O0"]}; a2={key(r):r for r in rows["O2"]}
    if set(a0)!=set(a2): raise SystemExit("F_PE_ELASTIC59_FAIL key drift")
    for k in a0:
        if sem(a0[k])!=sem(a2[k]): raise SystemExit(f"F_PE_ELASTIC59_FAIL O0/O2 {k}")
    rr=rows["O2"]

    # Fail-closed invalid budget semantics.
    for bad in (0.0,-1.0,float("inf"),float("nan")):
        if normalized(1.0,bad) is not None: raise SystemExit("F_PE_ELASTIC59_FAIL invalid budget")
    for badb in (-1.0,float("inf"),float("nan")):
        if normalized(badb,0.1) is not None: raise SystemExit("F_PE_ELASTIC59_FAIL invalid indicator")

    accepts=paired_accepts=false_accepts=0
    by_budget={b:{"accepts":0,"paired":0,"false":0,"exhausted":0} for b in BUDGETS}
    for h in HEADS:
      for d in DELTAS:
       for reg in REGIMES:
        seq=sorted([r for r in rr if r["regime"]==reg and float(r["h0"])==h and float(r["delta"])==d],key=lambda r:r["_retry"])
        for budget in BUDGETS:
            candidate=None
            for r in seq:
                if int(r["full_status"])!=1 or r["indicator_available"]!="T": continue
                b=float(r["indicator_binf"])
                c=normalized(b,budget)
                if c is None: continue
                algebra=(b <= budget/ALPHA*(1+1e-15))
                if (c<=1.0)!=algebra: raise SystemExit("F_PE_ELASTIC59_FAIL algebra mismatch")
                if c<=1.0:
                    candidate=r; break
            if candidate is None:
                by_budget[budget]["exhausted"]+=1
                continue
            accepts+=1; by_budget[budget]["accepts"]+=1
            if candidate["all_converged"]=="T" and float(candidate["dh_inf"])>0:
                paired_accepts+=1; by_budget[budget]["paired"]+=1
                if float(candidate["dh_inf"]) > budget*(1+1e-12):
                    false_accepts+=1; by_budget[budget]["false"]+=1
                    print(f"ELASTIC59_FALSE_ACCEPT|profile={a.profile_id}|budget={budget}|regime={reg}|h0={h}|delta={d}|dt={candidate['dt']}|hinf={candidate['dh_inf']}|binf={candidate['indicator_binf']}")
    for b,v in by_budget.items():
        print(f"ELASTIC59_BUDGET|profile={a.profile_id}|budget={b}|accepts={v['accepts']}|paired={v['paired']}|false={v['false']}|exhausted={v['exhausted']}")
    print(f"ELASTIC59_PROFILE|profile={a.profile_id}|accepts={accepts}|paired_accepts={paired_accepts}|false_accepts={false_accepts}")
    print("F_PE_ELASTIC59_PROFILE=PASS")

if __name__=="__main__": main()
