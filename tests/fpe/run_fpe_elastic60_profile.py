#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

HEAD_LIMIT=0.01
THETA_LIMIT=1e-5
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(2.0,10.0)
DELTAS=(-0.05,-0.035,0.035,0.05)
DTS=(0.015625,0.0078125,0.00390625,0.001953125,0.0009765625,0.00048828125,0.000244140625,0.0001220703125,0.00006103515625)

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    return d

def run(exe,reg,h,d,dt):
    cp=subprocess.run([str(exe),reg,repr(h),repr(d),repr(dt)],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC60_FAIL executable rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC59_BANK|"): row=parse(line)
    if row is None: raise SystemExit("F_PE_ELASTIC60_FAIL missing row")
    return row

def sem(r):
    keys=("full_status","half1_status","half2_status","all_converged","dh_inf","dtheta_inf",
          "indicator_available","head_candidate","raw_head_inf","defect_head_inf")
    return tuple(r.get(k) for k in keys)

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
                        r=run(exe,reg,h,d,dt); r["_retry"]=idx
                        rr.append(r)
        rows[tag]=rr

    def key(r): return (r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]))
    a0={key(r):r for r in rows["O0"]}; a2={key(r):r for r in rows["O2"]}
    if set(a0)!=set(a2): raise SystemExit("F_PE_ELASTIC60_FAIL key drift")
    for k in a0:
        if sem(a0[k])!=sem(a2[k]): raise SystemExit(f"F_PE_ELASTIC60_FAIL O0/O2 {k}")
    print("F_PE_ELASTIC60_A2_O0_O2=PASS")

    rr=rows["O2"]
    classes=[]
    for h in HEADS:
        for d in DELTAS:
            for reg in REGIMES:
                seq=[r for r in rr if r["regime"]==reg and float(r["h0"])==h and float(r["delta"])==d]
                seq=sorted(seq,key=lambda r:r["_retry"])
                avail=[r for r in seq if int(r["full_status"])==1 and r["indicator_available"]=="T"]
                paired=[r for r in seq if r["all_converged"]=="T" and r["indicator_available"]=="T"]
                oracle_ok=[r for r in paired if float(r["dh_inf"]) <= HEAD_LIMIT*(1+1e-12)]
                bound_ok=[r for r in avail if float(r["head_candidate"]) <= HEAD_LIMIT*(1+1e-12)]
                if bound_ok:
                    cls="BOUND_REACHABLE"
                elif oracle_ok:
                    cls="BOUND_OVERCONSERVATIVE"
                else:
                    cls="ORACLE_INFEASIBLE"

                min_h=min((float(r["dh_inf"]) for r in paired),default=math.nan)
                min_h_dt=next((float(r["dt"]) for r in paired if float(r["dh_inf"])==min_h),math.nan) if paired else math.nan
                min_c=min((float(r["head_candidate"]) for r in avail),default=math.nan)
                min_c_dt=next((float(r["dt"]) for r in avail if float(r["head_candidate"])==min_c),math.nan) if avail else math.nan
                first_o=oracle_ok[0] if oracle_ok else None
                first_b=bound_ok[0] if bound_ok else None

                if first_b is not None and first_b["all_converged"]=="T":
                    hinf=float(first_b["dh_inf"]); tinf=float(first_b["dtheta_inf"])
                    if hinf > HEAD_LIMIT*(1+1e-12) or tinf > THETA_LIMIT*(1+1e-12):
                        raise SystemExit("F_PE_ELASTIC60_FAIL reachable paired physical limit")

                rec=(cls,reg,h,d,len(avail),len(paired),min_h,min_h_dt,min_c,min_c_dt,
                     float(first_o["dt"]) if first_o else math.nan,
                     float(first_b["dt"]) if first_b else math.nan)
                classes.append(rec)
                print(f"ELASTIC60_CLASS|profile={a.profile_id}|class={cls}|regime={reg}|h0={h}|delta={d}|available={len(avail)}|paired={len(paired)}|min_hinf={min_h}|min_hinf_dt={min_h_dt}|min_hcand={min_c}|min_hcand_dt={min_c_dt}|first_oracle_ok_dt={rec[10]}|first_bound_ok_dt={rec[11]}")

    counts={k:sum(1 for x in classes if x[0]==k) for k in ("ORACLE_INFEASIBLE","BOUND_OVERCONSERVATIVE","BOUND_REACHABLE")}
    print(f"ELASTIC60_PROFILE_SUMMARY|profile={a.profile_id}|oracle_infeasible={counts['ORACLE_INFEASIBLE']}|bound_overconservative={counts['BOUND_OVERCONSERVATIVE']}|bound_reachable={counts['BOUND_REACHABLE']}")
    print("F_PE_ELASTIC60_PROFILE=PASS")

if __name__=="__main__":
    main()
