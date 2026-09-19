#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib

TR=0.02
TS=0.427494
ALPHA=0.021659
N=1.734737
KS=31.225016
LAMBDA=0.98087
M=1.0-1.0/N
DZ=10.0

SE0={"G00":0.85,"G01":0.65,"G02":0.85,"G03":0.95,"G04":0.85,"G05":0.65}

def fields(s):
    out={}
    for x in s.split("|"):
        if "=" in x:
            k,v=x.split("=",1);out[k]=v
    return out

def h_from_se(se):
    return -((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA

def h_from_theta(theta):
    return h_from_se((theta-TR)/(TS-TR))

def k_from_h(h):
    if h>=0.0:return KS
    se=(1.0+(ALPHA*abs(h))**N)**(-M)
    return KS*se**LAMBDA*(1.0-(1.0-se**(1.0/M))**M)**2

def k_from_theta(theta):
    se=(theta-TR)/(TS-TR)
    return KS*se**LAMBDA*(1.0-(1.0-se**(1.0/M))**M)**2

def hb(history,symbol):
    h0=h_from_se(SE0[history])
    if symbol in ("BOTTOM_HEAD_RISE","COMBINED_RISE_PLUS"): return 0.75*h0
    if symbol in ("BOTTOM_HEAD_FALL","COMBINED_FALL_MINUS"): return 1.25*h0
    raise ValueError((history,symbol))

def sgn(x): return 1 if x>0 else -1 if x<0 else 0

def summarize(pred,obs):
    e=[a-b for a,b in zip(pred,obs)]
    ae=[abs(x) for x in e]
    return {
        "record_count":len(e),
        "mean_signed_error_cm_per_day":sum(e)/len(e),
        "mean_abs_error_cm_per_day":sum(ae)/len(ae),
        "rms_error_cm_per_day":math.sqrt(sum(x*x for x in e)/len(e)),
        "max_abs_error_cm_per_day":max(ae),
        "sign_mismatch_count":sum(sgn(a)!=sgn(b) for a,b in zip(pred,obs)),
        "predicted_range_cm_per_day":[min(pred),max(pred)],
        "observed_range_cm_per_day":[min(obs),max(obs)]
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_LAGGED_REFERENCE_FACE_REPLAY"

    states={}
    n16={}
    for line in a.input.read_text(errors="replace").splitlines():
        if line.startswith("LAREGW1_STATE|"):
            row=fields(line.split("|",1)[1])
            states[(row["HISTORY"],int(row["STEP"]))]=row
        elif line.startswith("LAREGW1_NODE|"):
            row=fields(line.split("|",1)[1])
            if int(row["NODE"])==16:
                n16[(row["HISTORY"],int(row["STEP"]))]=row

    lag_head=[];lag_proj=[];cur=[];bound=[];obs=[];rows=[]
    skipped=[]
    for key in sorted(states):
        row=states[key]
        if int(row["BOTTOM_MODE"])!=5: continue
        hist,step=key
        prev=(hist,step-1)
        if prev not in n16:
            skipped.append({"history":hist,"step":step,"reason":"no emitted t0 predecessor"})
            continue
        cur_node=n16[key]; old_node=n16[prev]
        h1=float(cur_node["H"]);th1=float(cur_node["THETA"])
        h0=float(old_node["H"]);th0=float(old_node["THETA"])
        hboundary=hb(hist,row["SYMBOL"])
        qobs=float(row["BOTTOM_FLUX"])

        grad_head=1.0+2.0*(h1-hboundary)/DZ
        h1p=h_from_theta(th1)
        grad_proj=1.0+2.0*(h1p-hboundary)/DZ

        q_lag_head=k_from_h(h0)*grad_head
        q_lag_proj=k_from_theta(th0)*grad_proj
        q_cur=k_from_theta(th1)*grad_proj
        q_bound=k_from_h(hboundary)*grad_proj

        lag_head.append(q_lag_head);lag_proj.append(q_lag_proj)
        cur.append(q_cur);bound.append(q_bound);obs.append(qobs)
        rows.append({
            "history":hist,"step":step,"symbol":row["SYMBOL"],
            "h_t0_cm":h0,"theta_t0":th0,"h_t1_cm":h1,"theta_t1":th1,
            "h_boundary_cm":hboundary,"reference_outward_flux_cm_per_day":qobs,
            "REFERENCE_LAGGED_HEAD_cm_per_day":q_lag_head,
            "PROJECTED_LAGGED_LAYER_cm_per_day":q_lag_proj,
            "CURRENT_LAYER_FACE_cm_per_day":q_cur,
            "BOUNDARY_FACE_cm_per_day":q_bound
        })

    expected=int(pre["input"]["auditable_mode5_intervals"])
    if len(obs)!=expected:
        raise SystemExit(f"auditable records {len(obs)} != {expected}")
    if len(skipped)!=int(pre["input"]["first_mode5_states_without_emitted_t0_predecessor"]):
        raise SystemExit(f"skipped count {len(skipped)}")

    summaries={
        "REFERENCE_LAGGED_HEAD":summarize(lag_head,obs),
        "PROJECTED_LAGGED_LAYER":summarize(lag_proj,obs),
        "CURRENT_LAYER_FACE":summarize(cur,obs),
        "BOUNDARY_FACE":summarize(bound,obs)
    }
    gates=pre["technical_gates"]
    checks={
        "reference_lagged_head_identity":
          summaries["REFERENCE_LAGGED_HEAD"]["max_abs_error_cm_per_day"]<=float(gates["reference_lagged_head_max_abs_error_cm_per_day"]),
        "projected_lagged_layer_identity":
          summaries["PROJECTED_LAGGED_LAYER"]["max_abs_error_cm_per_day"]<=float(gates["projected_lagged_layer_max_abs_error_cm_per_day"]),
        "projected_lagged_layer_sign_identity":
          summaries["PROJECTED_LAGGED_LAYER"]["sign_mismatch_count"]==int(gates["projected_lagged_layer_sign_mismatch_count"])
    }
    passed=all(checks.values())
    result={
        "schema":"swap5.lare.bc1.a2.result.v1",
        "workstream":"F-ROM-LARE",
        "work_unit":"LARE-BC1-A2",
        "decision":"BC1_REFERENCE_FACE_SEMANTICS_QUALIFIED" if passed else "BC1_REFERENCE_FACE_SEMANTICS_BLOCKED",
        "auditable_mode5_interval_count":len(obs),
        "skipped_first_mode5_intervals":skipped,
        "operators":summaries,
        "technical_gates":checks,
        "interpretation":[
          "The two lagged operators test the actual SWKIMPL=0 Reference face time-level convention.",
          "CURRENT_LAYER_FACE and BOUNDARY_FACE are characterization only and cannot be selected from this A2 result.",
          "A successful A2 authorizes a separate reduced-dynamics experiment in which integrated exchange and storage are primary observables."
        ],
        "stage_B_reduced_dynamics_authorized":passed,
        "application_acceptance_adjudicated":False,
        "production_rom_authorized":False,
        "diagnostic_rows":rows
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "schema":result["schema"],"decision":result["decision"],
        "auditable_mode5_interval_count":len(obs),
        "operators":summaries,"technical_gates":checks
    },sort_keys=True))
    return 0 if passed else 2

if __name__=="__main__":
    raise SystemExit(main())
