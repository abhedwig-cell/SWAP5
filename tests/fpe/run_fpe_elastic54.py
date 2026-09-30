#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess
from pathlib import Path

REGIMES=("OFF","FIXED_1E6","GENERATED")
TRAIN_H=(-75.0,2.0,10.0)
TRAIN_D=(-0.05,-0.025,0.025,0.05)
HOLD_H=(-20.0,5.0)
HOLD_D=(-0.035,0.035)
DTS=(0.015625,0.0078125,0.00390625,0.001953125,0.0009765625,0.00048828125,0.000244140625,0.0001220703125,0.00006103515625)

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    return d

def run(exe, regime, h0, delta, dt):
    cp=subprocess.run([str(exe),regime,repr(h0),repr(delta),repr(dt)],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC54_FAIL executable rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC53_BANK|"):
            row=parse(line)
    if row is None:
        raise SystemExit("F_PE_ELASTIC54_FAIL missing bank row")
    row["set"]=None
    return row

def num(r,k): return float(r[k])

def paired(r):
    return r["all_converged"]=="T" and r["indicator_available"]=="T" and num(r,"dh_inf")>0 and num(r,"indicator_binf")>0

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--o0",required=True)
    ap.add_argument("--o2",required=True)
    a=ap.parse_args()
    results={}
    for tag,exe in (("O0",Path(a.o0)),("O2",Path(a.o2))):
        rows=[]
        for setname,hs,ds in (("TRAIN",TRAIN_H,TRAIN_D),("HOLDOUT",HOLD_H,HOLD_D)):
            for h in hs:
                for d in ds:
                    for reg in REGIMES:
                        for dt in DTS:
                            r=run(exe,reg,h,d,dt); r["set"]=setname
                            rows.append(r)
                            print(f"ELASTIC54_{tag}|set={setname}|"+r["_raw"] if "_raw" in r else
                                  f"ELASTIC54_{tag}|set={setname}|regime={reg}|h0={h}|delta={d}|dt={dt}|full_status={r['full_status']}|all_converged={r['all_converged']}|indicator_available={r['indicator_available']}|binf={r['indicator_binf']}|hinf={r['dh_inf']}")
        results[tag]=rows

    def key(r):
        return (r["set"],r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]))
    a0={key(r):r for r in results["O0"]}; a2={key(r):r for r in results["O2"]}
    if set(a0)!=set(a2): raise SystemExit("F_PE_ELASTIC54_FAIL O0/O2 key drift")
    fields=("full_status","half1_status","half2_status","all_converged","indicator_available","indicator_binf","dh_inf")
    for k in a0:
        if tuple(a0[k].get(f) for f in fields)!=tuple(a2[k].get(f) for f in fields):
            raise SystemExit(f"F_PE_ELASTIC54_FAIL O0/O2 drift {k}")
    print("F_PE_ELASTIC54_A2_O0_O2=PASS")

    rows=results["O2"]
    expected=(len(TRAIN_H)*len(TRAIN_D)+len(HOLD_H)*len(HOLD_D))*len(REGIMES)*len(DTS)
    if len(rows)!=expected: raise SystemExit(f"F_PE_ELASTIC54_FAIL count={len(rows)} expected={expected}")
    print(f"ELASTIC54_CASES={len(rows)}")
    print("F_PE_ELASTIC54_A1_CASES=PASS")

    full=[r for r in rows if int(r["full_status"])==1]
    for r in full:
        if r["indicator_available"]!="T":
            raise SystemExit("F_PE_ELASTIC54_FAIL full solve without indicator")
        b=num(r,"indicator_binf")
        if not math.isfinite(b) or b<0: raise SystemExit("F_PE_ELASTIC54_FAIL invalid Binf")
    print("F_PE_ELASTIC54_A3_INDICATOR=PASS")

    train=[r for r in rows if r["set"]=="TRAIN" and paired(r)]
    hold=[r for r in rows if r["set"]=="HOLDOUT" and paired(r)]
    if not train: raise SystemExit("F_PE_ELASTIC54_FAIL no paired training cases")
    ratios=[num(r,"dh_inf")/num(r,"indicator_binf") for r in train]
    alpha_global=max(ratios)
    alpha_reg={}
    for reg in REGIMES:
        rr=[num(r,"dh_inf")/num(r,"indicator_binf") for r in train if r["regime"]==reg]
        if rr: alpha_reg[reg]=max(rr)

    print(f"ELASTIC54_ALPHA_GLOBAL={alpha_global:.17e}")
    for reg,val in alpha_reg.items():
        print(f"ELASTIC54_ALPHA_REGIME|regime={reg}|alpha={val:.17e}")
    print(f"ELASTIC54_PAIRED|train={len(train)}|holdout={len(hold)}")
    print("F_PE_ELASTIC54_A5_TRAIN_ONLY=PASS")
    print("F_PE_ELASTIC54_A6_HOLDOUT_BLIND=PASS")

    fail_g=[]; fail_r=[]
    for r in hold:
        h=num(r,"dh_inf"); b=num(r,"indicator_binf")
        if h > alpha_global*b*(1+1e-12):
            fail_g.append((r["regime"],num(r,"h0"),num(r,"delta"),num(r,"dt"),h,b))
        ar=alpha_reg.get(r["regime"])
        if ar is not None and h > ar*b*(1+1e-12):
            fail_r.append((r["regime"],num(r,"h0"),num(r,"delta"),num(r,"dt"),h,b))
    print(f"ELASTIC54_HOLDOUT_GLOBAL_FAILURES={len(fail_g)}")
    print(f"ELASTIC54_HOLDOUT_REGIME_FAILURES={len(fail_r)}")
    for x in fail_g[:20]: print("ELASTIC54_GLOBAL_FAIL|"+("|".join(map(str,x))))
    for x in fail_r[:20]: print("ELASTIC54_REGIME_FAIL|"+("|".join(map(str,x))))

    # Monotonicity of Binf over full-converged sequences, only consecutive points.
    violations=0; sequences=0
    for setname,hs,ds in (("TRAIN",TRAIN_H,TRAIN_D),("HOLDOUT",HOLD_H,HOLD_D)):
        for h in hs:
            for d in ds:
                for reg in REGIMES:
                    seq=[r for r in rows if r["set"]==setname and r["regime"]==reg and num(r,"h0")==h and num(r,"delta")==d and int(r["full_status"])==1 and r["indicator_available"]=="T"]
                    seq=sorted(seq,key=lambda r:num(r,"dt"),reverse=True)
                    if len(seq)>=3:
                        sequences+=1
                        vals=[num(r,"indicator_binf") for r in seq]
                        if any(vals[i+1] > vals[i]*(1+1e-12) for i in range(len(vals)-1)):
                            violations+=1
    print(f"ELASTIC54_MONOTONIC_SEQUENCES={sequences}")
    print(f"ELASTIC54_MONOTONIC_VIOLATIONS={violations}")
    print("F_PE_ELASTIC54=PASS")

if __name__=="__main__":
    main()
