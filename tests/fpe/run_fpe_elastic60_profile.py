#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

HEAD_LIMIT=0.01
THETA_LIMIT=1.0e-5
BINF_BUDGET=0.05773585599727987
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
        raise SystemExit(f"F_PE_ELASTIC60_FAIL executable rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC55_BANK|"):
            row=parse(line)
    if row is None: raise SystemExit("F_PE_ELASTIC60_FAIL missing row")
    return row

def semantic(r):
    keys=("full_status","half1_status","half2_status","all_converged","dh_inf","dtheta_inf",
          "indicator_available","indicator_binf","indicator_raw","indicator_defect","direct_dinf")
    return tuple(r.get(k) for k in keys)

def choose(seq, key, limit):
    for r in seq:
        if int(r["full_status"])!=1 or r["indicator_available"]!="T":
            continue
        x=float(r[key])
        if not math.isfinite(x) or x<0:
            raise SystemExit(f"F_PE_ELASTIC60_FAIL invalid {key}")
        if x <= limit*(1+1e-15):
            return r
    return None

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--profile-id",type=int,required=True)
    ap.add_argument("--o0",required=True)
    ap.add_argument("--o2",required=True)
    a=ap.parse_args()

    rows={}
    for tag,exe in (("O0",a.o0),("O2",a.o2)):
        rr=[]
        for h in HEADS:
            for d in DELTAS:
                for reg in REGIMES:
                    for idx,dt in enumerate(DTS):
                        r=execute(exe,reg,h,d,dt); r["_retry"]=idx
                        rr.append(r)
        rows[tag]=rr

    def key(r): return (r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]))
    a0={key(r):r for r in rows["O0"]}; a2={key(r):r for r in rows["O2"]}
    if set(a0)!=set(a2): raise SystemExit("F_PE_ELASTIC60_FAIL O0/O2 key drift")
    for k in a0:
        if semantic(a0[k])!=semantic(a2[k]):
            raise SystemExit(f"F_PE_ELASTIC60_FAIL O0/O2 drift {k}")
    print("F_PE_ELASTIC60_A2_O0_O2=PASS")

    rr=rows["O2"]
    direct_selected=[]; direct_exhausted=[]
    binf_selected=[]; binf_exhausted=[]
    paired_head_fail=0; paired_theta_fail=0
    sat_direct=0; sat_binf=0
    unsat_direct=0; unsat_binf=0
    per_reg={r:{"direct":0,"binf":0,"direct_exhausted":0,"binf_exhausted":0} for r in REGIMES}

    for h in HEADS:
        for d in DELTAS:
            for reg in REGIMES:
                seq=[r for r in rr if r["regime"]==reg and float(r["h0"])==h and float(r["delta"])==d]
                seq=sorted(seq,key=lambda r:r["_retry"])
                pd=choose(seq,"direct_dinf",HEAD_LIMIT)
                pb=choose(seq,"indicator_binf",BINF_BUDGET)

                if pd is None:
                    direct_exhausted.append((reg,h,d)); per_reg[reg]["direct_exhausted"]+=1
                else:
                    direct_selected.append(pd); per_reg[reg]["direct"]+=1
                    if h>=0: sat_direct+=1
                    else: unsat_direct+=1
                    if pd["all_converged"]=="T":
                        hinf=float(pd["dh_inf"]); tinf=float(pd["dtheta_inf"])
                        if hinf>HEAD_LIMIT*(1+1e-12): paired_head_fail+=1
                        if tinf>THETA_LIMIT*(1+1e-12): paired_theta_fail+=1

                if pb is None:
                    binf_exhausted.append((reg,h,d)); per_reg[reg]["binf_exhausted"]+=1
                else:
                    binf_selected.append(pb); per_reg[reg]["binf"]+=1
                    if h>=0: sat_binf+=1
                    else: unsat_binf+=1

    paired_direct=sum(1 for r in direct_selected if r["all_converged"]=="T")
    max_dinf=max((float(r["direct_dinf"]) for r in direct_selected),default=0.0)
    max_hinf=max((float(r["dh_inf"]) for r in direct_selected if r["all_converged"]=="T"),default=0.0)
    max_tinf=max((float(r["dtheta_inf"]) for r in direct_selected if r["all_converged"]=="T"),default=0.0)

    print(f"ELASTIC60_PROFILE_SUMMARY|profile={a.profile_id}|direct_selected={len(direct_selected)}|direct_exhausted={len(direct_exhausted)}|binf_selected={len(binf_selected)}|binf_exhausted={len(binf_exhausted)}|direct_paired={paired_direct}|paired_head_fail={paired_head_fail}|paired_theta_fail={paired_theta_fail}|sat_direct={sat_direct}|sat_binf={sat_binf}|unsat_direct={unsat_direct}|unsat_binf={unsat_binf}|max_selected_dinf={max_dinf:.17e}|max_paired_hinf={max_hinf:.17e}|max_paired_theta_inf={max_tinf:.17e}")
    for reg in REGIMES:
        x=per_reg[reg]
        print(f"ELASTIC60_REGIME_SUMMARY|profile={a.profile_id}|regime={reg}|direct_selected={x['direct']}|direct_exhausted={x['direct_exhausted']}|binf_selected={x['binf']}|binf_exhausted={x['binf_exhausted']}")
    print(f"ELASTIC60_DIRECT_HEAD_LIMIT_CM={HEAD_LIMIT:.17e}")
    print(f"ELASTIC60_BINF_BUDGET_CM={BINF_BUDGET:.17e}")
    print("F_PE_ELASTIC60_PROFILE=PASS")

if __name__=="__main__":
    main()
