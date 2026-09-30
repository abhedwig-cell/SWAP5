#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, statistics, subprocess

ALPHA=0.17320259355765216
BUDGETS=(0.3,1.0)
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(-150.0,-40.0,-5.0,5.0,20.0)
DELTAS=(-0.07,-0.02,0.02,0.07)
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
        raise SystemExit(f"F_PE_ELASTIC59_FAIL executable rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC55_BANK|"):
            row=parse(line)
    if row is None:
        raise SystemExit("F_PE_ELASTIC59_FAIL missing row")
    return row

def semantic(r):
    ks=("full_status","half1_status","half2_status","all_converged","dh_inf","indicator_available","indicator_binf")
    return tuple(r.get(k) for k in ks)

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
                        r=execute(exe,reg,h,d,dt)
                        r["_retry"]=idx
                        rr.append(r)
        rows[tag]=rr

    def key(r): return (r["regime"],float(r["h0"]),float(r["delta"]),float(r["dt"]))
    a0={key(r):r for r in rows["O0"]}; a2={key(r):r for r in rows["O2"]}
    if set(a0)!=set(a2):
        raise SystemExit("F_PE_ELASTIC59_FAIL key drift")
    for k in a0:
        if semantic(a0[k])!=semantic(a2[k]):
            raise SystemExit(f"F_PE_ELASTIC59_FAIL O0/O2 drift {k}")
    print("F_PE_ELASTIC59_A3_O0_O2=PASS")

    rr=rows["O2"]
    sequences=[]
    for h in HEADS:
        for d in DELTAS:
            for reg in REGIMES:
                seq=sorted([r for r in rr if r["regime"]==reg and float(r["h0"])==h and float(r["delta"])==d],
                           key=lambda r:r["_retry"])
                sequences.append((h,d,reg,seq))

    for budget in BUDGETS:
        accepted=[]; exhausted=0; attempts=[]; by_reg={r:0 for r in REGIMES}
        by_state={"UNSAT":0,"SAT":0}
        for h,d,reg,seq in sequences:
            candidate=None; ntry=0
            for r in seq:
                ntry+=1
                if int(r["full_status"])!=1 or r["indicator_available"]!="T":
                    continue
                e=ALPHA*float(r["indicator_binf"])
                if e<=budget:
                    candidate=r
                    break
            attempts.append(ntry)
            if candidate is None:
                exhausted+=1
                continue
            accepted.append(candidate)
            by_reg[reg]+=1
            by_state["UNSAT" if h<0 else "SAT"]+=1
            e=ALPHA*float(candidate["indicator_binf"])
            if e>budget*(1+1e-12):
                raise SystemExit("F_PE_ELASTIC59_FAIL false accept")

        paired=[r for r in accepted if r["all_converged"]=="T" and float(r["dh_inf"])>0]
        hinf=[float(r["dh_inf"]) for r in paired]
        env=[float(r["dh_inf"])/(ALPHA*float(r["indicator_binf"])) for r in paired]
        util=[float(r["dh_inf"])/budget for r in paired]
        for u in env:
            if u>1+1e-12:
                raise SystemExit("F_PE_ELASTIC59_FAIL frozen envelope")
        retries=[int(r["_retry"]) for r in accepted]
        print(
            f"ELASTIC59_PROFILE_FRONTIER|profile={a.profile_id}|budget={budget:.17e}"
            f"|accepted={len(accepted)}|exhausted={exhausted}"
            f"|accept_fraction={len(accepted)/len(sequences):.17e}"
            f"|mean_retry={statistics.mean(retries) if retries else math.nan:.17e}"
            f"|median_retry={statistics.median(retries) if retries else math.nan:.17e}"
            f"|mean_attempts={statistics.mean(attempts):.17e}"
            f"|paired={len(paired)}"
            f"|max_hinf={max(hinf) if hinf else math.nan:.17e}"
            f"|median_hinf={statistics.median(hinf) if hinf else math.nan:.17e}"
            f"|max_hinf_over_budget={max(util) if util else math.nan:.17e}"
            f"|max_envelope_util={max(env) if env else math.nan:.17e}"
            f"|off_accept={by_reg['OFF']}|fixed_accept={by_reg['FIXED_1E6']}|generated_accept={by_reg['GENERATED']}"
            f"|unsat_accept={by_state['UNSAT']}|sat_accept={by_state['SAT']}"
        )

    print(f"ELASTIC59_PROFILE|profile={a.profile_id}|sequences={len(sequences)}")
    print("F_PE_ELASTIC59_PROFILE=PASS")

if __name__=="__main__":
    main()
