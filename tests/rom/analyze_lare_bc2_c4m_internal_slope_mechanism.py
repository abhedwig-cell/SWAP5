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

c4l=load_module("bc2c4l_for_c4m","analyze_lare_bc2_c4l_qh_preserving_cubic.py")
b9=c4l.b9
b8=c4l.b8
b3=c4l.b3

CMP=1.0e-12
ZERO=1.0e-12
C4L_REPRO=1.0e-10

def metrics(ref,pred):
    r=np.asarray(ref,dtype=float); p=np.asarray(pred,dtype=float); e=p-r
    corr=float(np.corrcoef(r,p)[0,1]) if np.std(r)>0.0 and np.std(p)>0.0 else None
    return {
        "count":int(len(e)),"bias":float(np.mean(e)),"mae":float(np.mean(np.abs(e))),
        "rms":float(np.sqrt(np.mean(e*e))),"max_abs":float(np.max(np.abs(e))),
        "sign_mismatch":int(np.count_nonzero(np.sign(r)!=np.sign(p))),"corr":corr
    }

def stats(x):
    a=np.asarray(x,dtype=float)
    return {"count":int(len(a)),"min":float(np.min(a)),"mean":float(np.mean(a)),
            "median":float(np.median(a)),"max":float(np.max(a)),
            "rms":float(np.sqrt(np.mean(a*a)))}

def cosine(a,b):
    x=np.asarray(a,dtype=float); y=np.asarray(b,dtype=float)
    den=float(np.sqrt(np.dot(x,x)*np.dot(y,y)))
    return None if den<=ZERO else float(np.dot(x,y)/den)

def corr(a,b):
    x=np.asarray(a,dtype=float); y=np.asarray(b,dtype=float)
    return None if np.std(x)<=ZERO or np.std(y)<=ZERO else float(np.corrcoef(x,y)[0,1])

def better(c,b):
    return c["rms"]<b["rms"]-CMP and c["mae"]<b["mae"]-CMP and c["sign_mismatch"]<=b["sign_mismatch"]

def noninferior(c,b):
    return c["rms"]<=b["rms"]+CMP and c["mae"]<=b["mae"]+CMP and c["sign_mismatch"]<=b["sign_mismatch"]

def k_ref(projected):
    _,kk=b3.psi_k(np.asarray([float(projected["theta_i"])],dtype=float))
    return float(kk[0])

