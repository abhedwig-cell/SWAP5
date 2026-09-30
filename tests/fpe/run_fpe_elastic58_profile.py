#!/usr/bin/env python3
from __future__ import annotations
import argparse, subprocess

ALPHA=0.17320259355765216
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
        if line.startswith("ELASTIC55_BANK|"):
            row=parse(line)
    if row is None: raise SystemExit("F_PE_ELASTIC58_FAIL missing bank row")
    return row

def sem(r):
    ks=("full_status","half1_status","half2_status","all_converged","dh_inf","indicator_available","indicator_binf")
    return tuple(r.get(k) for k in ks)

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
    print("F_PE_ELASTIC58_PROFILE_O0_O2=PASS")

    seq_count=0; avail_count=0
    rr=rows["O2"]
    for h in HEADS:
      for d in DELTAS:
       for reg in REGIMES:
        seq_count+=1
        seq=sorted([r for r in rr if r["regime"]==reg and float(r["h0"])==h and float(r["delta"])==d],
                   key=lambda r:r["_retry"])
        for r in seq:
            if int(r["full_status"])!=1 or r["indicator_available"]!="T": continue
            avail_count+=1
            b=float(r["indicator_binf"]); e=ALPHA*b
            paired=r["all_converged"]=="T" and float(r["dh_inf"])>0
            hinf=float(r["dh_inf"]) if paired else float("nan")
            print("ELASTIC58_POINT|"+("|".join([
                f"profile={a.profile_id}",f"regime={reg}",f"h0={h}",f"delta={d}",
                f"retry={r['_retry']}",f"dt={float(r['dt'])}",f"binf={b:.17e}",
                f"e={e:.17e}",f"paired={'T' if paired else 'F'}",f"hinf={hinf}"
            ])))
    print(f"ELASTIC58_PROFILE_SUMMARY|profile={a.profile_id}|sequences={seq_count}|available_points={avail_count}")
    print("F_PE_ELASTIC58_PROFILE=PASS")

if __name__=="__main__":
    main()
