#!/usr/bin/env python3
from __future__ import annotations

import argparse, importlib.util, json, math, pathlib
import numpy as np

HERE=pathlib.Path(__file__).resolve().parent

def load_module(name, filename):
    spec=importlib.util.spec_from_file_location(name, HERE/filename)
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

b9=load_module("bc2b9_c4o","analyze_lare_bc2_b9_internal_flux.py")
b8=b9.b8
b3=b9.b3

FLOOR=1.0e-9
HISTORIES=("WT_HOLD","WT_RISE","WT_FALL")

def cosine(x,y):
    a=np.asarray(x,dtype=float); b=np.asarray(y,dtype=float)
    den=float(np.linalg.norm(a)*np.linalg.norm(b))
    return None if den<=FLOOR else float(np.dot(a,b)/den)

def corr(x,y):
    a=np.asarray(x,dtype=float); b=np.asarray(y,dtype=float)
    if np.std(a)<=FLOOR or np.std(b)<=FLOOR:
        return None
    return float(np.corrcoef(a,b)[0,1])

def rms(x):
    a=np.asarray(x,dtype=float)
    return float(np.sqrt(np.mean(a*a)))

def metrics(resp,pred):
    r=np.asarray(resp,dtype=float); p=np.asarray(pred,dtype=float)
    mask=(np.abs(r)>FLOOR)&(np.abs(p)>FLOOR)
    same=None if not np.any(mask) else float(np.mean((r[mask]*p[mask])>0.0))
    e=p-r
    return {
      "count":int(len(r)),
      "signed_cosine":cosine(p,r),
      "pearson_correlation":corr(p,r),
      "same_sign_fraction":same,
      "sign_scored_count":int(np.count_nonzero(mask)),
      "unscaled_response_rms_error":rms(e),
      "predictor_rms":rms(p),
      "predictor_max_abs":float(np.max(np.abs(p))),
    }

def endpoint(profile,total,d):
    base=b9.endpoint_candidates(profile,total,d)
    p=base["projected"]
    B=float(base["B"]); a=float(base["a_t"]); bb=float(base["b_bulk"]); Ki=float(base["Ki"])
    eta=d/(B+d)
    pf=eta*(bb-a)
    pb=1.0-a
    pi=pf*pb
    vals=(B,a,bb,Ki,eta,pf,pb,pi)
    if B<=0.0 or Ki<=0.0 or not all(math.isfinite(v) for v in vals):
        raise ValueError("invalid B9 conditioner endpoint")
    return {
      "projected":p,"B":B,"a_t":a,"b_bulk":bb,"Ki":Ki,
      "q_base":float(base["TERMINAL_SIDE_LINEAR"]),
      "P_FACE":pf,"P_BOUNDARY":pb,"P_INTERACTION":pi,
      "theta_b":float(p["Wb64"])/B,
      "theta_t":float(p["Wt64"])/d,
      "H":float(p["H"]),
    }

def kref(projected):
    _,k=b3.psi_k(np.asarray([float(projected["theta_i"])],dtype=float))
    return float(k[0])

def build_history(history,d,init_meta,init_nodes,states,nodes):
    rows=[]; max_qiid=0.0; min_kr=float("inf"); min_ki=float("inf")
    e0=endpoint(init_nodes[history],init_meta[history]["total"],d)
    for step in range(1,b3.HISTORY_STEPS[history]+1):
        e1=endpoint(nodes[(history,step)],states[(history,step)]["total"],d)
        p0,p1=e0["projected"],e1["projected"]
        qH_ref=states[(history,step)]["bottom_exchange"]/b3.OBS_DT
        q90=-(p1["Wfixed"]-p0["Wfixed"])/b3.OBS_DT
        Hdot=(p1["H"]-p0["H"])/b3.OBS_DT
        Gi=0.5*(p0["theta_i"]+p1["theta_i"])*Hdot
        dWb=(p1["Wb64"]-p0["Wb64"])/b3.OBS_DT
        dWt=(p1["Wt64"]-p0["Wt64"])/b3.OBS_DT
        qi_b=q90+Gi-dWb
        qi_t=dWt+qH_ref-b3.THETA_S*Hdot+Gi
        max_qiid=max(max_qiid,abs(qi_b-qi_t))
        qi_ref=0.5*(qi_b+qi_t)

        Kr=0.5*(kref(p0)+kref(p1))
        Ki=0.5*(e0["Ki"]+e1["Ki"])
        min_kr=min(min_kr,Kr); min_ki=min(min_ki,Ki)
        if min(Kr,Ki)<=0.0 or not all(math.isfinite(v) for v in (Kr,Ki)):
            raise ValueError("nonpositive/nonfinite interface K")

        qb=0.5*(e0["q_base"]+e1["q_base"])
        sref=1.0-qi_ref/Kr
        sbase=1.0-qb/Ki
        dr=sref-sbase

        row={
          "step":step,
          "delta_ref":dr,
          "P_FACE":0.5*(e0["P_FACE"]+e1["P_FACE"]),
          "P_BOUNDARY":0.5*(e0["P_BOUNDARY"]+e1["P_BOUNDARY"]),
          "P_INTERACTION":0.5*(e0["P_INTERACTION"]+e1["P_INTERACTION"]),
          "H_mid_cm":0.5*(e0["H"]+e1["H"]),
          "theta_b_mid":0.5*(e0["theta_b"]+e1["theta_b"]),
          "theta_t_mid":0.5*(e0["theta_t"]+e1["theta_t"]),
        }
        if not all(math.isfinite(float(row[k])) for k in ("delta_ref","P_FACE","P_BOUNDARY","P_INTERACTION","H_mid_cm","theta_b_mid","theta_t_mid")):
            raise ValueError("nonfinite interval conditioner diagnostic")
        rows.append(row)
        e0=e1
    return rows,max_qiid,min_kr,min_ki

