#!/usr/bin/env python3
from __future__ import annotations
import argparse,subprocess,math

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
        raise SystemExit(f"F_PE_ELASTIC61_FAIL calibration rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC59_BANK|"): row=parse(line)
    if row is None: raise SystemExit("F_PE_ELASTIC61_FAIL calibration missing row")
    return row

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--profile-id",type=int,required=True)
    ap.add_argument("--exe",required=True)
    a=ap.parse_args()

    ratios=[]
    paired=0
    for h in HEADS:
        for d in DELTAS:
            for reg in REGIMES:
                for dt in DTS:
                    r=execute(a.exe,reg,h,d,dt)
                    if r["all_converged"]=="T" and r["indicator_available"]=="T":
                        hinf=float(r["dh_inf"]); defect=float(r["defect_head_inf"])
                        if hinf>0 and defect>0:
                            ratio=hinf/defect
                            if not math.isfinite(ratio) or ratio<0:
                                raise SystemExit("F_PE_ELASTIC61_FAIL invalid calibration ratio")
                            ratios.append((ratio,reg,h,d,dt,hinf,defect))
                            paired+=1
    if not ratios: raise SystemExit("F_PE_ELASTIC61_FAIL no calibration pairs")
    worst=max(ratios,key=lambda x:x[0])
    print(f"ELASTIC61_CAL_PROFILE|profile={a.profile_id}|paired={paired}|alpha_local={worst[0]:.17e}|regime={worst[1]}|h0={worst[2]}|delta={worst[3]}|dt={worst[4]}|hinf={worst[5]:.17e}|defect={worst[6]:.17e}")
    print("F_PE_ELASTIC61_CAL_PROFILE=PASS")
if __name__=="__main__": main()
