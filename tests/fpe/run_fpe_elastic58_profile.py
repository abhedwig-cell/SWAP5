#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

ALPHA=0.17320259355765216
H_BUDGET=0.01
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(-75.0,-20.0,2.0,10.0)
DELTAS=(-0.05,-0.035,0.035,0.05)
DTS=(0.015625,0.0078125,0.00390625,0.001953125,0.0009765625,0.00048828125,0.000244140625,0.0001220703125,0.00006103515625)

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    return d

def call(exe,args,prefix):
    cp=subprocess.run([str(exe),*map(str,args)],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC58_FAIL executable rc={cp.returncode} exe={exe}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith(prefix):
            row=parse(line)
    if row is None:
        raise SystemExit(f"F_PE_ELASTIC58_FAIL missing {prefix} marker")
    return row

def selector_sem(r):
    keys=("full_status","half1_status","half2_status","all_converged",
          "indicator_available","indicator_binf","indicator_raw","indicator_defect")
    return tuple(r.get(k) for k in keys)

def oracle_sem(r):
    keys=("candidate_status","oracle_complete","dh_inf","dtheta_inf",
          "candidate_qbot","oracle_qbot","candidate_exchange","oracle_exchange",
          "candidate_mass","oracle_mass")
    return tuple(r.get(k) for k in keys)

def finite(x): return math.isfinite(float(x))

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--profile-id",type=int,required=True)
    ap.add_argument("--selector-o0",required=True)
    ap.add_argument("--selector-o2",required=True)
    ap.add_argument("--oracle-o0",required=True)
    ap.add_argument("--oracle-o2",required=True)
    a=ap.parse_args()

    accepted=0; exhausted=0; oracle_fail=0
    head_fail=theta_fail=q_fail=exchange_fail=mass_fail=0
    rows=[]
    max_head=max_theta=max_qrel=max_xrel=max_mass=0.0
    min_dt=None; max_dt=None

    for h0 in HEADS:
        for delta in DELTAS:
            for regime in REGIMES:
                chosen=None
                for idx,dt in enumerate(DTS):
                    r0=call(a.selector_o0,[regime,h0,delta,dt],"ELASTIC55_BANK|")
                    r2=call(a.selector_o2,[regime,h0,delta,dt],"ELASTIC55_BANK|")
                    if selector_sem(r0)!=selector_sem(r2):
                        raise SystemExit(f"F_PE_ELASTIC58_FAIL selector O0/O2 drift profile={a.profile_id} h0={h0} delta={delta} regime={regime} dt={dt}")
                    if int(r2["full_status"])!=1 or r2["indicator_available"]!="T":
                        continue
                    b=float(r2["indicator_binf"])
                    if not math.isfinite(b) or b<0:
                        raise SystemExit("F_PE_ELASTIC58_FAIL invalid Binf")
                    if ALPHA*b <= H_BUDGET*(1+1e-15):
                        chosen=(idx,dt,b)
                        break
                if chosen is None:
                    exhausted+=1
                    print(f"ELASTIC58_DECISION|profile={a.profile_id}|regime={regime}|h0={h0}|delta={delta}|decision=EXHAUSTED")
                    continue

                idx,dt,b=chosen
                accepted+=1
                min_dt=dt if min_dt is None else min(min_dt,dt)
                max_dt=dt if max_dt is None else max(max_dt,dt)

                o0=call(a.oracle_o0,[regime,h0,delta,dt],"ELASTIC58_ORACLE|")
                o2=call(a.oracle_o2,[regime,h0,delta,dt],"ELASTIC58_ORACLE|")
                if oracle_sem(o0)!=oracle_sem(o2):
                    raise SystemExit(f"F_PE_ELASTIC58_FAIL oracle O0/O2 drift profile={a.profile_id} h0={h0} delta={delta} regime={regime} dt={dt}")

                cstatus=int(o2["candidate_status"])
                complete=o2["oracle_complete"]=="T"
                if cstatus!=1 or not complete:
                    oracle_fail+=1
                    print(f"ELASTIC58_PHYSICAL_FAIL|profile={a.profile_id}|regime={regime}|h0={h0}|delta={delta}|dt={dt}|reason=ORACLE_INCOMPLETE|candidate_status={cstatus}|oracle_complete={o2['oracle_complete']}")
                    continue

                vals={k:float(o2[k]) for k in (
                    "dh_inf","dtheta_inf","candidate_qbot","oracle_qbot",
                    "candidate_exchange","oracle_exchange","candidate_mass","oracle_mass")}
                if not all(math.isfinite(v) for v in vals.values()):
                    raise SystemExit("F_PE_ELASTIC58_FAIL nonfinite physical oracle value")

                dh=abs(vals["dh_inf"])
                dtheta=abs(vals["dtheta_inf"])
                qden=max(abs(vals["oracle_qbot"]),1e-12)
                qrel=abs(vals["candidate_qbot"]-vals["oracle_qbot"])/qden
                xden=max(abs(vals["oracle_exchange"]),1e-12)
                xrel=abs(vals["candidate_exchange"]-vals["oracle_exchange"])/xden
                m=max(abs(vals["candidate_mass"]),abs(vals["oracle_mass"]))

                max_head=max(max_head,dh);max_theta=max(max_theta,dtheta)
                max_qrel=max(max_qrel,qrel);max_xrel=max(max_xrel,xrel);max_mass=max(max_mass,m)

                gates={
                    "head":dh<=0.01+1e-15,
                    "theta":dtheta<=1e-5+1e-15,
                    "q":qrel<=0.01+1e-15,
                    "exchange":xrel<=0.005+1e-15,
                    "mass":m<=1e-12+1e-18,
                }
                head_fail+=not gates["head"];theta_fail+=not gates["theta"]
                q_fail+=not gates["q"];exchange_fail+=not gates["exchange"];mass_fail+=not gates["mass"]
                pass_all=all(gates.values())

                print(
                    f"ELASTIC58_ACCEPT|profile={a.profile_id}|regime={regime}|h0={h0}|delta={delta}|retry={idx}|dt={dt}"
                    f"|binf={b:.17e}|predicted={ALPHA*b:.17e}|dh={dh:.17e}|dtheta={dtheta:.17e}"
                    f"|qrel={qrel:.17e}|xrel={xrel:.17e}|mass={m:.17e}|physical_pass={'T' if pass_all else 'F'}"
                )
                if not pass_all:
                    print(
                        f"ELASTIC58_PHYSICAL_FAIL|profile={a.profile_id}|regime={regime}|h0={h0}|delta={delta}|dt={dt}"
                        f"|head={'PASS' if gates['head'] else 'FAIL'}|theta={'PASS' if gates['theta'] else 'FAIL'}"
                        f"|q={'PASS' if gates['q'] else 'FAIL'}|exchange={'PASS' if gates['exchange'] else 'FAIL'}"
                        f"|mass={'PASS' if gates['mass'] else 'FAIL'}"
                    )
                rows.append((regime,h0,delta,dt,pass_all))

    failures=oracle_fail+head_fail+theta_fail+q_fail+exchange_fail+mass_fail
    print(
        f"ELASTIC58_PROFILE_SUMMARY|profile={a.profile_id}|accepted={accepted}|exhausted={exhausted}"
        f"|oracle_incomplete={oracle_fail}|head_fail={head_fail}|theta_fail={theta_fail}|q_fail={q_fail}"
        f"|exchange_fail={exchange_fail}|mass_fail={mass_fail}|max_head={max_head:.17e}|max_theta={max_theta:.17e}"
        f"|max_qrel={max_qrel:.17e}|max_xrel={max_xrel:.17e}|max_mass={max_mass:.17e}"
        f"|min_accepted_dt={min_dt}|max_accepted_dt={max_dt}"
    )
    print(f"ELASTIC58_ALPHA={ALPHA:.17e}")
    print(f"ELASTIC58_H_BUDGET={H_BUDGET:.17e}")
    print("F_PE_ELASTIC58_PROFILE=PASS")

if __name__=="__main__":
    main()
