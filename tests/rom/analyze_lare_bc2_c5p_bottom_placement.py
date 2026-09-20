#!/usr/bin/env python3
from __future__ import annotations
import argparse, importlib.util, json, pathlib, sys
import numpy as np

HERE=pathlib.Path(__file__).resolve().parent

def load_module(name,path):
    spec=importlib.util.spec_from_file_location(name,str(path))
    mod=importlib.util.module_from_spec(spec)
    sys.modules[name]=mod
    spec.loader.exec_module(mod)
    return mod

base=load_module("c5n_analysis_base",HERE/"analyze_lare_bc2_c5n_fresh_highres.py")

HISTS={"P01":0.68,"P02":0.78,"P03":0.86,"P04":0.92}
PARTITIONS={
  "D4_B10":[0.0,130.0,140.0,150.0,160.0],
  "D4_B5":[0.0,140.0,150.0,155.0,160.0],
  "D4_B2P5":[0.0,150.0,155.0,157.5,160.0],
  "D8_B10":[0.0,90.0,100.0,110.0,120.0,130.0,140.0,150.0,160.0],
  "D8_B5":[0.0,100.0,110.0,120.0,130.0,140.0,150.0,155.0,160.0],
  "D8_B2P5":[0.0,110.0,120.0,130.0,140.0,150.0,155.0,157.5,160.0],
}
CANDIDATES=("D4_B10","D4_B5","D4_B2P5","D8_B10","D8_B5","D8_B2P5")
FOCUSED=("D4_B5","D4_B2P5","D8_B5","D8_B2P5")

base.HISTS=dict(HISTS)
base.bc.HISTORY_SE=dict(HISTS)
for name,bounds in PARTITIONS.items():
    base.bc.PARTITIONS[name]=np.diff(np.asarray(bounds,dtype=float))

def symbol(history,step):
    if history=="P01":
        if step<=192:return "BOTTOM_HEAD_FALL"
        if step<=576:return "BOTTOM_HEAD_RISE"
        return "HOLD"
    if history=="P02":
        if step<=192:return "BOTTOM_HEAD_RISE"
        if step<=576:return "BOTTOM_HEAD_FALL"
        return "HOLD"
    if history=="P03":
        if step<=272:return "BOTTOM_HEAD_FALL"
        if step<=576:return "BOTTOM_HEAD_RISE"
        return "HOLD"
    if history=="P04":
        if step<=304:return "BOTTOM_HEAD_RISE"
        if step<=576:return "BOTTOM_HEAD_FALL"
        return "HOLD"
    raise ValueError(history)

