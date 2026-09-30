#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

BINF_LIMIT=0.05773585599727987
HEAD_LIMIT=0.01
THETA_LIMIT=1.0e-5
FLUX_LIMIT=0.01
EXCHANGE_LIMIT=0.005
MASS_TOL=1.0e-12
FACTOR=3.0
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(-75.0,-20.0,2.0,10.0)
DELTAS=(-0.05,-0.035,0.035,0.05)
DTS=tuple(0.015625*(0.5**i) for i in range(15))
NS=(2,4,8,16,32,64)
TRIPLES=((16,32,64),(8,16,32),(4,8,16),(2,4,8))
PAIRS=((32,64),(16,32),(8,16),(4,8),(2,4))
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

def execute(exe,reg,h,d,dt,n=0):
    cp=subprocess.run([str(exe),reg,repr(h),repr(d),repr(dt),str(n)],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC61_FAIL executable rc={cp.returncode} reg={reg} h={h} d={d} dt={dt} N={n}\n{cp.stdout}\n{cp.stderr}")
    row=oracle=heads=theta=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC55_BANK|"): row=parse_pipe(line)
        elif line.startswith("ELASTIC60_ORACLE|"): oracle=parse_pipe(line)
        elif line.startswith("ELASTIC60_HEADS"): heads=parse_state(line,"ELASTIC60_HEADS")
        elif line.startswith("ELASTIC60_THETA"): theta=parse_state(line,"ELASTIC60_THETA")
    if row is None: raise SystemExit("F_PE_ELASTIC61_FAIL missing row")
    if n>0 and oracle is None: raise SystemExit("F_PE_ELASTIC61_FAIL missing oracle")
    return row,oracle,heads,theta

def sem(r):
    return (r.get("full_status"),r.get("indicator_available"),r.get("indicator_binf"))

def decide(exe,reg,h,d):
    trace=[]
    for idx,dt in enumerate(DTS):
        r,_,_,_=execute(exe,reg,h,d,dt,0); trace.append(r)
        if int(r["full_status"])==1 and r["indicator_available"]=="T" and float(r["indicator_binf"])<=BINF_LIMIT:
            return ("ACCEPT",idx,dt,r,trace)
    return ("EXHAUSTED",None,None,None,trace)

def maxdiff(a,b): return max(abs(x-y) for x,y in zip(a,b))
def contraction(d1,d2,floor): return d2 <= 0.75*d1 + floor

def metrics(a,b):
    return {
        "head":maxdiff(a["heads"],b["heads"]),
        "theta":maxdiff(a["theta"],b["theta"]),
        "flux":abs(a["flux"]-b["flux"]),
        "exchange":abs(a["exchange"]-b["exchange"]),
    }

def candidate_bounds(fine,D):
    return {
        "head":fine["cand_head"]+FACTOR*D["head"],
        "theta":fine["cand_theta"]+FACTOR*D["theta"],
        "flux":(fine["cand_flux_abs"]+FACTOR*D["flux"])/max(abs(fine["flux"]),1e-12),
        "exchange":(fine["cand_exchange_abs"]+FACTOR*D["exchange"])/max(abs(fine["exchange"]),1e-12),
    }

def physical_pass(b):
    return b["head"]<=HEAD_LIMIT*(1+1e-12) and b["theta"]<=THETA_LIMIT*(1+1e-12) and \
           b["flux"]<=FLUX_LIMIT*(1+1e-12) and b["exchange"]<=EXCHANGE_LIMIT*(1+1e-12)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--profile-id",type=int,required=True)
    ap.add_argument("--o0",required=True); ap.add_argument("--o2",required=True)
    a=ap.parse_args()

    accepted=exhausted=0
    validation=validation_tail_fail=validation_physical_fail=0
    residual=0; residual_pair=0; residual_no_pair=0; residual_physical_pass=0; residual_physical_fail=0
    parent_triple=0; parent_unavailable=0

    for h in HEADS:
      for d in DELTAS:
       for reg in REGIMES:
        q0=decide(a.o0,reg,h,d); q2=decide(a.o2,reg,h,d)
        if q0[:3]!=q2[:3]: raise SystemExit("F_PE_ELASTIC61_FAIL O0/O2 decision drift")
        for r0,r2 in zip(q0[4],q2[4]):
            if sem(r0)!=sem(r2): raise SystemExit("F_PE_ELASTIC61_FAIL O0/O2 scan drift")
        if q2[0]=="EXHAUSTED":
            exhausted+=1; continue
        accepted+=1
        rec={}
        for n in NS:
            _,o,hs,ts=execute(a.o2,reg,h,d,q2[2],n)
            if o["oracle_complete"]=="T":
                massok=o["oracle_mass_ok"]=="T" and abs(float(o["full_ledger_residual"]))<=MASS_TOL
                rec[n]={
                    "heads":hs,"theta":ts,"massok":massok,
                    "flux":float(o["oracle_flux_final"]),"exchange":float(o["oracle_exchange"]),
                    "cand_head":float(o["oracle_dh"]),"cand_theta":float(o["oracle_dtheta"]),
                    "cand_flux_abs":abs(float(o["full_flux"])-float(o["oracle_flux_final"])),
                    "cand_exchange_abs":abs(float(o["full_exchange"])-float(o["oracle_exchange"])),
                }

        selected=None
        for n0,n1,n2 in TRIPLES:
            if not all(n in rec and rec[n]["massok"] for n in (n0,n1,n2)): continue
            D1=metrics(rec[n0],rec[n1]); D2=metrics(rec[n1],rec[n2])
            if all(contraction(D1[k],D2[k],FLOORS[k]) for k in FLOORS):
                selected=(n0,n1,n2,D1,D2); break

        if selected is not None:
            parent_triple+=1
            validation+=1
            n0,n1,n2,D1,D2=selected
            tailok=all(D2[k] <= FACTOR*D1[k] + FLOORS[k] for k in FLOORS)
            b=candidate_bounds(rec[n1],D1)
            pok=physical_pass(b) and rec[n0]["massok"] and rec[n1]["massok"] and rec[n2]["massok"]
            validation_tail_fail+=int(not tailok)
            validation_physical_fail+=int(not pok)
            print(
              f"ELASTIC61_VALIDATION|profile={a.profile_id}|regime={reg}|h0={h}|delta={d}|dt={q2[2]:.17e}"
              f"|triple={n0}-{n1}-{n2}|tail_pass={'T' if tailok else 'F'}|physical_pass={'T' if pok else 'F'}"
              f"|head_bound={b['head']:.17e}|theta_bound={b['theta']:.17e}|flux_bound={b['flux']:.17e}|exchange_bound={b['exchange']:.17e}"
            )
            continue

        parent_unavailable+=1
        residual+=1
        pair=None
        for n0,n1 in PAIRS:
            if n0 in rec and n1 in rec and rec[n0]["massok"] and rec[n1]["massok"]:
                pair=(n0,n1); break
        if pair is None:
            residual_no_pair+=1
            print(f"ELASTIC61_RESIDUAL|profile={a.profile_id}|regime={reg}|h0={h}|delta={d}|dt={q2[2]:.17e}|status=NO_PAIR")
            continue
        residual_pair+=1
        n0,n1=pair; D=metrics(rec[n0],rec[n1]); b=candidate_bounds(rec[n1],D)
        pok=physical_pass(b)
        residual_physical_pass+=int(pok); residual_physical_fail+=int(not pok)
        print(
          f"ELASTIC61_RESIDUAL|profile={a.profile_id}|regime={reg}|h0={h}|delta={d}|dt={q2[2]:.17e}"
          f"|status=PAIR|pair={n0}-{n1}|physical_pass={'T' if pok else 'F'}"
          f"|head_bound={b['head']:.17e}|theta_bound={b['theta']:.17e}|flux_bound={b['flux']:.17e}|exchange_bound={b['exchange']:.17e}"
        )

    if accepted+exhausted!=48: raise SystemExit("F_PE_ELASTIC61_FAIL sequence accounting")
    print(
      f"ELASTIC61_PROFILE|profile={a.profile_id}|accepted={accepted}|exhausted={exhausted}"
      f"|parent_triple={parent_triple}|parent_unavailable={parent_unavailable}"
      f"|validation={validation}|validation_tail_fail={validation_tail_fail}|validation_physical_fail={validation_physical_fail}"
      f"|residual={residual}|residual_pair={residual_pair}|residual_no_pair={residual_no_pair}"
      f"|residual_physical_pass={residual_physical_pass}|residual_physical_fail={residual_physical_fail}"
    )
    print("F_PE_ELASTIC61_PROFILE=PASS")

if __name__=="__main__":
    main()