def range_stats(rows,key):
    a=np.asarray([r[key] for r in rows],dtype=float)
    return {"min":float(np.min(a)),"median":float(np.median(a)),"max":float(np.max(a))}

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c4n-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--c4k-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--c4h-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--b8-result",required=True,type=pathlib.Path)
    ap.add_argument("--b9-result",required=True,type=pathlib.Path)
    ap.add_argument("--width",required=True,type=float)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    c4n=json.loads(args.c4n_closeout.read_text()); c4k=json.loads(args.c4k_closeout.read_text()); c4h=json.loads(args.c4h_closeout.read_text())
    r8=json.loads(args.b8_result.read_text()); r9=json.loads(args.b9_result.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4N_BEFORE_EXISTING_STATE_CONDITIONER_MAP"
    assert c4n["status"]==pre["predecessors"]["C4N"]["required_status"]
    assert c4n["decision"]==pre["predecessors"]["C4N"]["required_decision"]
    assert c4n["next_authority"]==pre["predecessors"]["C4N"]["next_authority"]
    assert c4k["decision"]==pre["predecessors"]["C4K"]["required_decision"]
    assert c4h["decision"]==pre["predecessors"]["C4H"]["required_decision"]
    assert r8["decision"]==pre["predecessors"]["B8"]["required_decision"]
    assert pre["predecessors"]["B9"]["required_preferred_operator"] in r9["preferred_operator"]
    if args.width not in (2.5,5.0): raise SystemExit("unauthorized width")

    im,inodes,states,nodes=b3.load_reference(args.reference)
    by_hist={}; max_qiid=0.0; min_kr=float("inf"); min_ki=float("inf"); failures=[]
    try:
        for h in HISTORIES:
            rows,qerr,kr,ki=build_history(h,args.width,im,inodes,states,nodes)
            by_hist[h]=rows
            max_qiid=max(max_qiid,qerr); min_kr=min(min_kr,kr); min_ki=min(min_ki,ki)
    except Exception as exc:
        failures.append(str(exc))

    complete=not failures and all(h in by_hist for h in HISTORIES)
    histdiag={}
    if complete:
        for h,rows in by_hist.items():
            resp=[r["delta_ref"] for r in rows]
            histdiag[h]={
              "response":{"rms":rms(resp),"max_abs":float(np.max(np.abs(resp)))},
              "predictors":{p:metrics(resp,[r[p] for r in rows]) for p in ("P_FACE","P_BOUNDARY","P_INTERACTION")},
              "state_context":{
                "H_mid_cm":range_stats(rows,"H_mid_cm"),
                "theta_b_mid":range_stats(rows,"theta_b_mid"),
                "theta_t_mid":range_stats(rows,"theta_t_mid"),
              }
            }
        moving=by_hist["WT_RISE"]+by_hist["WT_FALL"]
        rmove=[r["delta_ref"] for r in moving]
        pooled={p:metrics(rmove,[r[p] for r in moving]) for p in ("P_FACE","P_BOUNDARY","P_INTERACTION")}
        hold_rms=histdiag["WT_HOLD"]["response"]["rms"]
    else:
        pooled=None; hold_rms=float("inf")

    hard=(
      complete
      and max_qiid<=float(pre["hard_gates"]["B8_qi_identity_cm_per_day"])
      and min_kr>0.0 and min_ki>0.0
      and hold_rms<=float(pre["hard_gates"]["hold_reference_delta_rms_max"])
      and pooled is not None
      and all(pooled[p]["signed_cosine"] is not None and pooled[p]["same_sign_fraction"] is not None for p in pooled)
    )

    result={
      "schema":"swap5.lare.bc2.c4o.width-result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4O",
      "width_cm":args.width,"complete":complete,"hard_pass":hard,
      "hard_checks":{
        "max_B8_qi_identity_cm_per_day":max_qiid,
        "minimum_reference_K_cm_per_day":min_kr,
        "minimum_B9_K_cm_per_day":min_ki,
        "hold_reference_delta_rms":hold_rms,
        "failure_count":len(failures)
      },
      "pooled_moving":pooled,
      "histories":histdiag,
      "failures":failures,
      "closure_authorized":False,
      "propagated_dynamics_authorized":False,
      "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
