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
QI_ID=1.0e-10
QH_ID=1.0e-12
HYD=1.0e-12

def stats(err):
    e=np.asarray(err,dtype=float)
    return {
        "count":int(len(e)),
        "bias":float(np.mean(e)),
        "mae":float(np.mean(np.abs(e))),
        "rms":float(np.sqrt(np.mean(e*e))),
        "max_abs":float(np.max(np.abs(e))),
    }

def flux_metrics(rows,key):
    ref=np.asarray([r["qi_ref"] for r in rows],dtype=float)
    pred=np.asarray([r[key] for r in rows],dtype=float)
    e=pred-ref
    corr=float(np.corrcoef(ref,pred)[0,1]) if np.std(ref)>0.0 and np.std(pred)>0.0 else None
    return {
        **stats(e),
        "sign_mismatch":int(np.count_nonzero(np.sign(ref)!=np.sign(pred))),
        "corr":corr,
    }

def better(c,b):
    return c["rms"]<b["rms"]-CMP and c["mae"]<b["mae"]-CMP and c["sign_mismatch"]<=b["sign_mismatch"]

def noninferior(c,b):
    return c["rms"]<=b["rms"]+CMP and c["mae"]<=b["mae"]+CMP and c["sign_mismatch"]<=b["sign_mismatch"]

def scalar_dist(values):
    a=np.asarray(values,dtype=float)
    return {
        "count":int(len(a)),
        "min":float(np.min(a)),
        "median":float(np.median(a)),
        "mean":float(np.mean(a)),
        "p90":float(np.percentile(a,90)),
        "max":float(np.max(a)),
        "rms":float(np.sqrt(np.mean(a*a))),
    }

