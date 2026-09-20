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

base=load_module("c5n_analysis_base_for_c5r",HERE/"analyze_lare_bc2_c5n_fresh_highres.py")

HISTS={"R01":0.72,"R02":0.82,"R03":0.88,"R04":0.76}
PARTITIONS={
  "D12_B10":[0.0,50.0,60.0,70.0,80.0,90.0,100.0,110.0,120.0,130.0,140.0,150.0,160.0],
  "D12_B5":[0.0,60.0,70.0,80.0,90.0,100.0,110.0,120.0,130.0,140.0,150.0,155.0,160.0],
  "D12_B2P5":[0.0,70.0,80.0,90.0,100.0,110.0,120.0,130.0,140.0,150.0,155.0,157.5,160.0],
  "D8_B2P5":[0.0,110.0,120.0,130.0,140.0,150.0,155.0,157.5,160.0],
}
CANDIDATES=("D12_B10","D12_B5","D12_B2P5","D8_B2P5")
CONTINUOUS_GW=(
  "total_storage_rmse_cm",
  "cumulative_bottom_rmse_cm",
  "interval_bottom_flux_rmse_cm_per_day",
  "mean_abs_history_signed_bottom_flux_error_cm_per_day",
  "max_abs_final_cumulative_bottom_error_cm",
)

base.HISTS=dict(HISTS)
base.bc.HISTORY_SE=dict(HISTS)
for name,bounds in PARTITIONS.items():
    base.bc.PARTITIONS[name]=np.diff(np.asarray(bounds,dtype=float))

def symbol(history,step):
    if history=="R01":
        if step<=224:return "BOTTOM_HEAD_FALL"
        if step<=576:return "BOTTOM_HEAD_RISE"
        return "HOLD"
    if history=="R02":
        if step<=224:return "BOTTOM_HEAD_RISE"
        if step<=576:return "BOTTOM_HEAD_FALL"
        return "HOLD"
    if history=="R03":
        if step<=320:return "BOTTOM_HEAD_FALL"
        if step<=576:return "BOTTOM_HEAD_RISE"
        return "HOLD"
    if history=="R04":
        if step<=320:return "BOTTOM_HEAD_RISE"
        if step<=576:return "BOTTOM_HEAD_FALL"
        return "HOLD"
    raise ValueError(history)

base.bc.symbol=symbol

