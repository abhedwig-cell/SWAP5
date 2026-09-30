#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

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
    if row is None:
        raise SystemExit("F_PE_ELASTIC59_FAIL missing row")
    return row

def semantic(r):
    keys=("full_status","half1_status","half2_status","all_converged","dh_inf",
          "indicator_available","indicator_binf","indicator_raw","indicator_defect",
          "raw_head_inf","defect_head_inf")
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
                    for dt in DTS:
                        rr.append(execute(exe,reg,h,d,dt))
        rows[tag]=rr

    if len(rows["O0"])!=432 or len(rows["O2"])!=432:
        raise SystemExit("F_PE_ELASTIC59_FAIL row count")

    def key(r): return (r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]))
    a0={key(r):r for r in rows["O0"]}; a2={key(r):r for r in rows["O2"]}
    if set(a0)!=set(a2): raise SystemExit("F_PE_ELASTIC59_FAIL key drift")
    for k in a0:
        if semantic(a0[k])!=semantic(a2[k]):
            raise SystemExit(f"F_PE_ELASTIC59_FAIL O0/O2 drift {k}")
    print("F_PE_ELASTIC59_A3_O0_O2=PASS")

    full=[r for r in rows["O2"] if int(r["full_status"])==1]
    for r in full:
        if r["indicator_available"]!="T":
            raise SystemExit("F_PE_ELASTIC59_FAIL full without indicator")
        for k in ("indicator_binf","raw_head_inf","defect_head_inf"):
            v=float(r[k])
            if not math.isfinite(v) or v<0:
                raise SystemExit(f"F_PE_ELASTIC59_FAIL invalid {k}")
    print("F_PE_ELASTIC59_A4_DIRECT_HEAD=PASS")

    paired=[r for r in rows["O2"] if r["all_converged"]=="T" and r["indicator_available"]=="T" and float(r["dh_inf"])>0]
    stats={}
    for domain,pred in (("UNSAT",lambda h:h<0),("SAT",lambda h:h>=0),("ALL",lambda h:True)):
        rr=[r for r in paired if pred(float(r["h0"]))]
        vals=[]
        c1fail=c2fail=c3fail=0
        for r in rr:
            h=float(r["dh_inf"]); b=float(r["indicator_binf"])
            raw=float(r["raw_head_inf"]); defect=float(r["defect_head_inf"]); two=2.0*defect
            if raw+1e-15<h: c1fail+=1
            if defect+1e-15<h: c2fail+=1
            if two+1e-15<h: c3fail+=1
            vals.append((b/h,raw/h,defect/h,two/h,b/two if two>0 else math.inf))
        if vals:
            stats[domain]=dict(
                paired=len(rr),
                binf_min=min(v[0] for v in vals),binf_max=max(v[0] for v in vals),
                raw_min=min(v[1] for v in vals),raw_max=max(v[1] for v in vals),
                defect_min=min(v[2] for v in vals),defect_max=max(v[2] for v in vals),
                two_min=min(v[3] for v in vals),two_max=max(v[3] for v in vals),
                amp_min=min(v[4] for v in vals),amp_max=max(v[4] for v in vals),
                c1fail=c1fail,c2fail=c2fail,c3fail=c3fail
            )
            s=stats[domain]
            print(f"ELASTIC59_DOMAIN|profile={a.profile_id}|domain={domain}|paired={s['paired']}|binf_over_h_min={s['binf_min']:.17e}|binf_over_h_max={s['binf_max']:.17e}|raw_over_h_min={s['raw_min']:.17e}|raw_over_h_max={s['raw_max']:.17e}|defect_over_h_min={s['defect_min']:.17e}|defect_over_h_max={s['defect_max']:.17e}|two_defect_over_h_min={s['two_min']:.17e}|two_defect_over_h_max={s['two_max']:.17e}|binf_over_two_defect_min={s['amp_min']:.17e}|binf_over_two_defect_max={s['amp_max']:.17e}|raw_failures={c1fail}|defect_failures={c2fail}|two_defect_failures={c3fail}")
    print(f"ELASTIC59_PROFILE_SUMMARY|profile={a.profile_id}|full_converged={len(full)}|paired={len(paired)}")
    print("F_PE_ELASTIC59_PROFILE=PASS")

if __name__=="__main__":
    main()
