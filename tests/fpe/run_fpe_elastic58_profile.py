#!/usr/bin/env python3
from __future__ import annotations
import argparse, math, subprocess

ALPHA=0.17320259355765216
REGIMES=("OFF","FIXED_1E6","GENERATED")
HEADS=(-75.0,-20.0,2.0,10.0)
DELTAS=(-0.05,-0.035,0.035,0.05)
DTS=(0.015625,0.0078125,0.00390625,0.001953125,0.0009765625,0.00048828125,0.000244140625,0.0001220703125,0.00006103515625)
BUDGETS=(0.01,0.03,0.10,0.30)

DIAG_FIELDS=("nonlinear","linear","jacobian","backtracking")

def parse(line):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    return d

def execute(exe,reg,h,d,dt):
    cp=subprocess.run([exe,reg,repr(h),repr(d),repr(dt)],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(f"F_PE_ELASTIC58_FAIL executable rc={cp.returncode}\n{cp.stdout}\n{cp.stderr}")
    row=None
    for line in cp.stdout.splitlines():
        if line.startswith("ELASTIC55_BANK|"): row=parse(line)
    if row is None: raise SystemExit("F_PE_ELASTIC58_FAIL missing row")
    return row

def sem(r):
    keys=("full_status","half1_status","half2_status","all_converged","exact_identity","dh_inf",
          "indicator_available","indicator_binf","full_nonlinear","half1_nonlinear","half2_nonlinear",
          "full_linear","half1_linear","half2_linear","full_jacobian","half1_jacobian","half2_jacobian",
          "full_backtracking","half1_backtracking","half2_backtracking")
    return tuple(r.get(k) for k in keys)

def zero_cost():
    return {k:0 for k in DIAG_FIELDS}|{"cert_tridiag":0,"attempts":0}

def add_trial(cost,r,prefix):
    cost["nonlinear"]+=int(r[f"{prefix}_nonlinear"])
    cost["linear"]+=int(r[f"{prefix}_linear"])
    cost["jacobian"]+=int(r[f"{prefix}_jacobian"])
    cost["backtracking"]+=int(r[f"{prefix}_backtracking"])

def identity_route(seq):
    c=zero_cost()
    for r in seq:
        c["attempts"]+=1
        add_trial(c,r,"full")
        if int(r["full_status"])!=1: continue
        add_trial(c,r,"half1")
        if int(r["half1_status"])!=1: continue
        add_trial(c,r,"half2")
        if int(r["half2_status"])!=1: continue
        if r["exact_identity"]=="T":
            return "ACCEPT",r,c
    return "EXHAUSTED",None,c

def certificate_route(seq,budget):
    c=zero_cost()
    for r in seq:
        c["attempts"]+=1
        add_trial(c,r,"full")
        if int(r["full_status"])!=1: continue
        if r["indicator_available"]!="T": continue
        c["cert_tridiag"]+=1
        c["linear"]+=1
        if ALPHA*float(r["indicator_binf"])<=budget:
            return "ACCEPT",r,c
    return "EXHAUSTED",None,c

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
    print("F_PE_ELASTIC58_B3_O0_O2=PASS")

    rr=rows["O2"]
    agg={b:{"cert":zero_cost(),"ident":zero_cost(),"cert_accept":0,"cert_exhaust":0,
            "ident_accept":0,"ident_exhaust":0,"cert_accept_ident_exhaust":0,
            "both_exhaust":0,"paired_accept":0,"unpaired_accept":0,"false_accept":0} for b in BUDGETS}
    for h in HEADS:
        for d in DELTAS:
            for reg in REGIMES:
                seq=sorted([r for r in rr if r["regime"]==reg and float(r["h0"])==h and float(r["delta"])==d],
                           key=lambda r:r["_retry"])
                istat,irow,icost=identity_route(seq)
                for budget in BUDGETS:
                    cstat,crow,ccost=certificate_route(seq,budget)
                    A=agg[budget]
                    for k in A["cert"]: A["cert"][k]+=ccost[k]
                    for k in A["ident"]: A["ident"][k]+=icost[k]
                    A["cert_accept" if cstat=="ACCEPT" else "cert_exhaust"]+=1
                    A["ident_accept" if istat=="ACCEPT" else "ident_exhaust"]+=1
                    if cstat=="ACCEPT" and istat=="EXHAUSTED": A["cert_accept_ident_exhaust"]+=1
                    if cstat=="EXHAUSTED" and istat=="EXHAUSTED": A["both_exhaust"]+=1
                    if cstat=="ACCEPT":
                        paired=crow["all_converged"]=="T"
                        if paired:
                            A["paired_accept"]+=1
                            if float(crow["dh_inf"])>budget*(1+1e-12): A["false_accept"]+=1
                        else:
                            A["unpaired_accept"]+=1
                    print(f"ELASTIC58_DECISION|profile={a.profile_id}|regime={reg}|h0={h}|delta={d}|budget={budget}|cert={cstat}|identity={istat}|cert_attempts={ccost['attempts']}|identity_attempts={icost['attempts']}|cert_nonlinear={ccost['nonlinear']}|identity_nonlinear={icost['nonlinear']}|cert_linear={ccost['linear']}|identity_linear={icost['linear']}|cert_tridiag={ccost['cert_tridiag']}|cert_jacobian={ccost['jacobian']}|identity_jacobian={icost['jacobian']}|cert_backtracking={ccost['backtracking']}|identity_backtracking={icost['backtracking']}")

    for budget,A in agg.items():
        if A["false_accept"]: raise SystemExit("F_PE_ELASTIC58_FAIL false accept")
        print("ELASTIC58_PROFILE_BUDGET|"
              f"profile={a.profile_id}|budget={budget}|cert_accept={A['cert_accept']}|cert_exhaust={A['cert_exhaust']}|"
              f"identity_accept={A['ident_accept']}|identity_exhaust={A['ident_exhaust']}|"
              f"cert_accept_ident_exhaust={A['cert_accept_ident_exhaust']}|both_exhaust={A['both_exhaust']}|"
              f"paired_accept={A['paired_accept']}|unpaired_accept={A['unpaired_accept']}|"
              f"cert_nonlinear={A['cert']['nonlinear']}|identity_nonlinear={A['ident']['nonlinear']}|"
              f"cert_linear={A['cert']['linear']}|identity_linear={A['ident']['linear']}|cert_tridiag={A['cert']['cert_tridiag']}|"
              f"cert_jacobian={A['cert']['jacobian']}|identity_jacobian={A['ident']['jacobian']}|"
              f"cert_backtracking={A['cert']['backtracking']}|identity_backtracking={A['ident']['backtracking']}")
    print("F_PE_ELASTIC58_B4_SAFETY=PASS")
    print("F_PE_ELASTIC58_PROFILE=PASS")

if __name__=="__main__":
    main()
