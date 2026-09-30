#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

ALPHA=0.17320259355765216
MASS_TOL=1.0e-12
BUDGETS=(0.05,0.10,0.25,0.50,1.0,2.0,5.0,10.0)
DTS=(0.015625,0.0078125,0.00390625,0.001953125,0.0009765625,0.00048828125,0.000244140625,0.0001220703125,0.00006103515625)

TARGETS={
11060:[("OFF",2.0,0.035)],
10260:[("OFF",2.0,0.035),("FIXED_1E6",2.0,0.035),("OFF",2.0,0.05),("FIXED_1E6",2.0,0.05),("OFF",10.0,0.035)],
8016:[("OFF",2.0,0.035),("OFF",2.0,0.05),("OFF",10.0,0.035),("OFF",10.0,0.05)],
3030:[("OFF",2.0,0.035),("OFF",2.0,0.05),("FIXED_1E6",2.0,0.05),("OFF",10.0,0.035),("OFF",10.0,0.05)],
}

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    return d

def execute(exe,reg,h,d,dt):
    cp=subprocess.run([str(exe),reg,repr(h),repr(d),repr(dt)],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC57_FAIL executable rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC57_BANK|"): row=parse(line)
    if row is None:
        raise SystemExit("F_PE_ELASTIC57_FAIL missing row")
    return row

def sem(r):
    keys=("full_status","half1_status","half2_status","all_converged","dh_inf",
          "indicator_available","indicator_binf","indicator_raw","indicator_defect",
          "full_mass_available","full_ledger_mass")
    return tuple(r.get(k) for k in keys)

def boolv(v): return v=="T"

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--profile-id",type=int,required=True)
    ap.add_argument("--o0",required=True)
    ap.add_argument("--o2",required=True)
    a=ap.parse_args()
    if a.profile_id not in TARGETS:
        raise SystemExit("F_PE_ELASTIC57_FAIL unexpected profile")

    sequences=[]
    for reg,h,d in TARGETS[a.profile_id]:
        sequences.append(("TARGET",reg,h,d))
        sequences.append(("CONTROL",reg,h,-d))

    bank={}
    for tag,exe in (("O0",a.o0),("O2",a.o2)):
        for kind,reg,h,d in sequences:
            rows=[]
            for retry,dt in enumerate(DTS):
                r=execute(exe,reg,h,d,dt)
                r["_retry"]=retry
                rows.append(r)
            bank[(tag,kind,reg,h,d)]=rows

    # O0/O2 identity.
    for kind,reg,h,d in sequences:
        a0=bank[("O0",kind,reg,h,d)]
        a2=bank[("O2",kind,reg,h,d)]
        for r0,r2 in zip(a0,a2):
            if sem(r0)!=sem(r2):
                raise SystemExit(f"F_PE_ELASTIC57_FAIL O0/O2 {a.profile_id} {kind} {reg} {h} {d} {r0['_retry']}")
    print(f"F_PE_ELASTIC57_O0_O2|profile={a.profile_id}|status=PASS")

    outcomes=[]
    for kind,reg,h,d in sequences:
        rows=bank[("O2",kind,reg,h,d)]
        for budget in BUDGETS:
            accepted=None
            solver_rej=indicator_rej=mass_rej=temporal_rej=0
            for r in rows:
                if int(r["full_status"])!=1:
                    solver_rej+=1
                    continue
                if not boolv(r["indicator_available"]):
                    indicator_rej+=1
                    continue
                if not boolv(r["full_mass_available"]):
                    mass_rej+=1
                    continue
                mass=float(r["full_ledger_mass"])
                if not math.isfinite(mass) or abs(mass)>MASS_TOL:
                    mass_rej+=1
                    continue
                b=float(r["indicator_binf"])
                if not math.isfinite(b) or b<0:
                    indicator_rej+=1
                    continue
                bound=ALPHA*b
                if bound<=budget:
                    accepted=r
                    break
                temporal_rej+=1

            oracle_retry=None
            for r in rows:
                if not boolv(r["all_converged"]): continue
                if not boolv(r["full_mass_available"]): continue
                mass=float(r["full_ledger_mass"])
                if not math.isfinite(mass) or abs(mass)>MASS_TOL: continue
                hreal=float(r["dh_inf"])
                if math.isfinite(hreal) and hreal<=budget:
                    oracle_retry=r["_retry"]; break

            if accepted is None:
                status="EXHAUSTED"; retry=-1; dt=0.0; bound=math.nan
                paired=False; hinf=math.nan; safety="NA"; unverified=False
                extra=None
            else:
                status="ACCEPTED"; retry=accepted["_retry"]; dt=float(accepted["dt"])
                bound=ALPHA*float(accepted["indicator_binf"])
                paired=boolv(accepted["all_converged"])
                if paired:
                    hinf=float(accepted["dh_inf"])
                    safety="PASS" if hinf<=budget*(1+1e-12) else "FAIL"
                    unverified=False
                    extra=(retry-oracle_retry) if oracle_retry is not None else None
                else:
                    hinf=math.nan; safety="UNVERIFIED"; unverified=True; extra=None

            rec=dict(profile=a.profile_id,kind=kind,regime=reg,h0=h,delta=d,budget=budget,
                     status=status,retry=retry,dt=dt,bound=bound,paired=paired,hinf=hinf,
                     safety=safety,unverified=unverified,oracle_retry=oracle_retry,extra=extra,
                     solver_rej=solver_rej,indicator_rej=indicator_rej,mass_rej=mass_rej,temporal_rej=temporal_rej)
            outcomes.append(rec)
            print("ELASTIC57_OUTCOME|"+("|".join([
                f"profile={a.profile_id}",f"kind={kind}",f"regime={reg}",f"h0={h}",f"delta={d}",f"budget={budget}",
                f"status={status}",f"retry={retry}",f"dt={dt}",f"bound={bound}",
                f"paired={'T' if paired else 'F'}",f"hinf={hinf}",f"safety={safety}",
                f"unverified={'T' if unverified else 'F'}",
                f"oracle_retry={oracle_retry if oracle_retry is not None else -1}",
                f"extra_refinement={extra if extra is not None else -999}",
                f"solver_rejections={solver_rej}",f"indicator_rejections={indicator_rej}",
                f"mass_rejections={mass_rej}",f"temporal_rejections={temporal_rej}"
            ])))

    unsafe=sum(1 for x in outcomes if x["safety"]=="FAIL")
    unverified=sum(1 for x in outcomes if x["unverified"])
    accepted=sum(1 for x in outcomes if x["status"]=="ACCEPTED")
    exhausted=len(outcomes)-accepted
    max_attempts=max((x["retry"]+1 if x["retry"]>=0 else 9) for x in outcomes)
    target_exhaust=sum(1 for x in outcomes if x["kind"]=="TARGET" and x["status"]=="EXHAUSTED")
    control_exhaust=sum(1 for x in outcomes if x["kind"]=="CONTROL" and x["status"]=="EXHAUSTED")
    paired_comp=[x["extra"] for x in outcomes if x["extra"] is not None]
    max_extra=max(paired_comp) if paired_comp else -999
    if unsafe:
        raise SystemExit(f"F_PE_ELASTIC57_FAIL paired unsafe accepts={unsafe}")
    if max_attempts>9:
        raise SystemExit("F_PE_ELASTIC57_FAIL attempts bound")
    print(f"ELASTIC57_PROFILE_SUMMARY|profile={a.profile_id}|outcomes={len(outcomes)}|accepted={accepted}|exhausted={exhausted}|unsafe={unsafe}|unverified={unverified}|target_exhausted={target_exhaust}|control_exhausted={control_exhaust}|max_attempts={max_attempts}|max_extra_refinement={max_extra}")
    print("F_PE_ELASTIC57_PROFILE=PASS")

if __name__=="__main__":
    main()
