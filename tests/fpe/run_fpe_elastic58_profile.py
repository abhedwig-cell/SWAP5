#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

ALPHA=0.17320259355765216
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(-75.0,-20.0,2.0,10.0)
DELTAS=(-0.05,-0.035,0.035,0.05)
DTS=(0.015625,0.0078125,0.00390625,0.001953125,0.0009765625,0.00048828125,0.000244140625,0.0001220703125,0.00006103515625)

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" in p:
            k,v=p.split("=",1); d[k]=v.strip()
    return d

def run(exe,reg,h,d,dt):
    cp=subprocess.run([exe,reg,repr(h),repr(d),repr(dt)],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC58_FAIL executable rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC58_METRIC|"): row=parse(line)
    if row is None: raise SystemExit("F_PE_ELASTIC58_FAIL missing metric row")
    return row

def sem(r):
    keys=("full_status","half1_status","half2_status","all_converged","dh_inf","dtheta_inf","dpond","dgwl",
          "storage_signed","storage_l1","qbot_diff","qbot_rel","indicator_available","indicator_binf")
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
                    for dt in DTS:
                        rr.append(run(exe,reg,h,d,dt))
        rows[tag]=rr
    def key(r): return (r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]))
    a0={key(r):r for r in rows["O0"]}; a2={key(r):r for r in rows["O2"]}
    if set(a0)!=set(a2): raise SystemExit("F_PE_ELASTIC58_FAIL key drift")
    for k in a0:
        if sem(a0[k])!=sem(a2[k]): raise SystemExit(f"F_PE_ELASTIC58_FAIL O0/O2 {k}")
    rr=rows["O2"]
    paired=[r for r in rr if r["all_converged"]=="T" and r["indicator_available"]=="T"]
    if not paired: raise SystemExit("F_PE_ELASTIC58_FAIL no paired cases")
    metrics=("dh_inf","dtheta_inf","storage_signed","storage_l1","dpond","dgwl","qbot_diff","qbot_rel")
    maxima={m:max(float(r[m]) for r in paired) for m in metrics}
    max_ratio=max(float(r["dh_inf"])/(ALPHA*float(r["indicator_binf"])) for r in paired if float(r["indicator_binf"])>0)
    nonzero={m:sum(float(r[m])>0 for r in paired) for m in metrics}
    for r in paired:
        vals=[float(r[m]) for m in metrics]
        if not all(math.isfinite(v) and v>=0 for v in vals): raise SystemExit("F_PE_ELASTIC58_FAIL invalid metric")
        if float(r["storage_signed"]) > float(r["storage_l1"])+64*2.220446049250313e-16*max(1.0,float(r["storage_l1"])):
            raise SystemExit("F_PE_ELASTIC58_FAIL storage inequality")
        if float(r["dh_inf"]) > ALPHA*float(r["indicator_binf"])*(1+1e-12):
            raise SystemExit("F_PE_ELASTIC58_FAIL frozen envelope")
    print("ELASTIC58_PROFILE|profile=%d|paired=%d|max_h=%.17e|max_theta=%.17e|max_storage_signed=%.17e|max_storage_l1=%.17e|max_pond=%.17e|max_gwl=%.17e|max_qbot=%.17e|max_qbot_rel=%.17e|max_h_over_envelope=%.17e"%
          (a.profile_id,len(paired),maxima["dh_inf"],maxima["dtheta_inf"],maxima["storage_signed"],maxima["storage_l1"],maxima["dpond"],maxima["dgwl"],maxima["qbot_diff"],maxima["qbot_rel"],max_ratio))
    print("ELASTIC58_NONZERO|profile=%d|"%a.profile_id+"|".join(f"{m}={nonzero[m]}" for m in metrics))
    print("F_PE_ELASTIC58_PROFILE=PASS")
if __name__=="__main__": main()
