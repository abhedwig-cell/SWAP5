#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib

MATERIALS=("B02","B05","B06","B11","B12","B16")
REPS=("L4","L6","R8","U4","U8","R16_OP")

def find_result(root:pathlib.Path,material:str)->pathlib.Path:
    matches=list(root.rglob(f"LAYER_ROM_B1HCM_{material}_RESULT.json"))
    if len(matches)!=1:
        raise SystemExit(f"{material}: expected one result, found {len(matches)}")
    return matches[0]

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_CONTINUOUS_TIME_REDUCED_LADDER_RESPONSE":
        raise SystemExit("wrong B1HCM preregistration")

    rows={}
    for m in MATERIALS:
        r=json.loads(find_result(a.input_dir,m).read_text())
        if r["material"]!=m or r["work_unit"]!="LAYER-ROM-B1HCM":
            raise SystemExit(f"{m}: identity drift")
        if not r["integrity"]["pass"]:
            raise SystemExit(f"{m}: integrity failed")
        rows[m]=r

    unresolved=[m for m,r in rows.items() if r["decision"]==pre["decisions"]["oracle_unresolved"]]
    decision=pre["decisions"]["oracle_unresolved"] if unresolved else pre["decisions"]["complete"]

    placement={
        "dimension4":{
            "supported":[m for m,r in rows.items() if r["placement"]["dimension4"]["supported"]],
            "not_supported":[m for m,r in rows.items() if not r["placement"]["dimension4"]["supported"]],
        },
        "dimension8":{
            "supported":[m for m,r in rows.items() if r["placement"]["dimension8"]["supported"]],
            "not_supported":[m for m,r in rows.items() if not r["placement"]["dimension8"]["supported"]],
        },
    }
    for x in placement.values():
        x["support_count"]=len(x["supported"])
        x["material_count"]=len(MATERIALS)

    transitions={}
    for key in ("L4_to_L6","L6_to_R8"):
        transitions[key]={
            "componentwise_nonworse":[m for m,r in rows.items() if r["targeted_dimension_transitions"][key]["higher_dimension_no_worse_all_primary"]],
            "tradeoff":[m for m,r in rows.items() if not r["targeted_dimension_transitions"][key]["higher_dimension_no_worse_all_primary"]],
        }

    equal_grid={
        "identity_all_conditions":[m for m,r in rows.items() if r["equal_grid_control"]["all_identity_conditions"]],
        "not_absolute_floor_identity":[m for m,r in rows.items() if not r["equal_grid_control"]["all_identity_conditions"]],
    }

    selected={}
    for m,r in rows.items():
        selected[m]={}
        for rid in ("L4","L6","R8","R16_OP"):
            q=r["representations"][rid]
            selected[m][rid]={
                "storage_rms_cm":q["fidelity"]["storage"]["rms"],
                "cumulative_bottom_rms_cm":q["fidelity"]["cumulative_bottom"]["rms"],
                "qavg_rms_cm_per_day":q["fidelity"]["qavg"]["rms"],
                "qend_rms_cm_per_day":q["fidelity"]["qend"]["rms"],
                "mapped_theta_rms":q["fidelity"]["mapped_theta"]["rms"],
                "qavg_sign_mismatch":q["sign_mismatch"]["QAVG"],
                "qend_sign_mismatch":q["sign_mismatch"]["QEND"],
                "max_abs_final_cumulative_bottom_error_cm":q["max_abs_final_cumulative_bottom_error_cm"],
                "oracle_resolved":q["oracle_resolved"],
            }

    result={
        "schema":"swap5.layer-rom.phase-b1hcm.adjudication.v1",
        "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCM",
        "decision":decision,
        "unresolved_materials":unresolved,
        "placement_support":placement,
        "targeted_dimension_transitions":transitions,
        "equal_grid_control":equal_grid,
        "selected_fidelity_vectors":selected,
        "material_results":{m:{
            "placement":rows[m]["placement"],
            "targeted_dimension_transitions":rows[m]["targeted_dimension_transitions"],
            "equal_grid_control":rows[m]["equal_grid_control"],
        } for m in MATERIALS},
        "integrity":{
            "pass":not unresolved,
            "all_six_materials_present":len(rows)==len(MATERIALS),
            "all_candidate_oracles_resolved":not unresolved,
            "hydrological_model_changed":False,
            "new_reference_generated":False,
        },
        "interpretation":(
            [
                "The frozen reduced Layer-ROM representations are now evaluated with continuous-time DOP853 integration and independently crosschecked by Radau against the B1HCL-qualified Reference temporal limit.",
                "Remaining reduced-member residuals are no longer attributable to candidate Heun time-integration error or the finite Reference outer interval used in B1H.",
                "The residual still combines Richards spatial-discretization effects with Layer-ROM closure/localization effects; same-partition CoRichards requires its own temporally qualified rebase before those mechanisms can be separated.",
                "Placement and dimension results are descriptive componentwise fidelity results, not application acceptance."
            ] if not unresolved else [
                "At least one reduced representation/material numerical oracle is unresolved.",
                "Do not use unresolved members for representation or closure attribution.",
                "Remain on candidate numerical integration for the affected member before same-partition model-form decomposition."
            ]
        ),
        "application_acceptance_adjudicated":False,
        "performance_measurement_performed":False,
        "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "placement_support":placement,
        "targeted_dimension_transitions":transitions,
        "equal_grid_control":equal_grid,
        "selected_fidelity_vectors":selected
    },sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
