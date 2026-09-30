#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, statistics, subprocess

ALPHA=0.17320259355765216
BUDGETS=(("STRICT",0.003369),("LOOSE",0.0065653))
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

def execute(exe,reg,h,d,dt):
    cp=subprocess.run([str(exe),reg,repr(h),repr(d),repr(dt)],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC58_FAIL executable rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC55_BANK|"): return parse(line)
    raise SystemExit("F_PE_ELASTIC58_FAIL missing row")

def semantic(r):
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
        if semantic(a0[k])!=semantic(a2[k]): raise SystemExit(f"F_PE_ELASTIC58_FAIL O0/O2 {k}")
    print("F_PE_ELASTIC58_A2_O0_O2=PASS")

    rr=rows["O2"]
    # Parent eligibility and nonmonotone count reproduction.
    eligible=violating=0
    seqs=[]
    for h in HEADS:
      for d in DELTAS:
       for reg in REGIMES:
        seq=sorted([r for r in rr if r["regime"]==reg and float(r["h0"])==h and float(r["delta"])==d],key=lambda r:r["_retry"])
        avail=[r for r in seq if int(r["full_status"])==1 and r["indicator_available"]=="T"]
        nonmono=False
        if len(avail)>=3:
            eligible+=1
            ev=[ALPHA*float(r["indicator_binf"]) for r in avail]
            nonmono=any(ev[i+1]>ev[i]*(1+1e-12) for i in range(len(ev)-1))
            if nonmono: violating+=1
        seqs.append((h,d,reg,seq,nonmono))

    for label,budget in BUDGETS:
        accepts=exhausted=paired=paired_safe=0
        retries=[]
        by_reg={r:0 for r in REGIMES}
        nonmono_total=nonmono_accept=nonmono_exhaust=0
        worst_hinf=0.0
        worst_margin=math.inf
        for h,d,reg,seq,nonmono in seqs:
            if nonmono: nonmono_total+=1
            chosen=None
            for r in seq:
                if int(r["full_status"])!=1 or r["indicator_available"]!="T": continue
                eb=ALPHA*float(r["indicator_binf"])
                if eb<=budget:
                    chosen=r; break
            if chosen is None:
                exhausted+=1
                if nonmono: nonmono_exhaust+=1
                continue
            accepts+=1; by_reg[reg]+=1; retries.append(int(chosen["_retry"]))
            if nonmono: nonmono_accept+=1
            eb=ALPHA*float(chosen["indicator_binf"])
            if eb>budget*(1+1e-12):
                raise SystemExit("F_PE_ELASTIC58_FAIL false accept")
            if chosen["all_converged"]=="T" and float(chosen["dh_inf"])>=0:
                paired+=1
                hinf=float(chosen["dh_inf"])
                worst_hinf=max(worst_hinf,hinf)
                margin=budget-hinf
                worst_margin=min(worst_margin,margin)
                if hinf>eb*(1+1e-12):
                    raise SystemExit("F_PE_ELASTIC58_FAIL frozen alpha envelope")
                if hinf>budget*(1+1e-12):
                    raise SystemExit("F_PE_ELASTIC58_FAIL external benchmark")
                paired_safe+=1
        total=len(seqs)
        frac=accepts/total
        med=statistics.median(retries) if retries else math.nan
        cls="SAFE_AND_PRACTICAL_IN_BANK" if frac>=0.75 else "SAFE_BUT_OVERCONSERVATIVE_IN_BANK"
        print(f"ELASTIC58_BUDGET|profile={a.profile_id}|label={label}|budget_cm={budget:.17e}|sequences={total}|accepts={accepts}|exhausted={exhausted}|accept_fraction={frac:.17e}|paired={paired}|paired_safe={paired_safe}|median_retry={med}|nonmono_total={nonmono_total}|nonmono_accept={nonmono_accept}|nonmono_exhaust={nonmono_exhaust}|worst_hinf={worst_hinf:.17e}|min_margin={worst_margin:.17e}|classification={cls}|off_accept={by_reg['OFF']}|fixed_accept={by_reg['FIXED_1E6']}|generated_accept={by_reg['GENERATED']}")
    print(f"ELASTIC58_PARENT|profile={a.profile_id}|eligible={eligible}|violating={violating}")
    print(f"ELASTIC58_ALPHA_FROZEN={ALPHA:.17e}")
    print("F_PE_ELASTIC58_PROFILE=PASS")

if __name__=="__main__":
    main()
