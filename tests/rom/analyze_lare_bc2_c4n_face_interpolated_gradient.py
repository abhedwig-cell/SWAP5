#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib

import numpy as np

HERE=pathlib.Path(__file__).resolve().parent

def load_module(name,filename):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

b9=load_module("bc2b9_c4n","analyze_lare_bc2_b9_internal_flux.py")
b8=b9.b8
b3=b9.b3

CMP=1.0e-12
ZERO=1.0e-12

def metrics(ref,pred):
    r=np.asarray(ref,dtype=float); p=np.asarray(pred,dtype=float); e=p-r
    corr=float(np.corrcoef(r,p)[0,1]) if np.std(r)>0.0 and np.std(p)>0.0 else None
    return {
        "count":int(len(e)),
        "bias":float(np.mean(e)),
        "mae":float(np.mean(np.abs(e))),
        "rms":float(np.sqrt(np.mean(e*e))),
        "max_abs":float(np.max(np.abs(e))),
        "sign_mismatch":int(np.count_nonzero(np.sign(r)!=np.sign(p))),
        "corr":corr,
    }

def stats(vals):
    a=np.asarray(vals,dtype=float)
    return {
        "count":int(len(a)),
        "min":float(np.min(a)),
        "median":float(np.median(a)),
        "mean":float(np.mean(a)),
        "p90":float(np.percentile(a,90)),
        "max":float(np.max(a)),
        "rms":float(np.sqrt(np.mean(a*a))),
    }

def better(c,b):
    return c["rms"]<b["rms"]-CMP and c["mae"]<b["mae"]-CMP and c["sign_mismatch"]<=b["sign_mismatch"]

def noninferior(c,b):
    return c["rms"]<=b["rms"]+CMP and c["mae"]<=b["mae"]+CMP and c["sign_mismatch"]<=b["sign_mismatch"]

def endpoint(profile,total,d):
    base=b9.endpoint_candidates(profile,total,d)
    p=base["projected"]
    B=float(base["B"]); a=float(base["a_t"]); bb=float(base["b_bulk"])
    sface=(B*a+d*bb)/(B+d)
    Ki=float(base["Ki"])
    if not all(math.isfinite(x) for x in (B,a,bb,sface,Ki)) or B<=0.0 or Ki<=0.0:
        raise ValueError("invalid B9 face-interpolation endpoint")
    delta_face=d/(B+d)*(bb-a)
    delta_central=B/(B+d)*(bb-a)
    ratio=None if abs(bb-a)<=ZERO else abs(delta_face)/abs(delta_central)
    return {
        "projected":p,
        "B":B,
        "a_t":a,
        "b_bulk":bb,
        "Ki":Ki,
        "q_base":float(base["TERMINAL_SIDE_LINEAR"]),
        "s_face_endpoint":sface,
        "q_face":Ki*(1.0-sface),
        "qH":b3.KS*(1.0-a),
        "delta_face_endpoint":delta_face,
        "delta_central_endpoint":delta_central,
        "geometry_ratio_face_over_central":ratio,
    }

