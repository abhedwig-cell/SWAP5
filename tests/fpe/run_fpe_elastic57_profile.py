#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

ALPHA=0.17320259355765216
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(-75.0,-20.0,2.0,10.0)
DELTAS=(-0.05,-0.035,0.035,0.05)
DTS=(0.015625,0.0078125,0.00390625,0.001953125,0.0009765625,0.00048828125,0.000244140625,0.0001220703125,0.00006103515625)

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" in p:
            k,v=p.split("=",1); d[k]=v.strip()
    return d

def execute(exe,reg,h,d,dt):
    cp=subprocess.run([str(exe),reg,repr(h),repr(d),repr(dt)],text=True,capture_output=True)
    if cp.returncode!=0: raise SystemExit(cp.stdout+"\n"+cp.stderr)
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC55_BANK|"): return parse(line)
    raise SystemExit("F_PE_ELASTIC57_FAIL missing row")

def semantic(r):
    ks=("full_status","half1_status","half2_status","all_converged","dh_inf","indicator_available","indicator_binf")
    return tuple(r.get(k) for k in ks)

def budgets(vals):
    x=sorted(set(v for v in vals if v>0))
    if not x: return []
    out=[x[0]*0.5]
    out += [math.sqrt(a*b) for a,b in zip(x,x[1:])]
    out += [x[-1]*2.0]
    return out

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
                        r=execute(exe,reg,h,d,dt); r["_retry"]=idx; rr.append(r)
        rows[tag]=rr
    def key(r): return (r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]))
    a0={key(r):r for r in rows["O0"]}; a2={key(r):r for r in rows["O2"]}
    if set(a0)!=set(a2): raise SystemExit("F_PE_ELASTIC57_FAIL key drift")
    for k in a0:
        if semantic(a0[k])!=semantic(a2[k]): raise SystemExit(f"F_PE_ELASTIC57_FAIL O0/O2 {k}")

    rr=rows["O2"]
    eligible=violating=budget_tests=accepts=exhausted=paired_accepts=0
    for h in HEADS:
      for d in DELTAS:
       for reg in REGIMES:
        seq=sorted([r for r in rr if r["regime"]==reg and float(r["h0"])==h and float(r["delta"])==d],key=lambda r:r["_retry"])
        avail=[r for r in seq if int(r["full_status"])==1 and r["indicator_available"]=="T"]
        if len(avail)>=3:
            eligible+=1
            ev=[ALPHA*float(r["indicator_binf"]) for r in avail]
            if any(ev[i+1]>ev[i]*(1+1e-12) for i in range(len(ev)-1)): violating+=1
        for budget in budgets([ALPHA*float(r["indicator_binf"]) for r in avail]):
            budget_tests+=1
            oracle=None
            for r in seq:
                if int(r["full_status"])==1 and r["indicator_available"]=="T" and ALPHA*float(r["indicator_binf"])<=budget:
                    oracle=r; break
            candidate=None
            for r in seq:
                if int(r["full_status"])!=1 or r["indicator_available"]!="T": continue
                if ALPHA*float(r["indicator_binf"])<=budget:
                    candidate=r; break
            if (oracle is None)!=(candidate is None): raise SystemExit("F_PE_ELASTIC57_FAIL controller oracle")
            if oracle is not None and key(oracle)!=key(candidate): raise SystemExit("F_PE_ELASTIC57_FAIL first-pass mismatch")
            if candidate is None:
                exhausted+=1
            else:
                accepts+=1
                if ALPHA*float(candidate["indicator_binf"])>budget*(1+1e-12): raise SystemExit("F_PE_ELASTIC57_FAIL false accept")
                if candidate["all_converged"]=="T" and float(candidate["dh_inf"])>0:
                    paired_accepts+=1
                    if float(candidate["dh_inf"])>ALPHA*float(candidate["indicator_binf"])*(1+1e-12):
                        raise SystemExit("F_PE_ELASTIC57_FAIL frozen envelope")

    print(f"ELASTIC57_PROFILE|profile={a.profile_id}|eligible={eligible}|violating={violating}|budget_tests={budget_tests}|accepts={accepts}|exhausted={exhausted}|paired_accepts={paired_accepts}")
    print("F_PE_ELASTIC57_PROFILE=PASS")

if __name__=="__main__": main()