def endpoint(profile,total,d):
    p=b8.projected(profile,total,d)
    base=b9.endpoint_candidates(profile,total,d)
    cub=c4l.solve_endpoint(profile,total,d,64)
    B=float(base["B"])
    a=float(base["a_t"]); bb=float(base["b_bulk"])
    sc=(d*a+B*bb)/(B+d)
    qi_central=float(base["Ki"])*(1.0-sc)
    return {
        "projected":p,
        "Kref":k_ref(p),
        "Ki_base":float(base["Ki"]),
        "a_t":a,
        "b_bulk":bb,
        "s_central_endpoint":sc,
        "qi_base_endpoint":float(base["TERMINAL_SIDE_LINEAR"]),
        "qi_central_endpoint":qi_central,
        "qH_base_endpoint":b3.KS*(1.0-a),
        "qH_central_endpoint":b3.KS*(1.0-a),
        "Ki_cubic":float(cub["Ki"]),
        "s_cubic_endpoint":float(cub["slope_i"]),
        "qi_cubic_endpoint":float(cub["qi"]),
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c4l-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--c4l-result",required=True,type=pathlib.Path)
    ap.add_argument("--c4h-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--c4k-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--b8-result",required=True,type=pathlib.Path)
    ap.add_argument("--b9-result",required=True,type=pathlib.Path)
    ap.add_argument("--width",required=True,type=float)
    ap.add_argument("--history",required=True)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    c4lc=json.loads(args.c4l_closeout.read_text()); c4lr=json.loads(args.c4l_result.read_text())
    c4h=json.loads(args.c4h_closeout.read_text()); c4k=json.loads(args.c4k_closeout.read_text())
    r8=json.loads(args.b8_result.read_text()); r9=json.loads(args.b9_result.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4L_BEFORE_INTERNAL_SLOPE_CORRECTION_REVIEW"
    assert pre["pre_execution_operationalisation"]["before_first_C4M_execution"] is True
    assert c4lc["schema"]==pre["predecessors"]["C4L"]["required_schema"]
    assert c4lc["status"]==pre["predecessors"]["C4L"]["required_status"]
    assert c4lc["decision"]==pre["predecessors"]["C4L"]["required_decision"]
    assert c4h["decision"]==pre["predecessors"]["C4H"]["required_decision"]
    assert c4k["decision"]==pre["predecessors"]["C4K"]["required_decision"]
    assert r8["decision"]==pre["predecessors"]["B8"]["required_decision"]
    assert pre["predecessors"]["B9"]["required_preferred_operator"] in r9["preferred_operator"]
    if args.width not in (2.5,5.0) or args.history not in ("WT_HOLD","WT_RISE","WT_FALL"):
        raise SystemExit("unauthorized case")

    im,inodes,states,nodes=b3.load_reference(args.reference)
    rows=[]; failures=[]; max_qiid=0.0; max_qhid=0.0; min_k=float("inf")

    max_hydro=0.0
    for Htest in (105.0,120.0,138.0):
        Ltest=Htest-b3.ANCHOR
        Btest=Ltest-args.width
        if Btest<=0.0:
            raise RuntimeError("invalid manufactured central geometry")
        sh=(args.width*1.0+Btest*1.0)/(Btest+args.width)
        max_hydro=max(max_hydro,abs(sh-1.0))
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
            qi_b=q90+Gi-dWb; qi_t=dWt+qH_ref-b3.THETA_S*Hdot+Gi
            max_qiid=max(max_qiid,abs(qi_b-qi_t)); qi_ref=0.5*(qi_b+qi_t)

            Kref=0.5*(e0["Kref"]+e1["Kref"])
            Kbase=0.5*(e0["Ki_base"]+e1["Ki_base"])
            Kcub=0.5*(e0["Ki_cubic"]+e1["Ki_cubic"])
            min_k=min(min_k,Kref,Kbase,Kcub)
            if min(Kref,Kbase,Kcub)<=0.0 or not all(math.isfinite(x) for x in (Kref,Kbase,Kcub)):
                failures.append({"step":step,"error":"nonpositive or nonfinite interface K"}); break

            qb=0.5*(e0["qi_base_endpoint"]+e1["qi_base_endpoint"])
            qc=0.5*(e0["qi_central_endpoint"]+e1["qi_central_endpoint"])
            qcu=0.5*(e0["qi_cubic_endpoint"]+e1["qi_cubic_endpoint"])
            qhb=0.5*(e0["qH_base_endpoint"]+e1["qH_base_endpoint"])
            qhc=0.5*(e0["qH_central_endpoint"]+e1["qH_central_endpoint"])
            max_qhid=max(max_qhid,abs(qhc-qhb))

            sref=1.0-qi_ref/Kref
            sb=1.0-qb/Kbase
            sc=1.0-qc/Kbase
            scu=1.0-qcu/Kcub

            rows.append({
                "step":step,"qi_ref":qi_ref,"qi_base":qb,"qi_central":qc,"qi_cubic":qcu,
                "qH_base":qhb,"qH_central":qhc,
                "s_ref":sref,"s_base":sb,"s_central":sc,"s_cubic":scu,
                "delta_ref":sref-sb,"delta_central":sc-sb,"delta_cubic":scu-sb,
                "endpoint_slope_base":0.5*(e0["a_t"]+e1["a_t"]),
                "endpoint_slope_bulk":0.5*(e0["b_bulk"]+e1["b_bulk"]),
                "endpoint_slope_central":0.5*(e0["s_central_endpoint"]+e1["s_central_endpoint"]),
                "endpoint_slope_cubic":0.5*(e0["s_cubic_endpoint"]+e1["s_cubic_endpoint"]),
            })
            e0=e1

    complete=not failures and len(rows)==b3.HISTORY_STEPS[args.history]
    hard=complete and max_qiid<=1e-10 and max_qhid<=1e-12 and min_k>0.0 and max_hydro<=1e-12

    if rows:
        qref=[r["qi_ref"] for r in rows]
        qi={
          "BASE":metrics(qref,[r["qi_base"] for r in rows]),
          "CENTRAL":metrics(qref,[r["qi_central"] for r in rows]),
          "CUBIC":metrics(qref,[r["qi_cubic"] for r in rows]),
        }
        sref=[r["s_ref"] for r in rows]
        slope={
          "BASE":metrics(sref,[r["s_base"] for r in rows]),
          "CENTRAL":metrics(sref,[r["s_central"] for r in rows]),
          "CUBIC":metrics(sref,[r["s_cubic"] for r in rows]),
        }
        dr=np.asarray([r["delta_ref"] for r in rows]); dc=np.asarray([r["delta_central"] for r in rows]); dcu=np.asarray([r["delta_cubic"] for r in rows])
        mask=np.abs(dr)>ZERO
        same_c=float(np.mean((dr[mask]*dc[mask])>0.0)) if np.any(mask) else None
        same_cu=float(np.mean((dr[mask]*dcu[mask])>0.0)) if np.any(mask) else None
        central_closer=float(np.mean(np.abs(np.asarray([r["s_central"] for r in rows])-np.asarray(sref)) < np.abs(np.asarray([r["s_base"] for r in rows])-np.asarray(sref))))
        central_vs_cubic=float(np.mean(np.abs(np.asarray([r["s_central"] for r in rows])-np.asarray(sref)) < np.abs(np.asarray([r["s_cubic"] for r in rows])-np.asarray(sref))))
        correction={
          "delta_ref":stats(dr),"delta_central":stats(dc),"delta_cubic":stats(dcu),
          "central_vs_required_cosine":cosine(dc,dr),"central_vs_required_correlation":corr(dc,dr),
          "cubic_vs_required_cosine":cosine(dcu,dr),"cubic_vs_required_correlation":corr(dcu,dr),
          "central_same_sign_fraction":same_c,"cubic_same_sign_fraction":same_cu,
          "central_slope_closer_than_baseline_fraction":central_closer,
          "central_slope_closer_than_cubic_fraction":central_vs_cubic,
        }
        endpoint_diag={
          "base":stats([r["endpoint_slope_base"] for r in rows]),
          "bulk":stats([r["endpoint_slope_bulk"] for r in rows]),
          "central":stats([r["endpoint_slope_central"] for r in rows]),
          "cubic":stats([r["endpoint_slope_cubic"] for r in rows]),
        }
    else:
        qi=slope=correction=endpoint_diag=None

    key=str(args.width)
    auth=c4lr["summary"][key][args.history]["qi_CUBIC"]
    c4l_reproduced=bool(qi and abs(qi["CUBIC"]["rms"]-auth["rms"])<=C4L_REPRO and abs(qi["CUBIC"]["mae"]-auth["mae"])<=C4L_REPRO)
    hard = hard and c4l_reproduced

    if not hard:
        decision="C4M_CASE_BLOCKED"
    elif args.history=="WT_HOLD":
        decision="C4M_CASE_SUPPORTED" if noninferior(qi["CENTRAL"],qi["BASE"]) else "C4M_CASE_NOT_SUPPORTED"
    else:
        decision="C4M_CASE_SUPPORTED" if better(qi["CENTRAL"],qi["BASE"]) else "C4M_CASE_NOT_SUPPORTED"

    result={
      "schema":"swap5.lare.bc2.c4m.case-result.v1","work_unit":"LARE-BC2-C4M",
      "width_cm":args.width,"history":args.history,"decision":decision,"complete":complete,
      "hard_checks":{"max_B8_qi_identity_cm_per_day":max_qiid,"max_qH_central_vs_B9_identity_cm_per_day":max_qhid,
                     "minimum_interface_K_cm_per_day":min_k,"central_hydrostatic_abs_slope_minus_1":max_hydro,
                     "C4L_cubic_metrics_reproduced":c4l_reproduced,"failure_count":len(failures)},
      "qi":qi,"slope_error":slope,"correction_geometry":correction,"endpoint_slope_diagnostics":endpoint_diag,
      "failures":failures[:20],"propagated_dynamics_authorized":False,"production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
