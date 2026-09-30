#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

ALPHA=0.17320259355765216
HEAD_LIMIT=0.01
THETA_LIMIT=1.0e-5
BUDGET=0.05773585599727987
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

def execute(exe,reg,h,d,dt):
    cp=subprocess.run([str(exe),reg,repr(h),repr(d),repr(dt)],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC58_FAIL executable rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC55_BANK|"): row=parse(line)
    if row is None: raise SystemExit("F_PE_ELASTIC58_FAIL missing row")
    return row

def sem(r):
    keys=("full_status","half1_status","half2_status","all_converged","dh_inf","dtheta_inf",
          "indicator_available","indicator_binf","indicator_raw","indicator_defect")
    return tuple(r.get(k) for k in keys)

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
    if set(a0)!=set(a2): raise SystemExit("F_PE_ELASTIC58_FAIL key drift")
    for k in a0:
        if sem(a0[k])!=sem(a2[k]): raise SystemExit(f"F_PE_ELASTIC58_FAIL O0/O2 {k}")

    accepted=[]; exhausted=0
    for h in HEADS:
        for d in DELTAS:
            for reg in REGIMES:
                seq=[r for r in rows["O2"] if r["regime"]==reg and float(r["h0"])==h and float(r["delta"])==d]
                seq=sorted(seq,key=lambda r:r["_retry"])
                chosen=None
                for r in seq:
                    if int(r["full_status"])!=1 or r["indicator_available"]!="T": continue
                    if float(r["indicator_binf"]) <= BUDGET*(1+1e-15):
                        chosen=r; break
                if chosen is None:
                    exhausted+=1
                else:
                    accepted.append(chosen)

    paired=[r for r in accepted if r["all_converged"]=="T"]
    unpaired=[r for r in accepted if r["all_converged"]!="T"]
    head_fail=[]; theta_fail=[]; env_fail=[]
    for r in paired:
        h=float(r["dh_inf"]); th=float(r["dtheta_inf"]); b=float(r["indicator_binf"])
        if h > HEAD_LIMIT*(1+1e-12): head_fail.append(r)
        if th > THETA_LIMIT*(1+1e-12): theta_fail.append(r)
        if h > ALPHA*b*(1+1e-12): env_fail.append(r)

    print(f"ELASTIC58_PROFILE_SUMMARY|profile={a.profile_id}|accepted={len(accepted)}|paired={len(paired)}|unpaired={len(unpaired)}|exhausted={exhausted}|head_failures={len(head_fail)}|theta_failures={len(theta_fail)}|envelope_failures={len(env_fail)}")
    for r in unpaired:
        print(f"ELASTIC58_UNPAIRED|profile={a.profile_id}|regime={r['regime']}|h0={r['h0']}|delta={r['delta']}|dt={r['dt']}|binf={r['indicator_binf']}")
    for label,items in (("HEAD",head_fail),("THETA",theta_fail),("ENVELOPE",env_fail)):
        for r in items:
            print(f"ELASTIC58_{label}_FAIL|profile={a.profile_id}|regime={r['regime']}|h0={r['h0']}|delta={r['delta']}|dt={r['dt']}|binf={r['indicator_binf']}|hinf={r['dh_inf']}|dtheta={r['dtheta_inf']}")
    print(f"ELASTIC58_BUDGET={BUDGET:.17e}")
    print("F_PE_ELASTIC58_PROFILE=PASS")

if __name__=="__main__":
    main()