def kref(projected):
    _,k=b3.psi_k(np.asarray([float(projected["theta_i"])],dtype=float))
    return float(k[0])

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c4m-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--c4k-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--c4h-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--b8-result",required=True,type=pathlib.Path)
    ap.add_argument("--b9-result",required=True,type=pathlib.Path)
    ap.add_argument("--width",required=True,type=float)
    ap.add_argument("--history",required=True)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    c4m=json.loads(args.c4m_closeout.read_text())
    c4k=json.loads(args.c4k_closeout.read_text())
    c4h=json.loads(args.c4h_closeout.read_text())
    r8=json.loads(args.b8_result.read_text())
    r9=json.loads(args.b9_result.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4M_BEFORE_FACE_INTERPOLATED_GRADIENT_TEST"
    assert pre["pre_execution_operationalisation"]["before_first_C4N_execution"] is True
    assert c4m["status"]==pre["predecessors"]["C4M"]["required_status"]
    assert c4m["decision"]==pre["predecessors"]["C4M"]["required_decision"]
    assert c4m["next_authority"]==pre["predecessors"]["C4M"]["next_authority"]
    assert c4k["decision"]==pre["predecessors"]["C4K"]["required_decision"]
    assert c4h["decision"]==pre["predecessors"]["C4H"]["required_decision"]
    assert r8["decision"]==pre["predecessors"]["B8"]["required_decision"]
    assert pre["predecessors"]["B9"]["required_preferred_operator"] in r9["preferred_operator"]
    if args.width not in (2.5,5.0) or args.history not in ("WT_HOLD","WT_RISE","WT_FALL"):
        raise SystemExit("unauthorized C4N case")

    im,inodes,states,nodes=b3.load_reference(args.reference)
    rows=[]; failures=[]
    max_qiid=0.0; max_qhid=0.0; min_kref=float("inf"); min_ki=float("inf")
    max_hydro=0.0
    for B in (10.0,25.0,60.0):
        sf=(B*1.0+args.width*1.0)/(B+args.width)
        max_hydro=max(max_hydro,abs(sf-1.0))

    try:
        e0=endpoint(inodes[args.history],im[args.history]["total"],args.width)
    except Exception as exc:
        failures.append({"step":0,"error":str(exc)}); e0=None

    if e0 is not None:
        for step in range(1,b3.HISTORY_STEPS[args.history]+1):
            try:
                e1=endpoint(nodes[(args.history,step)],states[(args.history,step)]["total"],args.width)
            except Exception as exc:
                failures.append({"step":step,"error":str(exc)}); break
            p0,p1=e0["projected"],e1["projected"]
            qH_ref=states[(args.history,step)]["bottom_exchange"]/b3.OBS_DT
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
            min_kref=min(min_kref,Kr); min_ki=min(min_ki,Ki)
            if not all(math.isfinite(x) and x>0.0 for x in (Kr,Ki)):
                failures.append({"step":step,"error":"nonpositive/nonfinite interface K"}); break

            qb=0.5*(e0["q_base"]+e1["q_base"])
            qf=0.5*(e0["q_face"]+e1["q_face"])
            qhb=0.5*(e0["qH"]+e1["qH"])
            qhf=qhb
            max_qhid=max(max_qhid,abs(qhf-qhb))

            sref=1.0-qi_ref/Kr
            sbase=1.0-qb/Ki
            sface=1.0-qf/Ki
            dr=sref-sbase
            df=sface-sbase
            endpoint_ratios=[x for x in (e0["geometry_ratio_face_over_central"],e1["geometry_ratio_face_over_central"]) if x is not None]
            rows.append({
                "step":step,
                "qi_ref":qi_ref,"qi_base":qb,"qi_face":qf,
                "s_ref":sref,"s_base":sbase,"s_face":sface,
                "delta_ref":dr,"delta_face":df,
                "same_sign":(abs(dr)<=ZERO and abs(df)<=ZERO) or (dr*df>0.0),
                "face_closer":abs(sface-sref)<abs(sbase-sref),
                "geometry_ratio_face_over_central":None if not endpoint_ratios else float(np.mean(endpoint_ratios)),
            })
            e0=e1

    complete=not failures and len(rows)==b3.HISTORY_STEPS[args.history]
    if rows:
        qref=[r["qi_ref"] for r in rows]
        qi={"BASE":metrics(qref,[r["qi_base"] for r in rows]),"FACE":metrics(qref,[r["qi_face"] for r in rows])}
        sr=[r["s_ref"] for r in rows]
        slope={"BASE":metrics(sr,[r["s_base"] for r in rows]),"FACE":metrics(sr,[r["s_face"] for r in rows])}
        ratios=[r["geometry_ratio_face_over_central"] for r in rows if r["geometry_ratio_face_over_central"] is not None]
        corr={
            "delta_ref":stats([r["delta_ref"] for r in rows]),
            "delta_face":stats([r["delta_face"] for r in rows]),
            "fraction_same_sign":float(np.mean([r["same_sign"] for r in rows])),
            "fraction_face_closer_than_base":float(np.mean([r["face_closer"] for r in rows])),
            "geometry_ratio_face_over_central":stats(ratios) if ratios else None,
        }
    else:
        qi=slope=corr=None

    hard=(
        complete
        and max_qiid<=float(pre["hard_gates"]["B8_qi_identity_cm_per_day"])
        and max_qhid<=float(pre["hard_gates"]["qH_candidate_vs_B9_identity_cm_per_day"])
        and min_kref>0.0 and min_ki>0.0
        and max_hydro<=float(pre["hard_gates"]["hydrostatic_abs_slope_minus_1"])
        and all(math.isfinite(r[k]) for r in rows for k in ("qi_ref","qi_base","qi_face","s_ref","s_base","s_face"))
    )
    if not hard:
        decision="C4N_CASE_BLOCKED"
    elif args.history=="WT_HOLD":
        decision="C4N_CASE_SUPPORTED" if noninferior(qi["FACE"],qi["BASE"]) else "C4N_CASE_NOT_SUPPORTED"
    else:
        decision="C4N_CASE_SUPPORTED" if better(qi["FACE"],qi["BASE"]) else "C4N_CASE_NOT_SUPPORTED"

    result={
        "schema":"swap5.lare.bc2.c4n.case-result.v1",
        "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4N",
        "width_cm":args.width,"history":args.history,
        "decision":decision,"complete":complete,
        "hard_checks":{
            "max_B8_qi_identity_cm_per_day":max_qiid,
            "max_qH_candidate_vs_B9_identity_cm_per_day":max_qhid,
            "minimum_reference_K_cm_per_day":min_kref,
            "minimum_candidate_K_cm_per_day":min_ki,
            "max_hydrostatic_abs_slope_minus_1":max_hydro,
            "failure_count":len(failures)
        },
        "qi":qi,"slope_error":slope,"correction_geometry":corr,
        "failures":failures[:20],
        "propagated_dynamics_authorized":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