base.bc.symbol=symbol

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r1024-t16",required=True,type=pathlib.Path)
    ap.add_argument("--r2048-t16",required=True,type=pathlib.Path)
    ap.add_argument("--r2048-t8",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c5o",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    o=json.loads(a.c5o.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C5P_FRESH_REFERENCE_OR_LARE_RESPONSE"
    assert p["implementation_binding"]["state"]=="BOUND_BEFORE_EXECUTION"
    assert p["representations"]["no_response_based_repartitioning"] is True
    assert o["decision"]=="TEST_BOTTOM_ADJACENT_STATE_PLACEMENT_AT_FIXED_DIMENSION_BEFORE_NEW_CLOSURE_FAMILY"

    r1024=base.parse_reference(a.r1024_t16,16)
    r2048=base.parse_reference(a.r2048_t16,16)
    r2048t8=base.parse_reference(a.r2048_t8,8)
    spatial=base.compare_routes(r1024,r2048)
    temporal=base.compare_routes(r2048t8,r2048)
    ref_quality={
      "temporal_no_worse_than_R1024_GW":base.no_worse(temporal,spatial,base.GW_KEYS),
      "temporal_no_worse_than_R1024_PROFILE":base.no_worse(temporal,spatial,base.PROFILE_KEYS),
    }
    ref_quality["R1024_frontier_interpretable"]=all(ref_quality.values())

    if not ref_quality["R1024_frontier_interpretable"]:
        out={
          "schema":"swap5.lare.bc2.c5p.result.v1",
          "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5P",
          "blind_validation":True,
          "status":"C5P_REFERENCE_OR_EXECUTION_BLOCKED",
          "reference_comparators":{"R1024_vs_R2048":spatial,"R2048_T8_vs_T16":temporal},
          "reference_quality":ref_quality,
          "members":[],
          "scientific_firewall":{
            "candidate_response_generated":False,
            "C5N_result_changed":False,
            "production_reference_changed":False,
            "new_closure_fit":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
            "speed_claim_authorized":False,
            "production_rom_authorized":False
          }
        }
        a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
        print(json.dumps({"status":out["status"],"reference_quality":ref_quality},sort_keys=True))
        return

    members=[]
    for mid in CANDIDATES:
        members.append(base.run_member(mid,PARTITIONS[mid],r2048))
    byid={x["id"]:x for x in members}
    qualified=[x for x in members if x["status"]=="QUALIFIED"]
    integrity=(len(members)==len(CANDIDATES) and len(qualified)==len(CANDIDATES) and
               max([x["max_abs_water_ledger_cm"] for x in qualified] or [0.0])<=base.LEDGER_GATE)

    crossings={}
    for x in qualified:
        m=x["metrics"]
        crossings[x["id"]]={
          "R1024_GW":base.no_worse(m,spatial,base.GW_KEYS),
          "R1024_PROFILE":base.no_worse(m,spatial,base.PROFILE_KEYS),
          "TEMPORAL_FLOOR_GW":base.no_worse(m,temporal,base.GW_KEYS),
          "TEMPORAL_FLOOR_PROFILE":base.no_worse(m,temporal,base.PROFILE_KEYS),
        }

    def cmp(aid,bid):
        arow=byid[aid]["metrics"];brow=byid[bid]["metrics"]
        return {
          "componentwise_no_worse_GW":base.no_worse(arow,brow,base.GW_KEYS),
          "componentwise_no_worse_PROFILE":base.no_worse(arow,brow,base.PROFILE_KEYS),
          "flux_rmse_ratio":float(arow["interval_bottom_flux_rmse_cm_per_day"])/float(brow["interval_bottom_flux_rmse_cm_per_day"]),
          "storage_rmse_ratio":float(arow["total_storage_rmse_cm"])/float(brow["total_storage_rmse_cm"]),
          "cumulative_rmse_ratio":float(arow["cumulative_bottom_rmse_cm"])/float(brow["cumulative_bottom_rmse_cm"]),
          "signed_history_bias_ratio":float(arow["mean_abs_history_signed_bottom_flux_error_cm_per_day"])/float(brow["mean_abs_history_signed_bottom_flux_error_cm_per_day"]),
          "mapped_theta_rmse_ratio":float(arow["mapped_theta_rmse"])/float(brow["mapped_theta_rmse"]),
          "strict_flux_improvement":float(arow["interval_bottom_flux_rmse_cm_per_day"]) < float(brow["interval_bottom_flux_rmse_cm_per_day"])-base.EQ_TOL,
        }

    comparisons={
      "D4_B5_vs_B10":cmp("D4_B5","D4_B10"),
      "D4_B2P5_vs_B5":cmp("D4_B2P5","D4_B5"),
      "D4_B2P5_vs_B10":cmp("D4_B2P5","D4_B10"),
      "D8_B5_vs_B10":cmp("D8_B5","D8_B10"),
      "D8_B2P5_vs_B5":cmp("D8_B2P5","D8_B5"),
      "D8_B2P5_vs_B10":cmp("D8_B2P5","D8_B10"),
    }

    d4_improve=any(
      comparisons[k]["componentwise_no_worse_GW"] and comparisons[k]["strict_flux_improvement"]
      for k in ("D4_B5_vs_B10","D4_B2P5_vs_B10")
    )
    d8_improve=any(
      comparisons[k]["componentwise_no_worse_GW"] and comparisons[k]["strict_flux_improvement"]
      for k in ("D8_B5_vs_B10","D8_B2P5_vs_B10")
    )
    d4_dyadic=(comparisons["D4_B5_vs_B10"]["componentwise_no_worse_GW"] and
               comparisons["D4_B2P5_vs_B5"]["componentwise_no_worse_GW"])
    d8_dyadic=(comparisons["D8_B5_vs_B10"]["componentwise_no_worse_GW"] and
               comparisons["D8_B2P5_vs_B5"]["componentwise_no_worse_GW"])
    focused_cross=[mid for mid in FOCUSED if crossings.get(mid,{}).get("R1024_GW") is True]
    focused_profile=[mid for mid in FOCUSED if crossings.get(mid,{}).get("R1024_PROFILE") is True]

    if not integrity:
        status="C5P_REFERENCE_OR_EXECUTION_BLOCKED"
    elif focused_cross:
        status="C5P_BOTTOM_FOCUS_RESCUES_HIGH_RES_GW_FRONTIER"
    elif d4_improve or d8_improve:
        status="C5P_BOTTOM_FOCUS_IMPROVES_BUT_NO_HIGH_RES_FRONTIER"
    else:
        status="C5P_BOTTOM_FOCUS_NO_IMPROVEMENT_CLOSURE_RECONCILIATION_REQUIRED"

    out={
      "schema":"swap5.lare.bc2.c5p.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5P",
      "blind_validation":True,
      "material":"B14",
      "status":status,
      "reference_comparators":{"R1024_vs_R2048":spatial,"R2048_T8_vs_T16":temporal},
      "reference_quality":ref_quality,
      "members":members,
      "crossings":crossings,
      "fixed_dimension_comparisons":comparisons,
      "frontiers":{
        "R1024_GW":[mid for mid in CANDIDATES if crossings.get(mid,{}).get("R1024_GW")],
        "R1024_PROFILE":[mid for mid in CANDIDATES if crossings.get(mid,{}).get("R1024_PROFILE")],
        "TEMPORAL_FLOOR_GW":[mid for mid in CANDIDATES if crossings.get(mid,{}).get("TEMPORAL_FLOOR_GW")],
        "TEMPORAL_FLOOR_PROFILE":[mid for mid in CANDIDATES if crossings.get(mid,{}).get("TEMPORAL_FLOOR_PROFILE")],
        "focused_R1024_GW":focused_cross,
        "focused_R1024_PROFILE":focused_profile
      },
      "hypotheses":{
        "H_D4_BOTTOM_FOCUS_IMPROVES":d4_improve,
        "H_D8_BOTTOM_FOCUS_IMPROVES":d8_improve,
        "H_D4_DYADIC_PROGRESS":d4_dyadic,
        "H_D8_DYADIC_PROGRESS":d8_dyadic,
        "H_ANY_FOCUSED_MEMBER_CROSSES_R1024_GW":bool(focused_cross)
      },
      "integrity":{
        "all_candidates_attempted":len(members)==len(CANDIDATES),
        "all_candidates_qualified":len(qualified)==len(CANDIDATES),
        "maximum_qualified_lare_water_ledger_cm":max([x["max_abs_water_ledger_cm"] for x in qualified] or [0.0]),
        "pass":integrity
      },
      "interpretation_boundaries":[
        "C5P changes state placement at fixed D4 or D8 dimension; it does not fit a new closure.",
        "The 10, 5 and 2.5 cm bottom-support levels are prospectively transferred diagnostic coordinates from C5C, not C5P-response-optimized partitions.",
        "R1024 crossing is high-resolution comparator-relative evidence, not application acceptance or continuum equivalence.",
        "Groundwater and mapped-profile views are reported separately; bottom-focused groundwater improvement may trade profile fidelity.",
        "No universal minimum state count or optimal partition is inferred from this experiment.",
        "No performance, speed or production claim is authorized."
      ],
      "scientific_firewall":{
        "candidate_response_generated":True,
        "C5A_formal_decision_changed":False,
        "C5N_result_changed":False,
        "production_reference_changed":False,
        "new_closure_fit":False,
        "response_based_repartitioning":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "status":status,
      "reference_quality":ref_quality,
      "frontiers":out["frontiers"],
      "hypotheses":out["hypotheses"],
      "comparisons":comparisons,
      "integrity":out["integrity"]
    },sort_keys=True))

if __name__=="__main__":
    main()
