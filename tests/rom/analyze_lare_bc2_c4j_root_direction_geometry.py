#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import math
import pathlib

import numpy as np
from scipy.optimize import least_squares

HERE=pathlib.Path(__file__).resolve().parent

def load_module(name,filename):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

c4i=load_module("bc2c4i_for_c4j","analyze_lare_bc2_c4i_quadratic_storage_profile.py")
b9=c4i.b9
b8=c4i.b8
b3=c4i.b3

DROOT=2.5
DGEOM=5.0
HISTORIES=("WT_HOLD","WT_RISE","WT_FALL")
NQS=(64,128)
ROOT_GATE=1.0e-10
QI_GATE=1.0e-10
FLUX_CROSS_GATE=5.0e-8
CMP_TOL=1.0e-12

def root_derived(a,b,d):
    H_dummy=None
    psi_i=a*d+b*d*d
    theta_i=float(b3.theta_from_psi(psi_i))
    _,ki=b3.psi_k(np.asarray([theta_i],dtype=float))
    Ki=float(ki[0])
    slope_i=a+2.0*b*d
    return {
        "a":float(a),"b":float(b),"psi_i":float(psi_i),
        "theta_i":theta_i,"Ki":Ki,"slope_i":float(slope_i),
        "qi_cm_per_day":float(Ki*(1.0-slope_i)),
        "qH_cm_per_day":float(b3.KS*(1.0-a)),
    }

def enumerate_roots(Wt,Wb,H,d,baseline,nq):
    L=H-b3.ANCHOR
    psi_i_seed=max(0.0,float(baseline["psi_i"]))
    psi_anchor_seed=max(0.0,psi_i_seed+float(baseline["b_bulk"])*(L-d))
    seeds=[
        np.asarray([psi_i_seed,psi_anchor_seed],dtype=float),
        np.asarray([d,L],dtype=float),
        0.5*np.asarray([psi_i_seed,psi_anchor_seed],dtype=float),
        2.0*np.asarray([psi_i_seed,psi_anchor_seed],dtype=float),
    ]
    valid=[]
    starts=[]
    max_res=0.0
    for idx,seed in enumerate(seeds):
        sol=least_squares(
            c4i.storage_residuals_pressures,
            x0=np.maximum(seed,0.0),
            bounds=(np.zeros(2),np.full(2,np.inf)),
            args=(Wt,Wb,L,d,nq),
            xtol=1e-13,ftol=1e-13,gtol=1e-13,max_nfev=300,
        )
        psi_i=float(sol.x[0]); psi_anchor=float(sol.x[1])
        a,b=c4i.coeffs_from_pressures(psi_i,psi_anchor,L,d)
        minpsi=c4i.profile_minimum(a,b,L)
        rr=c4i.storage_residuals_pressures(sol.x,Wt,Wb,L,d,nq)
        res=float(np.max(np.abs(rr)))
        max_res=max(max_res,res)
        physical=math.isfinite(a) and math.isfinite(b) and minpsi>=-c4i.PSI_TOL
        ok=bool(sol.success and physical and res<=ROOT_GATE)
        row={
            "start_index":idx,"valid":ok,"psi_i":psi_i,"psi_anchor":psi_anchor,
            "a":a,"b":b,"minimum_psi":minpsi,"max_storage_residual_cm":res
        }
        if ok:
            row.update(root_derived(a,b,d))
            valid.append(row)
        starts.append(row)

    clusters=[]
    for r in valid:
        placed=False
        for cl in clusters:
            if c4i.root_close((r["a"],r["b"]),(cl[0]["a"],cl[0]["b"])):
                cl.append(r); placed=True; break
        if not placed:
            clusters.append([r])

    reps=[]
    for cl in clusters:
        a=float(np.mean([x["a"] for x in cl]))
        b=float(np.mean([x["b"] for x in cl]))
        rep=root_derived(a,b,d)
        rep["psi_anchor"]=float(np.mean([x["psi_anchor"] for x in cl]))
        rep["member_start_indices"]=[int(x["start_index"]) for x in cl]
        rep["max_member_storage_residual_cm"]=float(max(x["max_storage_residual_cm"] for x in cl))
        reps.append(rep)
    reps=sorted(reps,key=lambda x:(x["a"],x["b"]))
    pair_sep=None
    if len(reps)>=2:
        vals=[]
        for i in range(len(reps)):
            for j in range(i+1,len(reps)):
                vals.append(math.hypot(reps[i]["a"]-reps[j]["a"],reps[i]["b"]-reps[j]["b"]))
        pair_sep=float(min(vals))
    flux_spread={
        "qi_cm_per_day":0.0 if not reps else float(max(x["qi_cm_per_day"] for x in reps)-min(x["qi_cm_per_day"] for x in reps)),
        "qH_cm_per_day":0.0 if not reps else float(max(x["qH_cm_per_day"] for x in reps)-min(x["qH_cm_per_day"] for x in reps)),
    }
    return {
        "valid_root_count":len(valid),
        "distinct_cluster_count":len(reps),
        "minimum_pairwise_ab_separation":pair_sep,
        "flux_spread":flux_spread,
        "clusters":reps,
        "starts":starts,
        "max_storage_residual_cm":max_res,
    }

