#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib
import sys

import numpy as np

HERE=pathlib.Path(__file__).resolve().parent
CODE_TOL=1.0e-12
MEMBERS=("S4","G4","U4")
SURF_H=("S05","S06","S07","S08")
GW_H=("G01","G02","G03","G04")


def load_module(name:str,path:pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod


p1ref=load_module("rom_purpose_p2_p1_reference_analysis",HERE/"analyze_rom_purpose_p1_reference.py")
p2ref=load_module("rom_purpose_p2_fresh_reference_analysis",HERE/"analyze_rom_purpose_p2_reference.py")


def rmse(x)->float:
    a=np.asarray(x,dtype=float)
    return float(np.sqrt(np.mean(np.square(a))))


def extrema_timing(a,b)->int:
    # Frozen P1 candidate metric semantics are retained. P2 changed Reference
    # observability qualification, not this placement metric operator.
    worst=0
    for aa,bb in ((a["root"],b["root"]),(a["upper"],b["upper"])):
        for fn in (np.argmin,np.argmax):
            worst=max(worst,abs(int(fn(aa))-int(fn(bb))))
    return worst


def reversals(values):
    return p1ref.reversals(values)


def surface_metrics(candidate:dict,reference:dict)->dict[str,float|int]:
    pools={k:[] for k in (
      "surface_0_20_storage_error_cm","root_zone_0_40_storage_error_cm",
      "upper_0_80_storage_error_cm","mapped_10cm_theta_error","total_storage_error_cm")}
    timing=0
    signed=[]
    for h in SURF_H:
        c=candidate[h]; r=reference["histories"][h]
        cs=np.asarray(c["surface_0_20_storage_cm"],float)
        cr=np.asarray(c["root_zone_0_40_storage_cm"],float)
        cu=np.asarray(c["upper_0_80_storage_cm"],float)
        ct=np.asarray(c["theta_10cm"],float)
        ctot=np.asarray(c["total_storage_cm"],float)
        pools["surface_0_20_storage_error_cm"].append(cs-r["surface"])
        pools["root_zone_0_40_storage_error_cm"].append(cr-r["root"])
        pools["upper_0_80_storage_error_cm"].append(cu-r["upper"])
        pools["mapped_10cm_theta_error"].append((ct-r["theta"]).ravel())
        pools["total_storage_error_cm"].append(ctot-r["total"])
        timing=max(timing,extrema_timing(
          {"root":cr,"upper":cu},{"root":r["root"],"upper":r["upper"]}))
        signed.append(abs(float(np.mean(ctot-r["total"]))))
    out={k:rmse(np.concatenate(v)) for k,v in pools.items()}
    out["storage_extremum_timing_error_steps"]=int(timing)
    out["history_signed_storage_bias_cm"]=float(np.mean(signed))
    return out


def gw_metrics(candidate:dict,reference:dict)->dict[str,float|int]:
    pools={k:[] for k in (
      "cumulative_bottom_exchange_error_cm","interval_bottom_flux_error_cm_per_day",
      "total_storage_error_cm")}
    sign=0; seq=0; timing=0; bias=[]; drift=[]
    for h in GW_H:
        c=candidate[h]; r=reference["histories"][h]
        cc=np.asarray(c["cumulative_bottom_downward_cm"],float)
        cq=np.asarray(c["interval_average_bottom_downward_flux_cm_per_day"],float)
        cs=np.asarray(c["total_storage_cm"],float)
        pools["cumulative_bottom_exchange_error_cm"].append(cc-r["cum"])
        pools["interval_bottom_flux_error_cm_per_day"].append(cq-r["q"])
        pools["total_storage_error_cm"].append(cs-r["total"])
        sign+=int(np.count_nonzero(np.sign(cq)!=np.sign(r["q"])))
        ca=reversals(cq); ra=reversals(r["q"])
        if len(ca)!=len(ra):
            seq+=1; timing=max(timing,p1ref.NOBS)
        else:
            timing=max(timing,max([abs(x-y) for x,y in zip(ca,ra)] or [0]))
        bias.append(abs(float(np.mean(cq-r["q"]))))
        drift.append(abs(float((cc-r["cum"])[-1])))
    out={k:rmse(np.concatenate(v)) for k,v in pools.items()}
    out["bottom_flux_sign_mismatch_count"]=int(sign)
    out["reversal_sequence_mismatch_count"]=int(seq)
    out["reversal_timing_error_steps"]=int(timing)
    out["history_signed_bottom_flux_bias_cm_per_day"]=float(np.mean(bias))
    out["long_horizon_exchange_drift_cm"]=float(max(drift))
    return out


def reference_surface_metrics(a,b):
    pseudo={}
    for h in SURF_H:
        x=a["histories"][h]
        pseudo[h]={
          "surface_0_20_storage_cm":x["surface"].tolist(),
          "root_zone_0_40_storage_cm":x["root"].tolist(),
          "upper_0_80_storage_cm":x["upper"].tolist(),
          "theta_10cm":x["theta"].tolist(),
          "total_storage_cm":x["total"].tolist(),
        }
    return surface_metrics(pseudo,b)


def reference_gw_metrics(a,b):
    pseudo={}
    for h in GW_H:
        x=a["histories"][h]
        pseudo[h]={
          "cumulative_bottom_downward_cm":x["cum"].tolist(),
          "interval_average_bottom_downward_flux_cm_per_day":x["q"].tolist(),
          "total_storage_cm":x["total"].tolist(),
        }
    return gw_metrics(pseudo,b)


def componentwise_relation(a:dict,b:dict,tol:float):
    keys=tuple(a)
    if set(keys)!=set(b):
        raise ValueError("metric key drift")
    a_no_worse=all(float(a[k])<=float(b[k])+tol for k in keys)
    b_no_worse=all(float(b[k])<=float(a[k])+tol for k in keys)
    a_strict=any(float(a[k])<float(b[k])-tol for k in keys)
    b_strict=any(float(b[k])<float(a[k])-tol for k in keys)
    if a_no_worse and a_strict and not (b_no_worse and b_strict):
        decision="LEFT_COMPONENTWISE_NONINFERIOR"
    elif b_no_worse and b_strict and not (a_no_worse and a_strict):
        decision="RIGHT_COMPONENTWISE_NONINFERIOR"
    elif a_no_worse and b_no_worse:
        decision="COMPONENTWISE_EQUAL_WITHIN_TOLERANCE"
    else:
        decision="MIXED"
    return {
      "decision":decision,"left_no_worse":a_no_worse,"right_no_worse":b_no_worse,
      "left_strict":a_strict,"right_strict":b_strict,
      "left_minus_right":{k:float(a[k])-float(b[k]) for k in keys},
      "equality_tolerance":tol
    }


def crosses(candidate:dict,comparator:dict,tol:float):
    rel=componentwise_relation(candidate,comparator,tol)
    return bool(rel["left_no_worse"]),rel


def load_candidate(root:pathlib.Path,purpose:str,material:str,member:str):
    p=root/f"{purpose}_{material}_{member}.json"
    obj=json.loads(p.read_text())
    c=obj["candidate"]
    assert c["purpose"]==purpose and c["material"]==material and c["id"]==member
    assert obj["schema"]=="swap5.rom-purpose.p2.layer-candidate.v1"
    return c


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--p2-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--metric-contract",required=True,type=pathlib.Path)
    ap.add_argument("--p2-reference-result",required=True,type=pathlib.Path)
    ap.add_argument("--p1-reference-result",required=True,type=pathlib.Path)
    ap.add_argument("--surface-reference-root",required=True,type=pathlib.Path)
    ap.add_argument("--gw-reference-root",required=True,type=pathlib.Path)
    ap.add_argument("--candidate-root",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.p2_prereg.read_text())
    met=json.loads(a.metric_contract.read_text())
    p2rr=json.loads(a.p2_reference_result.read_text())
    p1rr=json.loads(a.p1_reference_result.read_text())

    assert pre["phase"]=="PREREGISTERED_BEFORE_ANY_P2_REFERENCE_OR_CANDIDATE_RESPONSE"
    assert met["status"]=="FROZEN_BEFORE_ANY_P1_REFERENCE_RESPONSE"
    contract_tol=float(met["placement_decision"]["componentwise_equality_tolerance"])
    assert contract_tol==CODE_TOL,(
        "componentwise equality tolerance drift",CODE_TOL,contract_tol)
    assert p2rr["status"]=="P2_REFERENCE_QUALIFIED_CANDIDATES_AUTHORIZED"
    assert p2rr["candidate_response_authorized"] is True
    assert p1rr["status"]=="P1_REFERENCE_NOT_QUALIFIED_STOP_BEFORE_CANDIDATES"
    assert p1rr["candidate_response_authorized"] is False
    assert all(p1rr["results"]["gw"][m]["qualified"] for m in ("B01","B14"))

    refs={"SURF_P":{},"GW_LB":{}}
    comparator={"SURF_P":{},"GW_LB":{}}
    for material in ("B01","B14"):
        target=p2ref.parse_surface(
            a.surface_reference_root/f"surface_{material}_R2048_T32_o0.txt","R2048_T32")
        r512=p2ref.parse_surface(
            a.surface_reference_root/f"surface_{material}_R512_T32_o0.txt","R512_T32")
        refs["SURF_P"][material]=target
        comparator["SURF_P"][material]=reference_surface_metrics(r512,target)

        target_gw=p1ref.parse_gw(
            a.gw_reference_root/f"gw_{material}_R2048_T32_o0.txt","R2048_T32")
        r512_gw=p1ref.parse_gw(
            a.gw_reference_root/f"gw_{material}_R512_T32_o0.txt","R512_T32")
        refs["GW_LB"][material]=target_gw
        comparator["GW_LB"][material]=reference_gw_metrics(r512_gw,target_gw)

    cases={}
    for purpose in ("SURF_P","GW_LB"):
        cases[purpose]={}
        for material in ("B01","B14"):
            cases[purpose][material]={}
            for member in MEMBERS:
                c=load_candidate(a.candidate_root,purpose,material,member)
                metrics=None; cross=False; cross_relation=None
                if c["status"]=="QUALIFIED" and c["histories"] is not None:
                    metrics=(surface_metrics(c["histories"],refs[purpose][material])
                             if purpose=="SURF_P"
                             else gw_metrics(c["histories"],refs[purpose][material]))
                    cross,cross_relation=crosses(
                        metrics,comparator[purpose][material],contract_tol)
                cases[purpose][material][member]={
                  "status":c["status"],"metrics":metrics,
                  "crosses_R512_T32_numerical_comparator":cross,
                  "comparator_relation":cross_relation,
                  "max_abs_water_ledger_cm":c["max_abs_water_ledger_cm"],
                  "failures":c["failures"],
                }

    placement={}
    aligned={"SURF_P":"S4","GW_LB":"G4"}
    opposite={"SURF_P":"G4","GW_LB":"S4"}
    any_supported=False
    closure_followup=[]
    for purpose in ("SURF_P","GW_LB"):
        placement[purpose]={}
        for material in ("B01","B14"):
            am=cases[purpose][material][aligned[purpose]]
            u=cases[purpose][material]["U4"]
            op=cases[purpose][material][opposite[purpose]]
            if am["metrics"] is None or u["metrics"] is None:
                primary={"decision":"PLACEMENT_UNRESOLVED_CANDIDATE_NOT_QUALIFIED"}
            else:
                rel=componentwise_relation(am["metrics"],u["metrics"],contract_tol)
                if rel["decision"]=="LEFT_COMPONENTWISE_NONINFERIOR":
                    decision="PLACEMENT_SUPPORTED"; any_supported=True
                elif rel["decision"]=="RIGHT_COMPONENTWISE_NONINFERIOR":
                    decision="UNIFORM_NONINFERIOR"
                elif rel["decision"]=="COMPONENTWISE_EQUAL_WITHIN_TOLERANCE":
                    decision="PLACEMENT_EQUAL_WITHIN_TOLERANCE"
                else:
                    decision="PLACEMENT_MIXED"
                primary={"decision":decision,"relation":rel}
            crossdiag=None
            if am["metrics"] is not None and op["metrics"] is not None:
                crossdiag=componentwise_relation(am["metrics"],op["metrics"],contract_tol)
            need_closure=(am["status"]=="QUALIFIED" and
                          not am["crosses_R512_T32_numerical_comparator"])
            if need_closure:
                closure_followup.append({
                    "purpose":purpose,"material":material,
                    "partition":aligned[purpose]})
            placement[purpose][material]={
              "aligned_partition":aligned[purpose],
              "uniform_partition":"U4",
              "opposite_partition":opposite[purpose],
              "primary":primary,
              "cross_purpose_diagnostic":crossdiag,
              "aligned_crosses_R512_T32_comparator":am["crosses_R512_T32_numerical_comparator"],
              "same_partition_corichards_diagnostic_required":need_closure
            }

    out={
      "schema":"swap5.rom-purpose.p2.placement-result.v1",
      "workstream":"ROM-PURPOSE","work_unit":"ROM-PURPOSE-P2-PLACEMENT",
      "reference_authority":p2rr["status"],
      "groundwater_reference_inherited_from_P1":True,
      "metric_contract":"integration/f-rom/ROM_PURPOSE_P1_METRIC_CONTRACT.json",
      "componentwise_equality_tolerance":contract_tol,
      "tolerance_guard_passed":True,
      "surface_histories":list(SURF_H),
      "groundwater_histories":list(GW_H),
      "numerical_comparator":{
        "route":"R512_T32","target":"R2048_T32","metrics":comparator},
      "cases":cases,
      "placement":placement,
      "hypotheses":{
        "H1_groundwater_aligned_placement_supported":all(
          placement["GW_LB"][m]["primary"]["decision"]=="PLACEMENT_SUPPORTED"
          for m in ("B01","B14")),
        "H2_surface_aligned_placement_supported":all(
          placement["SURF_P"][m]["primary"]["decision"]=="PLACEMENT_SUPPORTED"
          for m in ("B01","B14")),
        "H3_any_equal_dimension_purpose_aligned_information_value":any_supported,
        "H4_same_partition_corichards_diagnostic_required":bool(closure_followup)
      },
      "closure_followup":closure_followup,
      "application_authority_status":"REFERENCE_OR_APPLICATION_ENVELOPE_NOT_YET_AUTHORITATIVE",
      "scientific_firewall":{
        "weighted_score_used":False,
        "materials_aggregated_for_decision":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "production_rom_authorized":False,
        "P1_failure_overridden":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "H1":out["hypotheses"]["H1_groundwater_aligned_placement_supported"],
      "H2":out["hypotheses"]["H2_surface_aligned_placement_supported"],
      "H3":out["hypotheses"]["H3_any_equal_dimension_purpose_aligned_information_value"],
      "H4_followup_count":len(closure_followup),
      "placement":{
        p:{m:placement[p][m]["primary"]["decision"] for m in placement[p]}
        for p in placement}
    },sort_keys=True))


if __name__=="__main__":
    main()
