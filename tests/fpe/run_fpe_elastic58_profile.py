#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

ALPHA=0.17320259355765216
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
        raise SystemExit(f"F_PE_ELASTIC58_FAIL executable rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC55_BANK|"):
            row=parse(line)
    if row is None: raise SystemExit("F_PE_ELASTIC58_FAIL missing row")
    return row

def semantic(r):
    keys=("full_status","half1_status","half2_status","all_converged","dh_inf","dtheta_inf",
          "indicator_available","indicator_binf","indicator_raw","indicator_defect")
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
    if set(a0)!=set(a2): raise SystemExit("F_PE_ELASTIC58_FAIL O0/O2 key drift")
    for k in a0:
        if semantic(a0[k])!=semantic(a2[k]):
            raise SystemExit(f"F_PE_ELASTIC58_FAIL O0/O2 drift {k}")
    print("F_PE_ELASTIC58_A2_O0_O2=PASS")

    rr=rows["O2"]
    selected=[]; exhausted=[]
    per_reg={r:{"selected":0,"exhausted":0,"paired_selected":0} for r in REGIMES}

    for h in HEADS:
        for d in DELTAS:
            for reg in REGIMES:
                seq=[r for r in rr if r["regime"]==reg and float(r["h0"])==h and float(r["delta"])==d]
                seq=sorted(seq,key=lambda r:r["_retry"])
                pick=None
                for r in seq:
                    if int(r["full_status"])!=1 or r["indicator_available"]!="T":
                        continue
                    b=float(r["indicator_binf"])
                    if not math.isfinite(b) or b<0: raise SystemExit("F_PE_ELASTIC58_FAIL invalid Binf")
                    if b <= BINF_BUDGET*(1+1e-15):
                        pick=r; break
                if pick is None:
                    exhausted.append((reg,h,d)); per_reg[reg]["exhausted"]+=1
                    continue
                b=float(pick["indicator_binf"])
                if b > BINF_BUDGET*(1+1e-15):
                    raise SystemExit("F_PE_ELASTIC58_FAIL selected over budget")
                paired=pick["all_converged"]=="T"
                hinf=float(pick["dh_inf"]) if paired else math.nan
                tinf=float(pick["dtheta_inf"]) if paired else math.nan
                if paired:
                    if not math.isfinite(hinf) or not math.isfinite(tinf):
                        raise SystemExit("F_PE_ELASTIC58_FAIL nonfinite paired metric")
                    if hinf > HEAD_LIMIT*(1+1e-12):
                        raise SystemExit(f"F_PE_ELASTIC58_FAIL paired head limit {hinf}")
                    if tinf > THETA_LIMIT*(1+1e-12):
                        raise SystemExit(f"F_PE_ELASTIC58_FAIL paired theta limit {tinf}")
                    per_reg[reg]["paired_selected"]+=1
                selected.append((reg,h,d,pick["_retry"],float(pick["dt"]),b,paired,hinf,tinf))
                per_reg[reg]["selected"]+=1

    print(f"ELASTIC58_PROFILE_SUMMARY|profile={a.profile_id}|selected={len(selected)}|exhausted={len(exhausted)}|paired_selected={sum(1 for x in selected if x[6])}")
    for reg in REGIMES:
        x=per_reg[reg]
        print(f"ELASTIC58_REGIME_SUMMARY|profile={a.profile_id}|regime={reg}|selected={x['selected']}|exhausted={x['exhausted']}|paired_selected={x['paired_selected']}")
    for x in selected:
        print(f"ELASTIC58_SELECTED|profile={a.profile_id}|regime={x[0]}|h0={x[1]}|delta={x[2]}|retry={x[3]}|dt={x[4]}|binf={x[5]:.17e}|paired={'T' if x[6] else 'F'}|hinf={x[7]}|dtheta_inf={x[8]}")
    for x in exhausted:
        print(f"ELASTIC58_EXHAUSTED|profile={a.profile_id}|regime={x[0]}|h0={x[1]}|delta={x[2]}")
    print(f"ELASTIC58_ALPHA_FROZEN={ALPHA:.17e}")
    print(f"ELASTIC58_HEAD_LIMIT_CM={HEAD_LIMIT:.17e}")
    print(f"ELASTIC58_THETA_LIMIT={THETA_LIMIT:.17e}")
    print(f"ELASTIC58_BINF_BUDGET_CM={BINF_BUDGET:.17e}")
    print("F_PE_ELASTIC58_PROFILE=PASS")

if __name__=="__main__":
    main()