def match_clusters(a,b):
    if len(a)!=len(b):
        return [],float("inf")
    unused=set(range(len(b)))
    matches=[]
    max_flux=0.0
    for i,ra in enumerate(a):
        j=min(unused,key=lambda k:math.hypot(ra["a"]-b[k]["a"],ra["b"]-b[k]["b"]))
        unused.remove(j)
        rb=b[j]
        qdiff=max(abs(ra["qi_cm_per_day"]-rb["qi_cm_per_day"]),abs(ra["qH_cm_per_day"]-rb["qH_cm_per_day"]))
        max_flux=max(max_flux,qdiff)
        matches.append({
            "cluster64":i,"cluster128":j,
            "ab_distance":math.hypot(ra["a"]-rb["a"],ra["b"]-rb["b"]),
            "qi_difference_cm_per_day":abs(ra["qi_cm_per_day"]-rb["qi_cm_per_day"]),
            "qH_difference_cm_per_day":abs(ra["qH_cm_per_day"]-rb["qH_cm_per_day"])
        })
    return matches,max_flux

def metrics(errors):
    e=np.asarray(errors,dtype=float)
    return {
        "count":int(len(e)),
        "bias":float(np.mean(e)),
        "mae":float(np.mean(np.abs(e))),
        "rms":float(np.sqrt(np.mean(e*e))),
        "max_abs":float(np.max(np.abs(e))),
    }

def strict_improve(c,b):
    return c["rms"]<b["rms"]-CMP_TOL and c["mae"]<b["mae"]-CMP_TOL

