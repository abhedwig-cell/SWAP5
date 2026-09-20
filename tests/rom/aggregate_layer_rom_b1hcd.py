#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib

MATERIALS=("B02","B05","B06","B11","B12","B16")
MEMBERS=("L4","L6","R8")
GW=(
    "storage_rmse_cm",
    "cumulative_bottom_rmse_cm",
    "bottom_flux_rmse_cm_per_day",
    "bottom_flux_sign_errors",
    "abs_mean_signed_bottom_flux_error_cm_per_day",
    "max_abs_final_cumulative_bottom_error_cm",
)
VERTICAL=("upper_storage_rmse_cm","lower_storage_rmse_cm","mapped_theta_rmse")
ALL=GW+VERTICAL


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_FIRST_SAME_PARTITION_HYDROLOGICAL_ERROR_EXPOSURE":
        raise SystemExit("wrong B1HC-D preregistration phase")

    results={}
    for p in a.input_dir.rglob("LAYER_ROM_B1HCD_*_RESULT.json"):
        row=json.loads(p.read_text())
        if row.get("schema")!="swap5.layer-rom.phase-b1hc-d.material-result.v1":
            continue
        material=row["material"]
        if material in results:
            raise SystemExit(f"duplicate material {material}")
        results[material]=row
    if set(results)!=set(MATERIALS):
        raise SystemExit(f"material set mismatch: {sorted(results)}")

    day1_relation={}
    component_relation={}
    dimension_order={}
    for material in MATERIALS:
        r=results[material]
        if r["decision"]!="B1HCD_MATERIAL_DECOMPOSED" or not r["integrity"]["pass"]:
            raise SystemExit(f"blocked material {material}")
        day1_relation[material]={}
        component_relation[material]={}
        for member in MEMBERS:
            c=r["same_partition_comparison"][member]["1024"]
            day1_relation[material][member]=c["GW6_vector_relation"]
            component_relation[material][member]=c["component_relation"]
        dimension_order[material]={
            "LARE":{k:v["nonincreasing"] for k,v in r["dimension_order"]["LARE"]["1024"].items()},
            "CoRichards":{k:v["nonincreasing"] for k,v in r["dimension_order"]["CoRichards"]["1024"].items()},
        }

    counts={m:{
        "COR_COMPONENTWISE_NO_WORSE":sum(day1_relation[x][m]=="COR_COMPONENTWISE_NO_WORSE" for x in MATERIALS),
        "LARE_COMPONENTWISE_NO_WORSE":sum(day1_relation[x][m]=="LARE_COMPONENTWISE_NO_WORSE" for x in MATERIALS),
        "NUMERICALLY_EQUIVALENT":sum(day1_relation[x][m]=="NUMERICALLY_EQUIVALENT" for x in MATERIALS),
        "TRADEOFF":sum(day1_relation[x][m]=="TRADEOFF" for x in MATERIALS),
    } for m in MEMBERS}

    b05=results["B05"]
    b05_diag={
        "L4_GW6_relation":b05["same_partition_comparison"]["L4"]["1024"]["GW6_vector_relation"],
        "LARE_L4":{k:b05["LARE"]["L4"]["1024"][k] for k in ALL},
        "CoRichards_L4":{k:b05["CoRichards"]["L4"]["1024"][k] for k in ALL},
        "component_relation":b05["same_partition_comparison"]["L4"]["1024"]["component_relation"],
    }

    nonmono={}
    for material in ("B02","B16"):
        r=results[material]
        nonmono[material]={
            "LARE":{k:r["dimension_order"]["LARE"]["1024"][k] for k in (
                "storage_rmse_cm","cumulative_bottom_rmse_cm","bottom_flux_rmse_cm_per_day","mapped_theta_rmse"
            )},
            "CoRichards":{k:r["dimension_order"]["CoRichards"]["1024"][k] for k in (
                "storage_rmse_cm","cumulative_bottom_rmse_cm","bottom_flux_rmse_cm_per_day","mapped_theta_rmse"
            )},
            "L6_to_R8_values":{
                route:{
                    k:[
                        r[route]["L6"]["1024"][k],
                        r[route]["R8"]["1024"][k]
                    ] for k in (
                        "storage_rmse_cm","cumulative_bottom_rmse_cm","bottom_flux_rmse_cm_per_day","mapped_theta_rmse"
                    )
                } for route in ("LARE","CoRichards")
            }
        }

    r8={
        material:{
            "LARE":{k:results[material]["LARE"]["R8"]["1024"][k] for k in ALL},
            "CoRichards":{k:results[material]["CoRichards"]["R8"]["1024"][k] for k in ALL},
            "component_relation":results[material]["same_partition_comparison"]["R8"]["1024"]["component_relation"],
            "GW6_relation":results[material]["same_partition_comparison"]["R8"]["1024"]["GW6_vector_relation"],
        } for material in MATERIALS
    }

    result={
      "schema":"swap5.layer-rom.phase-b1hc-d.aggregate-result.v1",
      "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HC-D",
      "decision":"B1HCD_FULL_COHORT_HYDROLOGICAL_DECOMPOSITION_COMPLETE",
      "materials":list(MATERIALS),
      "members":list(MEMBERS),
      "primary_checkpoint_step":1024,
      "day1_GW6_vector_relation":day1_relation,
      "day1_GW6_relation_counts_by_member":counts,
      "day1_component_relation":component_relation,
      "day1_dimension_order_by_component":dimension_order,
      "B05_L4_diagnostic":b05_diag,
      "B02_B16_nonmonotone_diagnostic":nonmono,
      "R8_cross_material_residual_vectors":r8,
      "material_results":results,
      "interpretation_rules":[
        "Counts summarize a frozen full cohort and are descriptive, not acceptance rates.",
        "The same-partition Layer-ROM minus CoRichards gap is not an additive closure-error decomposition.",
        "A CoRichards componentwise advantage is evidence that the Layer-ROM closure/model form adds error on that same partition; it does not prove all CoRichards error is pure spatial discretization.",
        "Shared nonmonotonicity across both routes is evidence that representation/discretization contributes; nonmonotonicity unique to Layer-ROM points toward layer-closure/model-form interaction.",
        "No aggregate weighted score or post-result tolerance is used."
      ],
      "performance_measurement_performed":False,
      "application_acceptance_adjudicated":False,
      "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "decision":result["decision"],
      "GW6_relation_counts":counts,
      "B05_L4_relation":b05_diag["L4_GW6_relation"],
      "B02_B16_nonmonotone":nonmono,
      "R8_GW6_relation":{m:r8[m]["GW6_relation"] for m in MATERIALS}
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
