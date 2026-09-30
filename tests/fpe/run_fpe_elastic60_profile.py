#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

ALPHA=0.17320259355765216
BINF_LIMIT=0.05773585599727987
HEAD_LIMIT=0.01
THETA_LIMIT=1.0e-5
FLUX_LIMIT=0.01
EXCHANGE_LIMIT=0.005
MASS_TOL=1.0e-12
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(-75.0,-20.0,2.0,10.0)
DELTAS=(-0.05,-0.035,0.035,0.05)
DTS=tuple(0.015625*(0.5**i) for i in range(15))
NS=(2,4,8,16,32,64)
TRIPLES=((16,32,64),(8,16,32),(4,8,16),(2,4,8))
FLOORS={"head":1e-12,"theta":1e-14,"flux":1e-12,"exchange":1e-14}

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
    return [float(v) for v in rest.split(",") if v!=""]

def execute(exe,reg,h,d,dt,oracle_n=0):
    cp=subprocess.run([str(exe),reg,repr(h),repr(d),repr(dt),str(oracle_n)],
                      text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC60_FAIL executable rc={cp.returncode} reg={reg} h={h} d={d} dt={dt} N={oracle_n}\n{cp.stdout}\n{cp.stderr}")
    row=oracle=heads=theta=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC55_BANK|"): row=parse_pipe(line)
        elif line.startswith("ELASTIC60_ORACLE|"): oracle=parse_pipe(line)
        elif line.startswith("ELASTIC60_HEADS"): heads=parse_state(line,"ELASTIC60_HEADS")
        elif line.startswith("ELASTIC60_THETA"): theta=parse_state(line,"ELASTIC60_THETA")
    if row is None: raise SystemExit("F_PE_ELASTIC60_FAIL missing bank row")
    if oracle_n>0 and oracle is None: raise SystemExit("F_PE_ELASTIC60_FAIL missing oracle row")
    if oracle is not None and oracle["oracle_complete"]=="T":
        if heads is None or theta is None or len(heads)!=16 or len(theta)!=16:
            raise SystemExit("F_PE_ELASTIC60_FAIL successful oracle missing state")
    return row,oracle,heads,theta

def sem(r):
    return (r.get("full_status"),r.get("indicator_available"),r.get("indicator_binf"))

def decide(exe,reg,h,d):
    trace=[]
    for idx,dt in enumerate(DTS):
        r,_,_,_=execute(exe,reg,h,d,dt,0); trace.append(r)
        if int(r["full_status"])==1 and r["indicator_available"]=="T":
            if float(r["indicator_binf"])<=BINF_LIMIT:
                return ("ACCEPT",idx,dt,r,trace)
    return ("EXHAUSTED",None,None,None,trace)

def maxdiff(a,b):
    return max(abs(x-y) for x,y in zip(a,b))

def scalar_diff(a,b):
    return abs(a-b)

def contraction(d1,d2,floor):
    return d2 <= 0.75*d1 + floor

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--profile-id",type=int,required=True)
    ap.add_argument("--o0",required=True); ap.add_argument("--o2",required=True)
    a=ap.parse_args()

    accepted=exhausted=n32_complete=0
    adaptive_ok=adaptive_unavailable=0
    no_success_triple=contraction_fail=0
    physical_fail=0
    head_fail=theta_fail=flux_fail=exchange_fail=mass_fail=0
    selected_triples={}
    worst={"head_bound":0.0,"theta_bound":0.0,"flux_bound":0.0,"exchange_bound":0.0}

    for h in HEADS:
      for d in DELTAS:
       for reg in REGIMES:
        q0=decide(a.o0,reg,h,d); q2=decide(a.o2,reg,h,d)
        if q0[:3]!=q2[:3]:
            raise SystemExit(f"F_PE_ELASTIC60_FAIL decision drift profile={a.profile_id} reg={reg} h={h} d={d}")
        for r0,r2 in zip(q0[4],q2[4]):
            if sem(r0)!=sem(r2):
                raise SystemExit(f"F_PE_ELASTIC60_FAIL scan drift profile={a.profile_id} reg={reg} h={h} d={d}")
        if q2[0]=="EXHAUSTED":
            exhausted+=1
            continue
        accepted+=1
        rec={}
        for n in NS:
            _,o,hs,ts=execute(a.o2,reg,h,d,q2[2],n)
            complete=o["oracle_complete"]=="T"
            massok=o["oracle_mass_ok"]=="T"
            fullmass=abs(float(o["full_ledger_residual"]))<=MASS_TOL
            if n==32 and complete: n32_complete+=1
            if complete:
                rec[n]={
                    "heads":hs,"theta":ts,
                    "flux":float(o["oracle_flux_final"]),
                    "exchange":float(o["oracle_exchange"]),
                    "cand_head":float(o["oracle_dh"]),
                    "cand_theta":float(o["oracle_dtheta"]),
                    "cand_flux_abs":abs(float(o["full_flux"])-float(o["oracle_flux_final"])),
                    "cand_exchange_abs":abs(float(o["full_exchange"])-float(o["oracle_exchange"])),
                    "massok":massok,"fullmass":fullmass,
                }

        eligible_success_triple=False
        chosen=None
        for n0,n1,n2 in TRIPLES:
            if not all(n in rec for n in (n0,n1,n2)): continue
            eligible_success_triple=True
            r0,r1,r2=rec[n0],rec[n1],rec[n2]
            if not all(x["massok"] and x["fullmass"] for x in (r0,r1,r2)): continue

            d1h=maxdiff(r0["heads"],r1["heads"]); d2h=maxdiff(r1["heads"],r2["heads"])
            d1t=maxdiff(r0["theta"],r1["theta"]); d2t=maxdiff(r1["theta"],r2["theta"])
            d1f=scalar_diff(r0["flux"],r1["flux"]); d2f=scalar_diff(r1["flux"],r2["flux"])
            d1e=scalar_diff(r0["exchange"],r1["exchange"]); d2e=scalar_diff(r1["exchange"],r2["exchange"])
            checks=(
                contraction(d1h,d2h,FLOORS["head"]),
                contraction(d1t,d2t,FLOORS["theta"]),
                contraction(d1f,d2f,FLOORS["flux"]),
                contraction(d1e,d2e,FLOORS["exchange"]),
            )
            if not all(checks): continue
            chosen=(n0,n1,n2,r2,d2h,d2t,d2f,d2e)
            break

        if chosen is None:
            adaptive_unavailable+=1
            if eligible_success_triple: contraction_fail+=1
            else: no_success_triple+=1
            print(f"ELASTIC60_ADAPTIVE|profile={a.profile_id}|regime={reg}|h0={h}|delta={d}|dt={q2[2]:.17e}|status=UNAVAILABLE|reason={'CONTRACTION' if eligible_success_triple else 'NO_SUCCESS_TRIPLE'}")
            continue

        adaptive_ok+=1
        n0,n1,n2,fine,d2h,d2t,d2f,d2e=chosen
        selected_triples[(n0,n1,n2)]=selected_triples.get((n0,n1,n2),0)+1
        hb=fine["cand_head"]+3.0*d2h
        tb=fine["cand_theta"]+3.0*d2t
        fb=(fine["cand_flux_abs"]+3.0*d2f)/max(abs(fine["flux"]),1e-12)
        eb=(fine["cand_exchange_abs"]+3.0*d2e)/max(abs(fine["exchange"]),1e-12)
        worst["head_bound"]=max(worst["head_bound"],hb)
        worst["theta_bound"]=max(worst["theta_bound"],tb)
        worst["flux_bound"]=max(worst["flux_bound"],fb)
        worst["exchange_bound"]=max(worst["exchange_bound"],eb)
        hf=hb>HEAD_LIMIT*(1+1e-12); tf=tb>THETA_LIMIT*(1+1e-12)
        ff=fb>FLUX_LIMIT*(1+1e-12); ef=eb>EXCHANGE_LIMIT*(1+1e-12)
        mf=not fine["massok"] or not fine["fullmass"]
        head_fail+=int(hf);theta_fail+=int(tf);flux_fail+=int(ff);exchange_fail+=int(ef);mass_fail+=int(mf)
        physical_fail+=int(hf or tf or ff or ef or mf)
        print(
          f"ELASTIC60_ADAPTIVE|profile={a.profile_id}|regime={reg}|h0={h}|delta={d}|dt={q2[2]:.17e}|status=QUALIFIED"
          f"|triple={n0}-{n1}-{n2}|head_bound={hb:.17e}|theta_bound={tb:.17e}|flux_bound={fb:.17e}|exchange_bound={eb:.17e}"
          f"|physical_pass={'T' if not (hf or tf or ff or ef or mf) else 'F'}"
        )

    if accepted+exhausted!=48:
        raise SystemExit(f"F_PE_ELASTIC60_FAIL sequence accounting profile={a.profile_id}")
    print(
      f"ELASTIC60_PROFILE|profile={a.profile_id}|accepted={accepted}|exhausted={exhausted}|n32_complete={n32_complete}"
      f"|adaptive_ok={adaptive_ok}|adaptive_unavailable={adaptive_unavailable}|no_success_triple={no_success_triple}"
      f"|contraction_fail={contraction_fail}|physical_fail={physical_fail}|head_fail={head_fail}|theta_fail={theta_fail}"
      f"|flux_fail={flux_fail}|exchange_fail={exchange_fail}|mass_fail={mass_fail}"
      f"|worst_head_bound={worst['head_bound']:.17e}|worst_theta_bound={worst['theta_bound']:.17e}"
      f"|worst_flux_bound={worst['flux_bound']:.17e}|worst_exchange_bound={worst['exchange_bound']:.17e}"
      f"|triples={selected_triples}"
    )
    print("F_PE_ELASTIC60_PROFILE=PASS")

if __name__=="__main__":
    main()