def strict_worsen(c,b):
    return c["rms"]>b["rms"]+CMP_TOL and c["mae"]>b["mae"]+CMP_TOL

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--reference",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c4i-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--c4h-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--b8-result",required=True,type=pathlib.Path)
    ap.add_argument("--b9-result",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    pre=json.loads(args.prereg.read_text())
    c4ic=json.loads(args.c4i_closeout.read_text())
    c4hc=json.loads(args.c4h_closeout.read_text())
    r8=json.loads(args.b8_result.read_text())
    r9=json.loads(args.b9_result.read_text())
    assert pre["phase"]=="PREREGISTERED_AFTER_C4I_BEFORE_ROOT_AND_DIRECTION_GEOMETRY_DIAGNOSTIC"
    assert pre["pre_execution_operationalisation"]["before_first_C4J_execution"] is True
    assert c4ic["status"]==pre["predecessors"]["C4I"]["required_status"]
    assert c4ic["decision"]==pre["predecessors"]["C4I"]["required_decision"]
    assert c4hc["decision"]==pre["predecessors"]["C4H"]["required_decision"]
    assert r8["decision"]==pre["predecessors"]["B8"]["required_decision"]
    assert pre["predecessors"]["B9"]["required_preferred_operator"] in r9["preferred_operator"]

    init_meta,init_nodes,states,nodes=b3.load_reference(args.reference)

    # Diagnostic A
    root_map={}
    max_root_res=0.0
    max_cross_flux=0.0
    root_support=True
    for history in HISTORIES:
        profile=init_nodes[history]
        total=init_meta[history]["total"]
        p=b8.projected(profile,total,DROOT)
        baseline=b9.endpoint_candidates(profile,total,DROOT)
        byq={}
        for nq in NQS:
            row=enumerate_roots(float(p["Wt64"]),float(p["Wb64"]),float(p["H"]),DROOT,baseline,nq)
            byq[str(nq)]=row
            max_root_res=max(max_root_res,row["max_storage_residual_cm"])
        matches,cross=match_clusters(byq["64"]["clusters"],byq["128"]["clusters"])
        max_cross_flux=max(max_cross_flux,cross)
        hist_support=(
            byq["64"]["distinct_cluster_count"]>=2
            and byq["128"]["distinct_cluster_count"]>=2
            and byq["64"]["distinct_cluster_count"]==byq["128"]["distinct_cluster_count"]
            and cross<=FLUX_CROSS_GATE
        )
        root_support &= hist_support
        root_map[history]={
            "H_cm":float(p["H"]),"Wb_cm":float(p["Wb64"]),"Wt_cm":float(p["Wt64"]),
            "quadrature":byq,"cross_quadrature_matches":matches,
            "max_cross_quadrature_flux_difference_cm_per_day":cross,
            "root_multiplicity_supported":hist_support
        }

    # Diagnostic B
    geom={}
    max_qi_identity=0.0
    min_K=float("inf")
    geom_complete=True
    for history in HISTORIES:
        rows=[]
        try:
            prev_profile=init_nodes[history]
            prev_total=init_meta[history]["total"]
            p0=b8.projected(prev_profile,prev_total,DGEOM)
            b0=b9.endpoint_candidates(prev_profile,prev_total,DGEOM)
            q0=c4i.solve_quadratic(float(p0["Wt64"]),float(p0["Wb64"]),float(p0["H"]),DGEOM,b0,64)
        except Exception as exc:
            geom[history]={"status":"BLOCKED","error":str(exc)}
            geom_complete=False
            continue

        for step in range(1,b3.HISTORY_STEPS[history]+1):
            try:
                profile=nodes[(history,step)]
                total=states[(history,step)]["total"]
                p1=b8.projected(profile,total,DGEOM)
                b1=b9.endpoint_candidates(profile,total,DGEOM)
                q1=c4i.solve_quadratic(float(p1["Wt64"]),float(p1["Wb64"]),float(p1["H"]),DGEOM,b1,64)
            except Exception as exc:
                geom[history]={"status":"BLOCKED","step":step,"error":str(exc)}
                geom_complete=False
                rows=[]
                break

            qH_ref=states[(history,step)]["bottom_exchange"]/b3.OBS_DT
            q90=-(p1["Wfixed"]-p0["Wfixed"])/b3.OBS_DT
            Hdot=(p1["H"]-p0["H"])/b3.OBS_DT
            Gi=0.5*(p0["theta_i"]+p1["theta_i"])*Hdot
            dWb=(p1["Wb64"]-p0["Wb64"])/b3.OBS_DT
            dWt=(p1["Wt64"]-p0["Wt64"])/b3.OBS_DT
            qi_bulk=q90+Gi-dWb
            qi_term=dWt+qH_ref-b3.THETA_S*Hdot+Gi
            max_qi_identity=max(max_qi_identity,abs(qi_bulk-qi_term))
            qi_ref=0.5*(qi_bulk+qi_term)

            _,k0=b3.psi_k(np.asarray([float(p0["theta_i"])],dtype=float))
            _,k1=b3.psi_k(np.asarray([float(p1["theta_i"])],dtype=float))
            Kref=0.5*(float(k0[0])+float(k1[0]))
            min_K=min(min_K,Kref)
            if not math.isfinite(Kref) or Kref<=0.0:
                geom[history]={"status":"BLOCKED","step":step,"error":"nonpositive Reference interface K"}
                geom_complete=False
                rows=[]
                break

            s_ref=1.0-qi_ref/Kref
            a_ref=1.0-qH_ref/b3.KS
            s_base=0.5*(float(b0["a_t"])+float(b1["a_t"]))
            a_base=s_base
            s_quad=0.5*(float(q0["slope_i"])+float(q1["slope_i"]))
            a_quad=0.5*(float(q0["a"])+float(q1["a"]))
            rows.append({
                "step":step,
                "s_ref":s_ref,"a_ref":a_ref,
                "s_base":s_base,"a_base":a_base,
                "s_quad":s_quad,"a_quad":a_quad,
                "abs_s_quad_better":abs(s_quad-s_ref)<abs(s_base-s_ref),
                "abs_a_quad_better":abs(a_quad-a_ref)<abs(a_base-a_ref),
            })
            p0,b0,q0=p1,b1,q1

        if rows:
            sb=metrics([r["s_base"]-r["s_ref"] for r in rows])
            sq=metrics([r["s_quad"]-r["s_ref"] for r in rows])
            ab=metrics([r["a_base"]-r["a_ref"] for r in rows])
            aq=metrics([r["a_quad"]-r["a_ref"] for r in rows])
            geom[history]={
                "status":"COMPLETE",
                "interval_count":len(rows),
                "interface_slope_error":{"BASE":sb,"QUADRATIC":sq},
                "water_table_slope_error":{"BASE":ab,"QUADRATIC":aq},
                "fraction_interface_abs_error_improved":float(np.mean([r["abs_s_quad_better"] for r in rows])),
                "fraction_water_table_abs_error_improved":float(np.mean([r["abs_a_quad_better"] for r in rows])),
                "mean_reference_interface_slope":float(np.mean([r["s_ref"] for r in rows])),
                "mean_reference_water_table_slope":float(np.mean([r["a_ref"] for r in rows])),
            }

    direction_support=False
    if geom_complete:
        fall=geom["WT_FALL"]; rise=geom["WT_RISE"]; hold=geom["WT_HOLD"]
        fall_ok=(
            strict_improve(fall["interface_slope_error"]["QUADRATIC"],fall["interface_slope_error"]["BASE"])
            and strict_improve(fall["water_table_slope_error"]["QUADRATIC"],fall["water_table_slope_error"]["BASE"])
        )
        rise_ok=(
            strict_worsen(rise["interface_slope_error"]["QUADRATIC"],rise["interface_slope_error"]["BASE"])
            and strict_worsen(rise["water_table_slope_error"]["QUADRATIC"],rise["water_table_slope_error"]["BASE"])
        )
        hi=hold["interface_slope_error"]; hw=hold["water_table_slope_error"]
        hold_fail=(
            hi["QUADRATIC"]["rms"]>hi["BASE"]["rms"]+CMP_TOL
            or hi["QUADRATIC"]["mae"]>hi["BASE"]["mae"]+CMP_TOL
            or hw["QUADRATIC"]["rms"]>hw["BASE"]["rms"]+CMP_TOL
            or hw["QUADRATIC"]["mae"]>hw["BASE"]["mae"]+CMP_TOL
        )
        direction_support=fall_ok and rise_ok and hold_fail
        geom["support_components"]={"WT_FALL_improves_both":fall_ok,"WT_RISE_worsens_both":rise_ok,"WT_HOLD_fails_noninferiority":hold_fail}

    hard_ok=(
        max_root_res<=ROOT_GATE
        and max_cross_flux<=FLUX_CROSS_GATE
        and geom_complete
        and max_qi_identity<=QI_GATE
        and min_K>0.0
    )
    if not hard_ok:
        decision="C4J_DIAGNOSTIC_BLOCKED"
    elif root_support and direction_support:
        decision="QUADRATIC_MULTIVALUED_AND_DIRECTION_GEOMETRY_CONFIRMED"
    elif root_support:
        decision="QUADRATIC_ROOT_MULTIPLICITY_ONLY"
    elif direction_support:
        decision="QUADRATIC_DIRECTION_GEOMETRY_ONLY"
    else:
        decision="C4J_MECHANISM_PARTIAL"

    result={
        "schema":"swap5.lare.bc2.c4j.result.v1",
        "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C4J",
        "decision":decision,
        "hard_checks":{
            "max_root_storage_residual_cm":max_root_res,
            "root_storage_gate_cm":ROOT_GATE,
            "max_cross_quadrature_root_flux_difference_cm_per_day":max_cross_flux,
            "root_flux_crosscheck_gate_cm_per_day":FLUX_CROSS_GATE,
            "max_abs_B8_qi_identity_cm_per_day":max_qi_identity,
            "B8_qi_identity_gate_cm_per_day":QI_GATE,
            "minimum_reference_interface_K_cm_per_day":min_K
        },
        "diagnostic_A":{"supported":root_support,"root_map":root_map},
        "diagnostic_B":{"supported":direction_support,"geometry":geom},
        "interpretation":[
            "C4J characterizes the failed C4I profile family; it does not select among roots or introduce a replacement closure.",
            "Multiple quadratic roots with different flux predictions under identical Wb/Wt/H demonstrate non-identifiability of this reconstruction family, not generic insufficiency of all reduced states.",
            "The 5 cm comparison is performed in effective gradient space, consistent with C4H's finding that the residual qi error is gradient-component dominant.",
            "If FALL improves and RISE worsens in both interface and water-table slopes, the C4I direction dependence is a reconstruction-geometry effect rather than a conductivity effect."
        ],
        "next_authority":"SCIENTIFIC_CHOICE_REQUIRED_BETWEEN_RICHER_STATE_AND_DIFFERENT_CONSTRAINED_GRADIENT_REPRESENTATION" if decision=="QUADRATIC_MULTIVALUED_AND_DIRECTION_GEOMETRY_CONFIRMED" else "MECHANISM_REMAINS_PARTIAL",
        "next_model_change_authorized":False,
        "groundwater_feedback_authorized":False,
        "application_acceptance_adjudicated":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "hard_checks":result["hard_checks"],
        "diagnostic_A_supported":root_support,
        "diagnostic_B_supported":direction_support,
        "root_summary":{h:{
            "clusters64":root_map[h]["quadrature"]["64"]["distinct_cluster_count"],
            "clusters128":root_map[h]["quadrature"]["128"]["distinct_cluster_count"],
            "flux_spread64":root_map[h]["quadrature"]["64"]["flux_spread"],
            "cross_flux":root_map[h]["max_cross_quadrature_flux_difference_cm_per_day"]
        } for h in HISTORIES},
        "geometry":geom
    },sort_keys=True))
    return 0 if hard_ok else 2

if __name__=="__main__":
    raise SystemExit(main())