def strict_any(a,b,keys):
    return any(float(a[k]) < float(b[k])-base.EQ_TOL for k in keys)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--r1024-t16",required=True,type=pathlib.Path)
    ap.add_argument("--r2048-t16",required=True,type=pathlib.Path)
    ap.add_argument("--r2048-t8",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--c5q",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    p=json.loads(a.prereg.read_text())
    q=json.loads(a.c5q.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_C5R_FRESH_REFERENCE_OR_LARE_RESPONSE"
    assert p["implementation_binding"]["state"]=="BOUND_BEFORE_EXECUTION"
    assert p["representations"]["no_response_based_repartitioning"] is True
    assert q["decision"]=="PREREGISTER_D12_SHARED_BOTTOM_SUPPORT_BREADTH_DISCRIMINATOR_BEFORE_CLOSURE_IMPLEMENTATION"

    r1024=base.parse_reference(a.r1024_t16,16)
    r2048=base.parse_reference(a.r2048_t16,16)
    r2048t8=base.parse_reference(a.r2048_t8,8)
    spatial=base.compare_routes(r1024,r2048)
    temporal=base.compare_routes(r2048t8,r2048)
    reference_quality={
      "temporal_no_worse_than_R1024_GW":base.no_worse(temporal,spatial,base.GW_KEYS),
      "temporal_no_worse_than_R1024_PROFILE":base.no_worse(temporal,spatial,base.PROFILE_KEYS),
    }
    reference_quality["R1024_frontier_interpretable"]=all(reference_quality.values())

    if not reference_quality["R1024_frontier_interpretable"]:
        out={
          "schema":"swap5.lare.bc2.c5r.result.v1",
          "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5R",
          "blind_validation":True,
          "status":"C5R_REFERENCE_OR_EXECUTION_BLOCKED",
          "reference_comparators":{"R1024_vs_R2048":spatial,"R2048_T8_vs_T16":temporal},
          "reference_quality":reference_quality,
          "members":[],
          "scientific_firewall":{
            "candidate_response_generated":False,
            "new_closure_fit":False,
            "response_based_repartitioning":False,
            "application_acceptance_adjudicated":False,
            "performance_comparison_authorized":False,
            "speed_claim_authorized":False,
            "production_rom_authorized":False
          }
        }
        a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
        print(json.dumps({"status":out["status"],"reference_quality":reference_quality},sort_keys=True))
        return

    members=[base.run_member(mid,PARTITIONS[mid],r2048) for mid in CANDIDATES]
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
        aa=byid[aid]["metrics"];bb=byid[bid]["metrics"]
        return {
          "componentwise_no_worse_GW":base.no_worse(aa,bb,base.GW_KEYS),
          "reverse_componentwise_no_worse_GW":base.no_worse(bb,aa,base.GW_KEYS),
          "componentwise_no_worse_PROFILE":base.no_worse(aa,bb,base.PROFILE_KEYS),
          "strict_any_continuous_GW_improvement":strict_any(aa,bb,CONTINUOUS_GW),
          "flux_rmse_ratio":float(aa["interval_bottom_flux_rmse_cm_per_day"])/float(bb["interval_bottom_flux_rmse_cm_per_day"]),
          "storage_rmse_ratio":float(aa["total_storage_rmse_cm"])/float(bb["total_storage_rmse_cm"]),
          "cumulative_rmse_ratio":float(aa["cumulative_bottom_rmse_cm"])/float(bb["cumulative_bottom_rmse_cm"]),
          "signed_history_bias_ratio":float(aa["mean_abs_history_signed_bottom_flux_error_cm_per_day"])/float(bb["mean_abs_history_signed_bottom_flux_error_cm_per_day"]),
          "mapped_theta_rmse_ratio":float(aa["mapped_theta_rmse"])/float(bb["mapped_theta_rmse"]),
          "sign_mismatch_delta":int(aa["bottom_flux_sign_mismatch_count"])-int(bb["bottom_flux_sign_mismatch_count"]),
          "reversal_penalty_delta":int(aa["reversal_penalty_steps"])-int(bb["reversal_penalty_steps"]),
        }

    comparisons={
      "D12_B5_vs_B10":cmp("D12_B5","D12_B10"),
      "D12_B2P5_vs_B5":cmp("D12_B2P5","D12_B5"),
      "D12_B2P5_vs_B10":cmp("D12_B2P5","D12_B10"),
      "D12_B2P5_vs_D8_B2P5":cmp("D12_B2P5","D8_B2P5"),
    }
    breadth=comparisons["D12_B2P5_vs_D8_B2P5"]
    d12=byid["D12_B2P5"]["metrics"];d8=byid["D8_B2P5"]["metrics"]
    d12_dyadic=(comparisons["D12_B5_vs_B10"]["componentwise_no_worse_GW"] and
                 comparisons["D12_B2P5_vs_B5"]["componentwise_no_worse_GW"])
    breadth_active=(breadth["componentwise_no_worse_GW"] and breadth["strict_any_continuous_GW_improvement"])
    profile_at_least_as_informative=float(d12["mapped_theta_rmse"])<=float(d8["mapped_theta_rmse"])+base.EQ_TOL
    propagation_strengthened=(breadth["reverse_componentwise_no_worse_GW"] and
                              profile_at_least_as_informative and not breadth_active)
    highres=crossings.get("D12_B2P5",{}).get("R1024_GW") is True

    if not integrity:
        status="C5R_REFERENCE_OR_EXECUTION_BLOCKED"
    elif highres:
        status="C5R_D12_BOTTOM_FOCUS_REACHES_HIGH_RES_GW_FRONTIER"
    elif breadth_active:
        status="C5R_VERTICAL_MEMORY_BREADTH_ACTIVE"
    elif propagation_strengthened:
        status="C5R_PROPAGATION_LIMIT_STRENGTHENED"
    else:
        status="C5R_BREADTH_PROPAGATION_MIXED"

    out={
      "schema":"swap5.lare.bc2.c5r.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5R",
      "blind_validation":True,
      "material":"B14",
      "status":status,
      "reference_comparators":{"R1024_vs_R2048":spatial,"R2048_T8_vs_T16":temporal},
      "reference_quality":reference_quality,
      "members":members,
      "crossings":crossings,
      "comparisons":comparisons,
      "hypotheses":{
        "H_D12_DYADIC_BOTTOM_PROGRESS":d12_dyadic,
        "H_BREADTH_ACTIVE":breadth_active,
        "H_PROPAGATION_LIMIT_STRENGTHENED":propagation_strengthened,
        "H_D12_B2P5_CROSSES_R1024_GW":highres,
        "D12_B2P5_PROFILE_AT_LEAST_AS_INFORMATIVE_AS_D8_B2P5":profile_at_least_as_informative
      },
      "integrity":{
        "all_candidates_attempted":len(members)==len(CANDIDATES),
        "all_candidates_qualified":len(qualified)==len(CANDIDATES),
        "maximum_qualified_lare_water_ledger_cm":max([x["max_abs_water_ledger_cm"] for x in qualified] or [0.0]),
        "pass":integrity
      },
      "interpretation_boundaries":[
        "D12 versus D8 at B2P5 isolates added vertical memory breadth while retaining identical 5/2.5/2.5-cm bottom support and unchanged CURRENT_LAYER_FACE closure.",
        "A D12 improvement keeps representation breadth causally active; it does not establish an optimal D12 partition.",
        "A propagation-limit outcome strengthens but does not itself implement or validate a new closure.",
        "R1024 crossing is comparator-relative numerical evidence, not application acceptance or continuum truth.",
        "No scalar score, response-based partition optimization, performance, speed or production claim is authorized."
      ],
      "scientific_firewall":{
        "candidate_response_generated":True,
        "C5N_result_changed":False,
        "C5P_result_changed":False,
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
      "reference_quality":reference_quality,
      "crossings":crossings,
      "comparisons":comparisons,
      "hypotheses":out["hypotheses"],
      "integrity":out["integrity"]
    },sort_keys=True))

if __name__=="__main__":
    main()
