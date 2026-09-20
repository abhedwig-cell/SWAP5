#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib
from collections import Counter

MATERIALS=("B02","B05","B06","B11","B12","B16")
CORE=("storage_rmse_cm","cumulative_bottom_rmse_cm","qavg_rmse_cm_per_day","qend_rmse_cm_per_day","mapped_theta_rmse")
FINE="0.00002500"
COARSE="0.00010000"


def find_result(root:pathlib.Path,material:str)->pathlib.Path:
    matches=list(root.rglob(f"LAYER_ROM_B1HCG_{material}_RESULT.json"))
    if len(matches)!=1:
        raise RuntimeError(f"expected one result for {material}, found {len(matches)}")
    return matches[0]


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_TEMPORAL_REFINEMENT_RESULTS":
        raise SystemExit("wrong B1HCG preregistration")
    tol=float(pre["hard_controls"]["relation_tolerance"])
    rows={m:json.loads(find_result(a.input_dir,m).read_text()) for m in MATERIALS}
    for m,r in rows.items():
        if r["material"]!=m or r["decision"]!="B1HCG_MATERIAL_TEMPORAL_LADDER_CHARACTERIZED":
            raise SystemExit(f"material result mismatch {m}")
        if not r["integrity"]["pass"]:
            raise SystemExit(f"material integrity failed {m}")

    signatures={m:bool(rows[m]["R16_OP_material_temporal_signature"]) for m in MATERIALS}
    all_signature=all(signatures.values())
    finest_identity={}
    for m in MATERIALS:
        day=rows[m]["temporal_monotonicity"]["R16_OP"]["day1"]
        finest_identity[m]=all(float(day[k]["values"][FINE])<=tol for k in CORE)
    all_identity=all(finest_identity.values())

    labels=pre["adjudication"]["decision_labels"]
    if all_signature and all_identity:
        decision=labels["all_materials_and_finest_core_numerical_identity"]
    elif all_signature:
        decision=labels["all_materials_but_finest_core_residual_remains"]
    else:
        decision=labels["mixed_material_or_component_signature"]

    monotone_counts={"R16_OP":{},"R8":{}}
    allcp_counts={"R16_OP":{},"R8":{}}
    for rid in ("R16_OP","R8"):
        for key in pre["full_response_vector"]:
            monotone_counts[rid][key]=sum(
                bool(rows[m]["temporal_monotonicity"][rid]["day1"][key]["nonincreasing"])
                for m in MATERIALS
            )
            allcp_counts[rid][key]=sum(
                bool(rows[m]["temporal_monotonicity"][rid]["all_checkpoints"][key])
                for m in MATERIALS
            )

    core_reduction={}
    for m in MATERIALS:
        core_reduction[m]={}
        day=rows[m]["temporal_monotonicity"]["R16_OP"]["day1"]
        for key in CORE:
            e0=float(day[key]["values"][COARSE]);ef=float(day[key]["values"][FINE])
            core_reduction[m][key]={
                "coarse":e0,
                "fine":ef,
                "fine_over_coarse":None if e0==0.0 else ef/e0,
                "absolute_reduction":e0-ef
            }

    r8_vs_r16_counts={"GW":Counter(),"PROFILE":Counter()}
    for m in MATERIALS:
        for group in ("GW","PROFILE"):
            r8_vs_r16_counts[group][rows[m]["finest_dt_R8_vs_R16_OP"][group]["vector_relation"]]+=1

    result={
        "schema":"swap5.layer-rom.phase-b1hcg.aggregate-result.v1",
        "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCG",
        "decision":decision,
        "materials":list(MATERIALS),
        "R16_OP_material_temporal_signature":signatures,
        "R16_OP_finest_core_numerical_identity":finest_identity,
        "all_six_materials_temporal_signature":all_signature,
        "all_six_materials_finest_core_numerical_identity":all_identity,
        "day1_temporal_nonincrease_counts":monotone_counts,
        "all_checkpoint_temporal_nonincrease_counts":allcp_counts,
        "R16_OP_core_coarse_to_fine":core_reduction,
        "finest_dt_R8_vs_R16_OP_relation_counts":{
            k:dict(v) for k,v in r8_vs_r16_counts.items()
        },
        "scientific_adjudication":[
            "The experiment changes only the fixed-step Layer-ROM research integrator dt; Reference trajectories, state representations and closure formulas remain frozen.",
            "A decreasing R16_OP residual therefore diagnoses temporal/state-evolution contribution after equal-grid spatial operator identity and corrected QAVG/QEND semantics have been established.",
            "Residual at the finest frozen dt is not converted into an application tolerance or an extrapolated zero-dt acceptance statement.",
            "R8 versus R16_OP remains a componentwise descriptive comparison; their errors are not subtracted as independent additive terms."
        ],
        "next":(
            "Repair B01 fixed-head frontier authority with corrected QAVG/QEND. Then decide whether a separate integrator-order/state-evolution formulation study is needed before any closure redesign."
            if decision!=labels["all_materials_and_finest_core_numerical_identity"]
            else
            "Repair B01 fixed-head frontier authority with corrected QAVG/QEND; temporal equal-grid residual is numerically collapsed on the frozen ladder."
        ),
        "application_acceptance_adjudicated":False,
        "performance_measurement_performed":False,
        "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "signatures":signatures,
        "finest_identity":finest_identity,
        "day1_R16_core_nonincrease_counts":{k:monotone_counts["R16_OP"][k] for k in CORE},
        "finest_R8_vs_R16_counts":result["finest_dt_R8_vs_R16_OP_relation_counts"]
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
