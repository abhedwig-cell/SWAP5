#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

BINF_LIMIT=0.05773585599727987
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(-75.0,-20.0,2.0,10.0)
DELTAS=(-0.05,-0.035,0.035,0.05)
DTS=tuple(0.015625*(0.5**i) for i in range(15))
NS=(2,4,8,16,32,64)
PAIRS=((32,64),(16,32),(8,16),(4,8),(2,4))
TRIPLES=((16,32,64),(8,16,32),(4,8,16),(2,4,8))
FLOORS={"head":1e-12,"theta":1e-14,"flux":1e-12,"exchange":1e-14}

def parse_pipe(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" in p:
            k,v=p.split("=",1); d[k]=v.strip()
    return d

def execute(exe,reg,h,d,dt,n=0):
    cp=subprocess.run([str(exe),reg,repr(h),repr(d),repr(dt),str(n)],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC66_FAIL executable rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=oracle=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC55_BANK|"): row=parse_pipe(line)
        elif line.startswith("ELASTIC60_ORACLE|"): oracle=parse_pipe(line)
    if row is None: raise SystemExit("F_PE_ELASTIC66_FAIL missing selector row")
    if n>0 and oracle is None: raise SystemExit("F_PE_ELASTIC66_FAIL missing oracle row")
    return row,oracle

def sem(r): return (r.get("full_status"),r.get("indicator_available"),r.get("indicator_binf"))

def decide(exe,reg,h,d):
    trace=[]
    for idx,dt in enumerate(DTS):
        r,_=execute(exe,reg,h,d,dt,0); trace.append(r)
        if int(r["full_status"])==1 and r["indicator_available"]=="T" and float(r["indicator_binf"])<=BINF_LIMIT:
            return ("ACCEPT",idx,dt,r,trace)
    return ("EXHAUSTED",None,None,None,trace)

def metric_complete(o):
    return o["oracle_complete"]=="T" and o["oracle_mass_ok"]=="T"

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--profile-id",type=int,required=True)
    ap.add_argument("--o0",required=True); ap.add_argument("--o2",required=True)
    a=ap.parse_args()
    accepted=exhausted=no_pair=triple=pair=0

    for h in HEADS:
      for d in DELTAS:
       for reg in REGIMES:
        q0=decide(a.o0,reg,h,d); q2=decide(a.o2,reg,h,d)
        if q0[:3]!=q2[:3]: raise SystemExit("F_PE_ELASTIC66_FAIL O0/O2 decision drift")
        for r0,r2 in zip(q0[4],q2[4]):
            if sem(r0)!=sem(r2): raise SystemExit("F_PE_ELASTIC66_FAIL O0/O2 scan drift")
        if q2[0]=="EXHAUSTED":
            exhausted+=1; continue
        accepted+=1

        rec={}
        diag={}
        for n in NS:
            _,o=execute(a.o2,reg,h,d,q2[2],n)
            ok=metric_complete(o)
            rec[n]=ok
            diag[n]={
              "complete":o["oracle_complete"],
              "mass":o["oracle_mass_ok"],
              "fstep":int(o.get("failure_step","0")),
              "fstatus":int(o.get("failure_status","0")),
              "minnl":int(o.get("min_nonlinear","0")),
              "maxnl":int(o.get("max_nonlinear","0")),
            }

        has_triple=any(all(rec[n] for n in t) for t in TRIPLES)
        if has_triple:
            triple+=1; continue
        has_pair=any(rec[n0] and rec[n1] for n0,n1 in PAIRS)
        if has_pair:
            pair+=1; continue

        no_pair+=1
        pattern="".join("1" if rec[n] else "0" for n in NS)
        levels=",".join(str(n) for n in NS)
        failures=";".join(
          f"{n}:{diag[n]['complete']}:{diag[n]['mass']}:{diag[n]['fstep']}:{diag[n]['fstatus']}:{diag[n]['minnl']}:{diag[n]['maxnl']}"
          for n in NS
        )
        print(
          f"ELASTIC66_NO_PAIR|profile={a.profile_id}|regime={reg}|h0={h}|delta={d}|dt={q2[2]:.17e}"
          f"|levels={levels}|pattern={pattern}|diag={failures}"
        )

    print(f"ELASTIC66_PROFILE|profile={a.profile_id}|accepted={accepted}|exhausted={exhausted}|triple={triple}|pair_only={pair}|no_pair={no_pair}")
    print("F_PE_ELASTIC66_PROFILE=PASS")

if __name__=="__main__": main()
