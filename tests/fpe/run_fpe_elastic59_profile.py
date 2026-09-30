#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

ALPHA=0.17320259355765216
H_TARGET=0.0065653
ORACLE_SELF=0.1*H_TARGET
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(-75.0,-20.0,2.0,10.0)
DELTAS=(-0.05,-0.035,0.035,0.05)
DTS=(0.015625,0.0078125)

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" in p:
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
    ks=("full_status","indicator_available","indicator_binf","ref8_ok","ref16_ok","oracle_complete",
        "h_real_ref16","h_oracle_8_16")
    return tuple(r.get(k) for k in ks)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--profile-id",type=int,required=True)
    ap.add_argument("--set",choices=("TRAIN","HOLDOUT"),required=True)
    ap.add_argument("--o0",required=True); ap.add_argument("--o2",required=True)
    a=ap.parse_args()
    rows={}
    for tag,exe in (("O0",a.o0),("O2",a.o2)):
        rr=[]
        for h in HEADS:
            for d in DELTAS:
                for reg in REGIMES:
                    for dt in DTS:
                        r=execute(exe,reg,h,d,dt); rr.append(r)
        rows[tag]=rr
    def key(r): return (r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]))
    a0={key(r):r for r in rows["O0"]}; a2={key(r):r for r in rows["O2"]}
    if set(a0)!=set(a2): raise SystemExit("F_PE_ELASTIC59_FAIL key drift")
    for k in a0:
        if sem(a0[k])!=sem(a2[k]): raise SystemExit(f"F_PE_ELASTIC59_FAIL O0/O2 {k}")
    print("F_PE_ELASTIC59_A2_O0_O2=PASS")

    q=[]
    for r in rows["O2"]:
        full=int(r["full_status"])==1
        ind=r["indicator_available"]=="T"
        oracle=r["oracle_complete"]=="T" and r["ref8_ok"]=="T" and r["ref16_ok"]=="T"
        hreal=float(r["h_real_ref16"])
        horacle=float(r["h_oracle_8_16"])
        binf=float(r["indicator_binf"])
        if full and ind and oracle and math.isfinite(hreal) and math.isfinite(horacle) and math.isfinite(binf) and horacle<=ORACLE_SELF:
            eb=ALPHA*binf
            q.append(dict(profile=a.profile_id,set=a.set,regime=r["regime"],h0=float(r["h0"]),delta=float(r["delta"]),
                          dt=float(r["dt"]),hreal=hreal,horacle=horacle,binf=binf,ebound=eb,
                          safe=hreal<=H_TARGET))
    for x in q:
        print("ELASTIC59_QUALIFIED|"+("|".join([
            f"profile={x['profile']}",f"set={x['set']}",f"regime={x['regime']}",f"h0={x['h0']}",
            f"delta={x['delta']}",f"dt={x['dt']}",f"hreal={x['hreal']:.17e}",
            f"horacle={x['horacle']:.17e}",f"binf={x['binf']:.17e}",f"ebound={x['ebound']:.17e}",
            f"safe={'T' if x['safe'] else 'F'}"
        ])))
    print(f"ELASTIC59_PROFILE|profile={a.profile_id}|set={a.set}|requested={len(rows['O2'])}|oracle_qualified={len(q)}|safe={sum(x['safe'] for x in q)}|unsafe={sum(not x['safe'] for x in q)}")
    print("F_PE_ELASTIC59_PROFILE=PASS")

if __name__=="__main__":
    main()
