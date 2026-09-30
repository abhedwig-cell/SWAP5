#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

HEAD_LIMIT=0.01
THETA_LIMIT=1e-5
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
        raise SystemExit(f"F_PE_ELASTIC59_FAIL executable rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC59_BANK|"): row=parse(line)
    if row is None: raise SystemExit("F_PE_ELASTIC59_FAIL missing row")
    return row

def sem(r):
    keys=("full_status","half1_status","half2_status","all_converged","dh_inf","dtheta_inf",
          "indicator_available","indicator_binf","indicator_raw","indicator_defect",
          "raw_head_inf","defect_head_inf","head_candidate")
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
                        r=execute(exe,reg,h,d,dt); r["_retry"]=idx
                        rr.append(r)
        rows[tag]=rr

    def key(r): return (r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]))
    a0={key(r):r for r in rows["O0"]}; a2={key(r):r for r in rows["O2"]}
    if set(a0)!=set(a2): raise SystemExit("F_PE_ELASTIC59_FAIL key drift")
    for k in a0:
        if sem(a0[k])!=sem(a2[k]): raise SystemExit(f"F_PE_ELASTIC59_FAIL O0/O2 {k}")
    print("F_PE_ELASTIC59_A2_O0_O2=PASS")

    rr=rows["O2"]
    full=[r for r in rr if int(r["full_status"])==1]
    for r in full:
        if r["indicator_available"]!="T": raise SystemExit("F_PE_ELASTIC59_FAIL converged full without indicator")
        vals=[float(r[k]) for k in ("raw_head_inf","defect_head_inf","head_candidate","indicator_binf")]
        if not all(math.isfinite(v) and v>=0 for v in vals):
            raise SystemExit("F_PE_ELASTIC59_FAIL invalid headspace metric")

    paired=[r for r in rr if r["all_converged"]=="T" and r["indicator_available"]=="T"]
    bound_fail=[]
    hc_ratios=[]; b_ratios=[]
    for r in paired:
        h=float(r["dh_inf"]); hc=float(r["head_candidate"]); b=float(r["indicator_binf"])
        if h>0 and hc>0: hc_ratios.append(hc/h)
        if h>0 and b>0: b_ratios.append(b/h)
        if h > hc*(1+1e-12):
            bound_fail.append((r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]),h,hc,b))

    selected=[]; exhausted=[]
    for h0 in HEADS:
        for d in DELTAS:
            for reg in REGIMES:
                seq=[r for r in rr if r["regime"]==reg and float(r["h0"])==h0 and float(r["delta"])==d]
                seq=sorted(seq,key=lambda r:r["_retry"])
                pick=None
                for r in seq:
                    if int(r["full_status"])!=1 or r["indicator_available"]!="T": continue
                    if float(r["head_candidate"]) <= HEAD_LIMIT*(1+1e-15):
                        pick=r; break
                if pick is None:
                    exhausted.append((reg,h0,d)); continue
                paired_pick=pick["all_converged"]=="T"
                hinf=float(pick["dh_inf"]) if paired_pick else math.nan
                tinf=float(pick["dtheta_inf"]) if paired_pick else math.nan
                selected.append((reg,h0,d,pick["_retry"],float(pick["dt"]),float(pick["head_candidate"]),paired_pick,hinf,tinf))

    selected_pair=[x for x in selected if x[6]]
    head_limit_fail=[x for x in selected_pair if x[7] > HEAD_LIMIT*(1+1e-12)]
    theta_limit_fail=[x for x in selected_pair if x[8] > THETA_LIMIT*(1+1e-12)]

    # Monotonicity comparison on sequences with >=3 full-converged available points.
    hc_seq=hc_bad=b_seq=b_bad=0
    for h0 in HEADS:
        for d in DELTAS:
            for reg in REGIMES:
                seq=[r for r in rr if r["regime"]==reg and float(r["h0"])==h0 and float(r["delta"])==d
                     and int(r["full_status"])==1 and r["indicator_available"]=="T"]
                seq=sorted(seq,key=lambda r:r["_retry"])
                if len(seq)>=3:
                    hc_seq+=1; b_seq+=1
                    hv=[float(r["head_candidate"]) for r in seq]
                    bv=[float(r["indicator_binf"]) for r in seq]
                    if any(hv[i+1] > hv[i]*(1+1e-12) for i in range(len(hv)-1)): hc_bad+=1
                    if any(bv[i+1] > bv[i]*(1+1e-12) for i in range(len(bv)-1)): b_bad+=1

    saturated_selected=sum(1 for x in selected if x[1]>0)
    unsat_selected=sum(1 for x in selected if x[1]<0)

    print(f"ELASTIC59_PROFILE_SUMMARY|profile={a.profile_id}|full={len(full)}|paired={len(paired)}|bound_failures={len(bound_fail)}|selected={len(selected)}|exhausted={len(exhausted)}|paired_selected={len(selected_pair)}|head_limit_failures={len(head_limit_fail)}|theta_limit_failures={len(theta_limit_fail)}|saturated_selected={saturated_selected}|unsaturated_selected={unsat_selected}|hcand_monotonic_sequences={hc_seq}|hcand_monotonic_violations={hc_bad}|binf_monotonic_sequences={b_seq}|binf_monotonic_violations={b_bad}")
    if hc_ratios:
        print(f"ELASTIC59_HCAND_RATIO|profile={a.profile_id}|min={min(hc_ratios):.17e}|max={max(hc_ratios):.17e}")
    if b_ratios:
        print(f"ELASTIC59_BINF_RATIO|profile={a.profile_id}|min={min(b_ratios):.17e}|max={max(b_ratios):.17e}")
    for x in bound_fail[:50]:
        print(f"ELASTIC59_BOUND_FAIL|profile={a.profile_id}|regime={x[0]}|h0={x[1]}|delta={x[2]}|dt={x[3]}|hinf={x[4]:.17e}|hcand={x[5]:.17e}|binf={x[6]:.17e}")
    for x in head_limit_fail[:50]:
        print(f"ELASTIC59_HEAD_LIMIT_FAIL|profile={a.profile_id}|regime={x[0]}|h0={x[1]}|delta={x[2]}|dt={x[4]}|hinf={x[7]:.17e}|hcand={x[5]:.17e}")
    for x in theta_limit_fail[:50]:
        print(f"ELASTIC59_THETA_LIMIT_FAIL|profile={a.profile_id}|regime={x[0]}|h0={x[1]}|delta={x[2]}|dt={x[4]}|dtheta={x[8]:.17e}|hcand={x[5]:.17e}")
    print("F_PE_ELASTIC59_PROFILE=PASS")

if __name__=="__main__":
    main()
