#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

ALPHA=0.17320259355765216
HEAD_LIMIT=0.01
BINF_LIMIT=0.05773585599727987
THETA_LIMIT=1.0e-5
FLUX_REL_LIMIT=0.01
EXCHANGE_REL_LIMIT=0.005
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(-75.0,-20.0,2.0,10.0)
DELTAS=(-0.05,-0.035,0.035,0.05)
DTS=tuple(0.015625*(0.5**i) for i in range(15))

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    return d

def execute(exe,reg,h,d,dt,oracle_n=0):
    cp=subprocess.run([str(exe),reg,repr(h),repr(d),repr(dt),str(oracle_n)],
                      text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC58_FAIL executable rc={cp.returncode} reg={reg} h={h} d={d} dt={dt} oracle={oracle_n}\n{cp.stdout}\n{cp.stderr}")
    row=None; oracle=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC55_BANK|"): row=parse(line)
        elif line.startswith("ELASTIC58_ORACLE|"): oracle=parse(line)
    if row is None:
        raise SystemExit("F_PE_ELASTIC58_FAIL missing bank row")
    if oracle_n>0 and oracle is None:
        raise SystemExit("F_PE_ELASTIC58_FAIL missing oracle row")
    return row,oracle

def sem(r):
    keys=("full_status","indicator_available","indicator_binf")
    return tuple(r.get(k) for k in keys)

def decide(exe,reg,h,d):
    trace=[]
    for idx,dt in enumerate(DTS):
        r,_=execute(exe,reg,h,d,dt,0)
        trace.append((idx,dt,r))
        if int(r["full_status"])==1 and r["indicator_available"]=="T":
            b=float(r["indicator_binf"])
            if not math.isfinite(b) or b<0:
                raise SystemExit("F_PE_ELASTIC58_FAIL invalid Binf")
            if b<=BINF_LIMIT:
                return {"status":"ACCEPT","idx":idx,"dt":dt,"row":r,"trace":trace}
    return {"status":"EXHAUSTED","idx":None,"dt":None,"row":None,"trace":trace}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--profile-id",type=int,required=True)
    ap.add_argument("--o0",required=True)
    ap.add_argument("--o2",required=True)
    a=ap.parse_args()

    sequences=accepted=exhausted=oracle_ok=oracle_unavailable=0
    head_fail=theta_fail=flux_fail=exchange_fail=mass_fail=0
    worst_head=worst_theta=worst_flux=worst_exchange=0.0
    accept_levels=[]
    per_reg={r:{"accepted":0,"exhausted":0,"oracle_ok":0} for r in REGIMES}

    for h in HEADS:
      for d in DELTAS:
       for reg in REGIMES:
        sequences+=1
        d0=decide(a.o0,reg,h,d)
        d2=decide(a.o2,reg,h,d)
        if d0["status"]!=d2["status"] or d0["idx"]!=d2["idx"]:
            raise SystemExit(f"F_PE_ELASTIC58_FAIL O0/O2 decision drift profile={a.profile_id} reg={reg} h={h} d={d}")
        # All observed scan semantics up to the shared decision must match.
        n=min(len(d0["trace"]),len(d2["trace"]))
        for j in range(n):
            if sem(d0["trace"][j][2])!=sem(d2["trace"][j][2]):
                raise SystemExit(f"F_PE_ELASTIC58_FAIL O0/O2 scan drift profile={a.profile_id} reg={reg} h={h} d={d} idx={j}")

        if d2["status"]=="EXHAUSTED":
            exhausted+=1; per_reg[reg]["exhausted"]+=1
            print(f"ELASTIC58_DECISION|profile={a.profile_id}|regime={reg}|h0={h}|delta={d}|status=EXHAUSTED|levels={len(d2['trace'])}")
            continue

        accepted+=1; per_reg[reg]["accepted"]+=1; accept_levels.append(d2["idx"])
        row,oracle=execute(a.o2,reg,h,d,d2["dt"],32)
        # Accepted point must still satisfy controller criterion on replay.
        if int(row["full_status"])!=1 or row["indicator_available"]!="T" or float(row["indicator_binf"])>BINF_LIMIT*(1+1e-14):
            raise SystemExit("F_PE_ELASTIC58_FAIL accepted replay mismatch")
        complete=oracle["oracle_complete"]=="T"
        massok=oracle["oracle_mass_ok"]=="T"
        if not complete:
            oracle_unavailable+=1
            print(f"ELASTIC58_DECISION|profile={a.profile_id}|regime={reg}|h0={h}|delta={d}|status=ACCEPT_ORACLE_UNAVAILABLE|retry={d2['idx']}|dt={d2['dt']:.17e}|binf={float(row['indicator_binf']):.17e}")
            continue
        if not massok:
            mass_fail+=1
        oracle_ok+=1; per_reg[reg]["oracle_ok"]+=1
        dh=float(oracle["oracle_dh"]); dteta=float(oracle["oracle_dtheta"])
        frel=float(oracle["oracle_flux_rel"]); erel=float(oracle["oracle_exchange_rel"])
        vals=(dh,dteta,frel,erel,float(oracle["max_ledger_residual"]))
        if not all(math.isfinite(v) and v>=0 for v in vals):
            raise SystemExit("F_PE_ELASTIC58_FAIL nonfinite oracle metric")
        worst_head=max(worst_head,dh); worst_theta=max(worst_theta,dteta)
        worst_flux=max(worst_flux,frel); worst_exchange=max(worst_exchange,erel)
        hf=dh>HEAD_LIMIT*(1+1e-12); tf=dteta>THETA_LIMIT*(1+1e-12)
        ff=frel>FLUX_REL_LIMIT*(1+1e-12); ef=erel>EXCHANGE_REL_LIMIT*(1+1e-12)
        head_fail+=int(hf); theta_fail+=int(tf); flux_fail+=int(ff); exchange_fail+=int(ef)
        print(
          f"ELASTIC58_ORACLE_RESULT|profile={a.profile_id}|regime={reg}|h0={h}|delta={d}"
          f"|retry={d2['idx']}|dt={d2['dt']:.17e}|binf={float(row['indicator_binf']):.17e}"
          f"|dh={dh:.17e}|dtheta={dteta:.17e}|flux_rel={frel:.17e}|exchange_rel={erel:.17e}"
          f"|mass_ok={'T' if massok else 'F'}"
          f"|head_pass={'F' if hf else 'T'}|theta_pass={'F' if tf else 'T'}"
          f"|flux_pass={'F' if ff else 'T'}|exchange_pass={'F' if ef else 'T'}"
        )

    if sequences!=48:
        raise SystemExit(f"F_PE_ELASTIC58_FAIL sequences={sequences}")
    print(
      f"ELASTIC58_PROFILE_SUMMARY|profile={a.profile_id}|sequences={sequences}|accepted={accepted}|exhausted={exhausted}"
      f"|oracle_ok={oracle_ok}|oracle_unavailable={oracle_unavailable}|mass_fail={mass_fail}"
      f"|head_fail={head_fail}|theta_fail={theta_fail}|flux_fail={flux_fail}|exchange_fail={exchange_fail}"
      f"|worst_head={worst_head:.17e}|worst_theta={worst_theta:.17e}"
      f"|worst_flux_rel={worst_flux:.17e}|worst_exchange_rel={worst_exchange:.17e}"
      f"|max_accept_retry={max(accept_levels) if accept_levels else -1}"
    )
    for reg,v in per_reg.items():
        print(f"ELASTIC58_REGIME|profile={a.profile_id}|regime={reg}|accepted={v['accepted']}|exhausted={v['exhausted']}|oracle_ok={v['oracle_ok']}")
    print(f"ELASTIC58_FROZEN|alpha={ALPHA:.17e}|head_limit={HEAD_LIMIT:.17e}|binf_limit={BINF_LIMIT:.17e}|theta_limit={THETA_LIMIT:.17e}|flux_rel_limit={FLUX_REL_LIMIT:.17e}|exchange_rel_limit={EXCHANGE_REL_LIMIT:.17e}")
    print("F_PE_ELASTIC58_PROFILE=PASS")

if __name__=="__main__":
    main()
