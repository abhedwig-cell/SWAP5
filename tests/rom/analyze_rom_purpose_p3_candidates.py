#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib
import sys

HERE=pathlib.Path(__file__).resolve().parent
TOL=1.0e-12
SURF_H=("S09","S10","S11","S12")
GW_H=("G06","G07","G08","G09")
ALIGNED={
    "SURF_P":("S4","S6","S8"),
    "GW_LB":("G4","G6","G8"),
}
UNIFORM={4:"U4",6:"U6",8:"U8"}


def load_module(name:str,path:pathlib.Path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod


base=load_module("rom_purpose_p3_p2_candidate_analysis",HERE/"analyze_rom_purpose_p2_candidates.py")
base.SURF_H=SURF_H
base.GW_H=GW_H
base.p2ref.SURF_H=SURF_H
base.p1ref.GW_H=GW_H


def load_candidate(root:pathlib.Path,purpose:str,material:str,member:str)->dict:
    path=root/f"{purpose}_{material}_{member}.json"
    obj=json.loads(path.read_text())
    assert obj["schema"]=="swap5.rom-purpose.p3.layer-candidate.v1"
    cand=obj["candidate"]
    assert cand["purpose"]==purpose
    assert cand["material"]==material
    assert cand["id"]==member
    return cand


def candidate_metrics(purpose:str,cand:dict,ref:dict)->dict|None:
    if cand["status"]!="QUALIFIED" or cand["histories"] is None:
        return None
    if purpose=="SURF_P":
        return base.surface_metrics(cand["histories"],ref)
    return base.gw_metrics(cand["histories"],ref)


def reference_bundle(root:pathlib.Path)->tuple[dict,dict]:
    refs={"SURF_P":{},"GW_LB":{}}
    comps={"SURF_P":{},"GW_LB":{}}
    for material in ("B01","B14"):
        s2048=base.p2ref.parse_surface(root/f"surface_{material}_R2048_T32_o0.txt","R2048_T32")
        s512=base.p2ref.parse_surface(root/f"surface_{material}_R512_T32_o0.txt","R512_T32")
        refs["SURF_P"][material]=s2048
        comps["SURF_P"][material]=base.reference_surface_metrics(s512,s2048)

        g2048=base.p1ref.parse_gw(root/f"gw_{material}_R2048_T32_o0.txt","R2048_T32")
        g512=base.p1ref.parse_gw(root/f"gw_{material}_R512_T32_o0.txt","R512_T32")
        refs["GW_LB"][material]=g2048
        comps["GW_LB"][material]=base.reference_gw_metrics(g512,g2048)
    return refs,comps


def classify_case(metrics:dict|None,status:str,comparator:dict)->tuple[str,dict|None]:
    if status!="QUALIFIED" or metrics is None:
        return "CANDIDATE_NOT_NUMERICALLY_QUALIFIED",None
    crosses,relation=base.crosses(metrics,comparator,TOL)
    return ("REPRESENTATION_COMPARATOR_REACHED" if crosses
            else "BELOW_NUMERICAL_COMPARATOR"),relation


def ref_uncertainty_map(p3ref:dict,purpose:str,material:str)->dict[str,float]:
    if purpose=="SURF_P":
        src=p3ref["fresh_reference"]["SURF_P"][material]["metrics"]
        names={
          "surface_0_20_storage_error_cm":"surface_0_20_storage_rmse_cm",
          "root_zone_0_40_storage_error_cm":"root_0_40_storage_rmse_cm",
          "upper_0_80_storage_error_cm":"upper_0_80_storage_rmse_cm",
          "mapped_10cm_theta_error":"mapped_10cm_theta_rmse",
          "total_storage_error_cm":"total_storage_rmse_cm",
        }
    else:
        src=p3ref["fresh_reference"]["GW_LB"][material]["metrics"]
        names={
          "cumulative_bottom_exchange_error_cm":"cumulative_bottom_rmse_cm",
          "interval_bottom_flux_error_cm_per_day":"interval_bottom_flux_rmse_cm_per_day",
          "total_storage_error_cm":"total_storage_rmse_cm",
        }
    out={}
    for dst,source in names.items():
        rec=src.get(source)
        if rec and rec.get("qualified") and rec.get("combined_reference_uncertainty") is not None:
            out[dst]=float(rec["combined_reference_uncertainty"])
    return out


def stability(lower:dict,upper:dict,unc:dict)->dict:
    discrete_keys={
      "bottom_flux_sign_mismatch_count",
      "reversal_sequence_mismatch_count",
      "reversal_timing_error_steps",
      "storage_extremum_timing_error_steps",
    }
    continuous=[k for k in lower if k not in discrete_keys]
    missing=[k for k in continuous if k not in unc]
    if missing:
        return {
          "classification":"FRONTIER_STABILITY_UNAVAILABLE_MISSING_REFERENCE_UNCERTAINTY",
          "stable":False,
          "missing_uncertainty_metrics":missing
        }
    cont={}
    stable=True
    for k in continuous:
        bound=max(TOL,float(unc[k]))
        delta=abs(float(upper[k])-float(lower[k]))
        ok=delta<=bound
        cont[k]={"delta":delta,"bound":bound,"stable":ok}
        stable=stable and ok
    discrete={}
    for k in discrete_keys.intersection(lower):
        ok=int(lower[k])==int(upper[k])
        discrete[k]={"lower":int(lower[k]),"upper":int(upper[k]),"stable":ok}
        stable=stable and ok
    return {
      "classification":("REPRESENTATION_FRONTIER_STABLE"
                        if stable else "REPRESENTATION_FRONTIER_NOT_STABLE"),
      "stable":bool(stable),
      "continuous":cont,
      "discrete":discrete,
      "missing_uncertainty_metrics":[]
    }


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--p3-prereg",required=True,type=pathlib.Path)
    ap.add_argument("--metric-contract",required=True,type=pathlib.Path)
    ap.add_argument("--p3-reference-result",required=True,type=pathlib.Path)
    ap.add_argument("--reference-root",required=True,type=pathlib.Path)
    ap.add_argument("--candidate-root",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.p3_prereg.read_text())
    met=json.loads(a.metric_contract.read_text())
    p3ref=json.loads(a.p3_reference_result.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_ANY_NEW_P3_REFERENCE_OR_CANDIDATE_RESPONSE"
    assert p3ref["status"]=="P3_REFERENCE_QUALIFIED_CANDIDATES_AUTHORIZED"
    assert p3ref["candidate_response_authorized"] is True
    assert float(met["placement_decision"]["componentwise_equality_tolerance"])==TOL
    assert float(pre["representation_sufficiency"]["equality_tolerance"])==TOL

    refs,comparators=reference_bundle(a.reference_root)
    cases={}
    decisions={}
    diagnostics=[]
    purpose_summary={}

    for purpose in ("SURF_P","GW_LB"):
        cases[purpose]={}
        decisions[purpose]={}
        aligned=ALIGNED[purpose]
        for material in ("B01","B14"):
            cases[purpose][material]={}
            decisions[purpose][material]={}
            for member in tuple(aligned)+tuple(UNIFORM[d] for d in (4,6,8)):
                if member in cases[purpose][material]:
                    continue
                cand=load_candidate(a.candidate_root,purpose,material,member)
                metrics=candidate_metrics(purpose,cand,refs[purpose][material])
                cls,relation=classify_case(metrics,cand["status"],comparators[purpose][material])
                cases[purpose][material][member]={
                  "status":cand["status"],
                  "dimension":int(cand["dimension"]),
                  "boundaries_cm":cand["boundaries_cm"],
                  "metrics":metrics,
                  "representation_sufficiency":cls,
                  "comparator_relation":relation,
                  "max_abs_water_ledger_cm":cand["max_abs_water_ledger_cm"],
                  "failures":cand["failures"]
                }

            rung_decisions=[]
            minimum=None
            for member in aligned:
                dim=int(member[1:])
                rec=cases[purpose][material][member]
                u=cases[purpose][material][UNIFORM[dim]]
                uniform_relation=None
                if rec["metrics"] is not None and u["metrics"] is not None:
                    uniform_relation=base.componentwise_relation(rec["metrics"],u["metrics"],TOL)
                rung_decisions.append({
                  "member":member,
                  "dimension":dim,
                  "classification":rec["representation_sufficiency"],
                  "uniform_comparator":UNIFORM[dim],
                  "aligned_vs_uniform":uniform_relation
                })
                if minimum is None and rec["representation_sufficiency"]=="REPRESENTATION_COMPARATOR_REACHED":
                    minimum=member

            if minimum is None:
                min_status="REPRESENTATION_FRONTIER_NOT_REACHED"
                min_dim=None
                min_bounds=None
            else:
                min_status="MINIMUM_TESTED_REPRESENTATION_IDENTIFIED"
                min_dim=int(minimum[1:])
                min_bounds=cases[purpose][material][minimum]["boundaries_cm"]

            stable_diag=None
            if minimum is not None:
                idx=aligned.index(minimum)
                if idx+1<len(aligned):
                    upper=aligned[idx+1]
                    if cases[purpose][material][upper]["representation_sufficiency"]=="REPRESENTATION_COMPARATOR_REACHED":
                        stable_diag=stability(
                          cases[purpose][material][minimum]["metrics"],
                          cases[purpose][material][upper]["metrics"],
                          ref_uncertainty_map(p3ref,purpose,material))
                    else:
                        stable_diag={
                          "classification":"FRONTIER_STABILITY_NOT_TESTABLE_HIGHER_RUNG_DOES_NOT_REACH_COMPARATOR",
                          "stable":False,
                          "higher_rung":upper
                        }
                else:
                    stable_diag={
                      "classification":"FRONTIER_STABILITY_NOT_TESTABLE_NO_HIGHER_FROZEN_RUNG",
                      "stable":False
                    }

            terminal=aligned[-1]
            terminal_rec=cases[purpose][material][terminal]
            if minimum is None and terminal_rec["status"]=="QUALIFIED" and terminal_rec["representation_sufficiency"]=="BELOW_NUMERICAL_COMPARATOR":
                diag="SAME_PARTITION_RICHARDS_DIAGNOSTIC_REQUIRED"
                diagnostics.append({
                  "purpose":purpose,"material":material,
                  "member":terminal,
                  "boundaries_cm":terminal_rec["boundaries_cm"]
                })
            elif minimum is not None:
                diag="NO_CLOSURE_DIAGNOSTIC_REQUIRED"
            else:
                diag="SAME_PARTITION_RICHARDS_DIAGNOSTIC_UNAVAILABLE_PENDING_NUMERICAL_CANDIDATE_QUALIFICATION"

            decisions[purpose][material]={
              "rungs":rung_decisions,
              "minimum_tested_member":minimum,
              "minimum_tested_state_count":min_dim,
              "minimum_tested_state_placement_cm":min_bounds,
              "representation_frontier_status":min_status,
              "frontier_stability":stable_diag,
              "closure_diagnostic_disposition":diag
            }

        mins=[decisions[purpose][m]["minimum_tested_state_count"] for m in ("B01","B14")]
        if all(x is not None for x in mins):
            purpose_summary[purpose]={
              "status":"PURPOSE_SPECIFIC_FINITE_REPRESENTATION_FRONTIER_SUPPORTED",
              "both_materials_reach_comparator":True,
              "maximum_minimum_tested_state_count_across_materials":max(mins),
              "material_minima":{m:decisions[purpose][m]["minimum_tested_state_count"] for m in ("B01","B14")}
            }
        else:
            purpose_summary[purpose]={
              "status":"REPRESENTATION_DIMENSION_REMAINS_LIMITING",
              "both_materials_reach_comparator":False,
              "material_minima":{m:decisions[purpose][m]["minimum_tested_state_count"] for m in ("B01","B14")}
            }

    out={
      "schema":"swap5.rom-purpose.p3.state-count-result.v1",
      "workstream":"ROM-PURPOSE",
      "work_unit":"ROM-PURPOSE-P3-STATE-COUNT",
      "reference_status":p3ref["status"],
      "metric_contract":"integration/f-rom/ROM_PURPOSE_P1_METRIC_CONTRACT.json",
      "componentwise_equality_tolerance":TOL,
      "cases":cases,
      "decisions":decisions,
      "purpose_summary":purpose_summary,
      "same_partition_richards_triggers":diagnostics,
      "closure_workstream_authorized":False,
      "scientific_firewall":{
        "weighted_score_used":False,
        "materials_aggregated_for_primary_admission":False,
        "state_boundaries_changed_after_response":False,
        "closure_changed":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "purpose_summary":purpose_summary,
      "same_partition_richards_trigger_count":len(diagnostics),
      "material_minima":{
        p:{m:decisions[p][m]["minimum_tested_state_count"] for m in decisions[p]}
        for p in decisions
      }
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
