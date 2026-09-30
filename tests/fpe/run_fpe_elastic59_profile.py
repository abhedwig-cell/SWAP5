#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

BINF_LIMIT=0.05773585599727987
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(-75.0,-20.0,2.0,10.0)
DELTAS=(-0.05,-0.035,0.035,0.05)
DTS=tuple(0.015625*(0.5**i) for i in range(15))
NS=(4,8,16,32,64)

def parse_pipe(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" in p:
            k,v=p.split("=",1); d[k]=v.strip()
    return d

def parse_state(line,prefix):
    x=line.strip()
    if not x.startswith(prefix): return None
    rest=x[len(prefix):]
    if rest.startswith(","): rest=rest[1:]
    if not rest: return []
    return [float(v) for v in rest.split(",") if v!=""]

def execute(exe,reg,h,d,dt,oracle_n=0):
    cp=subprocess.run([str(exe),reg,repr(h),repr(d),repr(dt),str(oracle_n)],
                      text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC59_FAIL executable rc={cp.returncode} reg={reg} h={h} d={d} dt={dt} N={oracle_n}\n{cp.stdout}\n{cp.stderr}")
    row=oracle=heads=theta=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC55_BANK|"): row=parse_pipe(line)
        elif line.startswith("ELASTIC59_ORACLE|"): oracle=parse_pipe(line)
        elif line.startswith("ELASTIC59_HEADS"): heads=parse_state(line,"ELASTIC59_HEADS")
        elif line.startswith("ELASTIC59_THETA"): theta=parse_state(line,"ELASTIC59_THETA")
    if row is None: raise SystemExit("F_PE_ELASTIC59_FAIL missing bank row")
    if oracle_n>0 and oracle is None: raise SystemExit("F_PE_ELASTIC59_FAIL missing oracle row")
    if oracle is not None and oracle["oracle_complete"]=="T":
        if heads is None or theta is None or len(heads)!=16 or len(theta)!=16:
            raise SystemExit("F_PE_ELASTIC59_FAIL successful oracle missing state")
    return row,oracle,heads,theta

def sem(r):
    return (r.get("full_status"),r.get("indicator_available"),r.get("indicator_binf"))

def decide(exe,reg,h,d):
    trace=[]
    for idx,dt in enumerate(DTS):
        r,_,_,_=execute(exe,reg,h,d,dt,0)
        trace.append(r)
        if int(r["full_status"])==1 and r["indicator_available"]=="T":
            b=float(r["indicator_binf"])
            if b<=BINF_LIMIT:
                return ("ACCEPT",idx,dt,r,trace)
    return ("EXHAUSTED",None,None,None,trace)

def maxdiff(a,b):
    return max(abs(x-y) for x,y in zip(a,b))

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--profile-id",type=int,required=True)
    ap.add_argument("--o0",required=True); ap.add_argument("--o2",required=True)
    a=ap.parse_args()

    accepted=exhausted=0
    nstats={n:{"complete":0,"failed":0} for n in NS}
    failsteps={n:{} for n in NS}
    refine_pairs=0
    refine_h=[]; refine_theta=[]
    regime_pattern={}

    for h in HEADS:
      for d in DELTAS:
       decisions={}
       for reg in REGIMES:
        q0=decide(a.o0,reg,h,d); q2=decide(a.o2,reg,h,d)
        if q0[:3]!=q2[:3]:
            raise SystemExit(f"F_PE_ELASTIC59_FAIL decision drift profile={a.profile_id} h={h} d={d} reg={reg}")
        for r0,r2 in zip(q0[4],q2[4]):
            if sem(r0)!=sem(r2):
                raise SystemExit(f"F_PE_ELASTIC59_FAIL scan drift profile={a.profile_id} h={h} d={d} reg={reg}")
        if q2[0]=="EXHAUSTED":
            exhausted+=1
            decisions[reg]=None
            continue
        accepted+=1
        decisions[reg]=(q2[1],q2[2])
        prev_success=None
        pattern=[]
        for n in NS:
            _,o,hs,ts=execute(a.o2,reg,h,d,q2[2],n)
            complete=o["oracle_complete"]=="T"
            pattern.append("T" if complete else "F")
            if complete:
                nstats[n]["complete"]+=1
                if o["oracle_mass_ok"]!="T":
                    raise SystemExit(f"F_PE_ELASTIC59_FAIL successful oracle mass profile={a.profile_id} reg={reg} h={h} d={d} N={n}")
                if prev_success is not None:
                    pn,ph,pt=prev_success
                    hd=maxdiff(ph,hs); td=maxdiff(pt,ts)
                    refine_pairs+=1; refine_h.append(hd); refine_theta.append(td)
                    print(f"ELASTIC59_REFINEMENT|profile={a.profile_id}|regime={reg}|h0={h}|delta={d}|dt={q2[2]:.17e}|n0={pn}|n1={n}|dh={hd:.17e}|dtheta={td:.17e}")
                prev_success=(n,hs,ts)
            else:
                nstats[n]["failed"]+=1
                fs=int(o["failure_step"]); st=int(o["failure_status"])
                failsteps[n][fs]=failsteps[n].get(fs,0)+1
                print(
                    f"ELASTIC59_FAILURE|profile={a.profile_id}|regime={reg}|h0={h}|delta={d}|dt={q2[2]:.17e}"
                    f"|N={n}|failure_step={fs}|failure_status={st}|min_nonlinear={o['min_nonlinear']}|max_nonlinear={o['max_nonlinear']}"
                )
        regime_pattern[reg]=(q2[1],q2[2],"".join(pattern))

       # Compare regime solvability patterns for this physical state/forcing.
       active=[(reg,decisions.get(reg),regime_pattern.get(reg)) for reg in REGIMES if decisions.get(reg) is not None]
       if len(active)==3:
           pats=[x[2][2] for x in active]
           same = len(set(pats))==1
           print(f"ELASTIC59_REGIME_PATTERN|profile={a.profile_id}|h0={h}|delta={d}|same={'T' if same else 'F'}|OFF={pats[0]}|FIXED_1E6={pats[1]}|GENERATED={pats[2]}")

    if accepted+exhausted!=48:
        raise SystemExit(f"F_PE_ELASTIC59_FAIL accounting accepted={accepted} exhausted={exhausted}")
    print(f"ELASTIC59_PROFILE|profile={a.profile_id}|accepted={accepted}|exhausted={exhausted}|refine_pairs={refine_pairs}|max_refine_dh={max(refine_h) if refine_h else 0.0:.17e}|max_refine_dtheta={max(refine_theta) if refine_theta else 0.0:.17e}")
    for n in NS:
        print(f"ELASTIC59_N|profile={a.profile_id}|N={n}|complete={nstats[n]['complete']}|failed={nstats[n]['failed']}|failure_steps={failsteps[n]}")
    print("F_PE_ELASTIC59_PROFILE=PASS")

if __name__=="__main__":
    main()
