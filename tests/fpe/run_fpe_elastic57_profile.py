#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

ALPHA=0.17320259355765216
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(-75.0,-20.0,2.0,10.0)
DELTAS=(-0.05,-0.035,0.035,0.05)
DTS=(0.015625,0.0078125,0.00390625,0.001953125,0.0009765625,0.00048828125,0.000244140625,0.0001220703125,0.00006103515625)
BUDGETS=(0.01,0.03,0.10,0.30)

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    return d

def execute(exe,reg,h,d,dt):
    cp=subprocess.run([exe,reg,repr(h),repr(d),repr(dt)],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC57_FAIL executable rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC55_BANK|"): row=parse(line)
    if row is None: raise SystemExit("F_PE_ELASTIC57_FAIL missing row")
    return row

def sem(r):
    keys=("full_status","half1_status","half2_status","all_converged","dh_inf","indicator_available","indicator_binf")
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
                    for idx,dt in enumerate(DTS):
                        r=execute(exe,reg,h,d,dt); r["_retry"]=idx; rr.append(r)
        rows[tag]=rr

    def key(r): return (r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]))
    a0={key(r):r for r in rows["O0"]}; a2={key(r):r for r in rows["O2"]}
    if set(a0)!=set(a2): raise SystemExit("F_PE_ELASTIC57_FAIL key drift")
    for k in a0:
        if sem(a0[k])!=sem(a2[k]): raise SystemExit(f"F_PE_ELASTIC57_FAIL O0/O2 {k}")
    print("F_PE_ELASTIC57_A2_O0_O2=PASS")

    rr=rows["O2"]; false_accepts=0; accepts=0; exhausted=0; nonmono_sequences=0
    for h in HEADS:
        for d in DELTAS:
            for reg in REGIMES:
                seq=sorted([r for r in rr if r["regime"]==reg and float(r["h0"])==h and float(r["delta"])==d],
                           key=lambda r:r["_retry"])
                avail=[r for r in seq if int(r["full_status"])==1 and r["indicator_available"]=="T"]
                nonmono=any(float(avail[i+1]["indicator_binf"])>float(avail[i]["indicator_binf"])*(1+1e-12)
                            for i in range(len(avail)-1)) if len(avail)>=2 else False
                if nonmono: nonmono_sequences+=1
                for budget in BUDGETS:
                    accepted=None; increases_seen=0; prev_b=None
                    for r in seq:
                        if int(r["full_status"])!=1 or r["indicator_available"]!="T": continue
                        b=float(r["indicator_binf"])
                        if prev_b is not None and b>prev_b*(1+1e-12): increases_seen+=1
                        prev_b=b
                        if ALPHA*b <= budget:
                            accepted=r; break
                    if accepted is None:
                        exhausted+=1
                        print(f"ELASTIC57_DECISION|profile={a.profile_id}|regime={reg}|h0={h}|delta={d}|budget={budget}|status=EXHAUSTED|nonmonotone={'T' if nonmono else 'F'}|increases_seen={increases_seen}")
                        continue
                    accepts+=1
                    paired=accepted["all_converged"]=="T"
                    hinf=float(accepted["dh_inf"]) if paired else math.nan
                    margin=budget-hinf if paired else math.nan
                    if paired and hinf>budget*(1+1e-12):
                        false_accepts+=1
                    print(f"ELASTIC57_DECISION|profile={a.profile_id}|regime={reg}|h0={h}|delta={d}|budget={budget}|status=ACCEPT|retry={accepted['_retry']}|dt={float(accepted['dt'])}|binf={float(accepted['indicator_binf']):.17e}|pred={ALPHA*float(accepted['indicator_binf']):.17e}|paired={'T' if paired else 'F'}|hinf={hinf}|margin={margin}|nonmonotone={'T' if nonmono else 'F'}|increases_seen={increases_seen}")
    print(f"ELASTIC57_PROFILE_SUMMARY|profile={a.profile_id}|accepts={accepts}|exhausted={exhausted}|false_accepts={false_accepts}|nonmonotone_sequences={nonmono_sequences}")
    if false_accepts: raise SystemExit("F_PE_ELASTIC57_FAIL false acceptance")
    print("F_PE_ELASTIC57_A5_SAFETY=PASS")
    print("F_PE_ELASTIC57_PROFILE=PASS")

if __name__=="__main__":
    main()