def endpoint(profile,total,d):
    base=b9.endpoint_candidates(profile,total,d)
    H=float(base["projected"]["H"])
    B=float(base["B"])
    at=float(base["a_t"])
    bb=float(base["b_bulk"])
    scent=(d*at+B*bb)/(B+d)
    if not all(math.isfinite(x) for x in (H,B,at,bb,scent,float(base["Ki"]))):
        raise ValueError("nonfinite B9 central-gradient endpoint")
    cubic=c4l.solve_endpoint(profile,total,d,64)
    return {
        "H":H,"B":B,
        "a_t":at,"b_bulk":bb,
        "s_central":scent,
        "s_cubic":float(cubic["slope_i"]),
        "Ki":float(base["Ki"]),
        "q_base":float(base["TERMINAL_SIDE_LINEAR"]),
        "q_central":float(base["Ki"])*(1.0-scent),
        "q_cubic":float(cubic["qi"]),
        "qH":b3.KS*(1.0-at),
        "theta_i_ref":float(base["projected"]["theta_i"]),
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c4l-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--c4h-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--c4k-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--b8-result",required=True,type=pathlib.Path)
    ap.add_argument("--b9-result",required=True,type=pathlib.Path)
    ap.add_argument("--width",required=True,type=float)
    ap.add_argument("--history",required=True)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    c4lc=json.loads(args.c4l_closeout.read_text())
    c4hc=json.loads(args.c4h_closeout.read_text())
    c4kc=json.loads(args.c4k_closeout.read_text())
    r8=json.loads(args.b8_result.read_text())
    r9=json.loads(args.b9_result.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4L_BEFORE_INTERNAL_SLOPE_CORRECTION_REVIEW"
    assert c4lc["status"]==pre["predecessors"]["C4L"]["required_status"]
    assert c4lc["decision"]==pre["predecessors"]["C4L"]["required_decision"]
    assert c4lc["schema"]==pre["predecessors"]["C4L"]["required_schema"]
    assert c4hc["decision"]==pre["predecessors"]["C4H"]["required_decision"]
    assert c4kc["decision"]==pre["predecessors"]["C4K"]["required_decision"]
    assert r8["decision"]==pre["predecessors"]["B8"]["required_decision"]
    assert pre["predecessors"]["B9"]["required_preferred_operator"] in r9["preferred_operator"]
    if args.width not in (2.5,5.0) or args.history not in ("WT_HOLD","WT_RISE","WT_FALL"):
        raise SystemExit("unauthorized C4M case")

    im,inodes,states,nodes=b3.load_reference(args.reference)
    rows=[]
    failures=[]
    max_qiid=0.0
    max_qhid=0.0
    min_k=float("inf")

    # Algebraic manufactured hydrostatic identity of the central slope.
    max_hydro=0.0
    for B in (10.0,25.0,60.0):
        s=(args.width*1.0+B*1.0)/(B+args.width)
        max_hydro=max(max_hydro,abs(s-1.0))

    try:
        e0=endpoint(inodes[args.history],im[args.history]["total"],args.width)
    except Exception as exc:
        failures.append({"step":0,"error":str(exc)})
        e0=None

    if e0 is not None:
        for step in range(1,b3.HISTORY_STEPS[args.history]+1):
            try:
                e1=endpoint(nodes[(args.history,step)],states[(args.history,step)]["total"],args.width)
            except Exception as exc:
                failures.append({"step":step,"error":str(exc)})
                break

            p0=b8.projected(inodes[args.history] if step==1 else nodes[(args.history,step-1)],
                            im[args.history]["total"] if step==1 else states[(args.history,step-1)]["total"],args.width)
            p1=b8.projected(nodes[(args.history,step)],states[(args.history,step)]["total"],args.width)
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

            _,k0=b3.psi_k(np.asarray([float(p0["theta_i"])],dtype=float))
            _,k1=b3.psi_k(np.asarray([float(p1["theta_i"])],dtype=float))
            Kref=0.5*(float(k0[0])+float(k1[0]))
            if not math.isfinite(Kref) or Kref<=0.0:
                failures.append({"step":step,"error":"nonpositive/nonfinite Reference interface K"})
                break
            min_k=min(min_k,Kref)
            sref=1.0-qi_ref/Kref

            sbase=0.5*(e0["a_t"]+e1["a_t"])
            scent=0.5*(e0["s_central"]+e1["s_central"])
            scub=0.5*(e0["s_cubic"]+e1["s_cubic"])

            qbase=0.5*(e0["q_base"]+e1["q_base"])
            qcent=0.5*(e0["q_central"]+e1["q_central"])
            qcub=0.5*(e0["q_cubic"]+e1["q_cubic"])
            qhbase=0.5*(e0["qH"]+e1["qH"])
            qhcent=qhbase
            max_qhid=max(max_qhid,abs(qhcent-qhbase))

            dref=sref-sbase
            dcent=scent-sbase
            dcub=scub-sbase
            rows.append({
                "step":step,
                "qi_ref":qi_ref,
                "BASE_qi":qbase,
                "CENTRAL_qi":qcent,
                "CUBIC_qi":qcub,
                "s_ref":sref,
                "s_base":sbase,
                "s_central":scent,
                "s_cubic":scub,
                "delta_ref":dref,
                "delta_central":dcent,
                "delta_cubic":dcub,
                "central_sign_match":(dcent==0.0 and dref==0.0) or (dcent*dref>0.0),
                "cubic_sign_match":(dcub==0.0 and dref==0.0) or (dcub*dref>0.0),
                "central_closer_than_base":abs(scent-sref)<abs(sbase-sref),
                "central_closer_than_cubic":abs(scent-sref)<abs(scub-sref),
                "cubic_closer_than_base":abs(scub-sref)<abs(sbase-sref),
            })
            e0=e1

    complete=(not failures and len(rows)==b3.HISTORY_STEPS[args.history])
    if rows:
        slope={
            "BASE":stats([r["s_base"]-r["s_ref"] for r in rows]),
            "CENTRAL":stats([r["s_central"]-r["s_ref"] for r in rows]),
            "CUBIC":stats([r["s_cubic"]-r["s_ref"] for r in rows]),
        }
        flux={k:flux_metrics(rows,k+"_qi") for k in ("BASE","CENTRAL","CUBIC")}
        correction={
            "delta_ref":scalar_dist([r["delta_ref"] for r in rows]),
            "delta_central":scalar_dist([r["delta_central"] for r in rows]),
            "delta_cubic":scalar_dist([r["delta_cubic"] for r in rows]),
            "fraction_central_sign_match":float(np.mean([r["central_sign_match"] for r in rows])),
            "fraction_cubic_sign_match":float(np.mean([r["cubic_sign_match"] for r in rows])),
            "fraction_central_closer_than_base":float(np.mean([r["central_closer_than_base"] for r in rows])),
            "fraction_central_closer_than_cubic":float(np.mean([r["central_closer_than_cubic"] for r in rows])),
            "fraction_cubic_closer_than_base":float(np.mean([r["cubic_closer_than_base"] for r in rows])),
        }
    else:
        slope=flux=correction=None

    hard=(
        complete
        and max_qiid<=float(pre["hard_gates"]["B8_qi_identity_cm_per_day"])
        and max_qhid<=float(pre["hard_gates"]["qH_central_vs_B9_identity_cm_per_day"])
        and min_k>0.0
        and max_hydro<=float(pre["hard_gates"]["central_hydrostatic_abs_slope_minus_1"])
        and all(math.isfinite(r[k]) for r in rows for k in ("qi_ref","BASE_qi","CENTRAL_qi","CUBIC_qi","s_ref","s_base","s_central","s_cubic"))
    )
    if not hard:
        decision="C4M_CASE_BLOCKED"
    elif args.history=="WT_HOLD":
        decision="C4M_CASE_SUPPORTED" if noninferior(flux["CENTRAL"],flux["BASE"]) else "C4M_CASE_NOT_SUPPORTED"
    else:
        decision="C4M_CASE_SUPPORTED" if better(flux["CENTRAL"],flux["BASE"]) else "C4M_CASE_NOT_SUPPORTED"

    result={
        "schema":"swap5.lare.bc2.c4m.case-result.v1",
        "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4M",
        "width_cm":args.width,"history":args.history,
        "decision":decision,"complete":complete,
        "hard_checks":{
            "max_B8_qi_identity_cm_per_day":max_qiid,
            "max_qH_central_vs_B9_identity_cm_per_day":max_qhid,
            "minimum_reference_interface_K_cm_per_day":min_k,
            "max_central_hydrostatic_abs_slope_minus_1":max_hydro,
            "failure_count":len(failures)
        },
        "slope_error":slope,
        "qi":flux,
        "correction":correction,
        "failures":failures[:20],
        "propagated_dynamics_authorized":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,"width_cm":args.width,"history":args.history,
        "hard_checks":result["hard_checks"],"slope_error":slope,"qi":flux,"correction":correction,
        "failures":failures[:20]
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
