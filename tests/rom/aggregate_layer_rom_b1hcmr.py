#!/usr/bin/env python3
from __future__ import annotations

import argparse,json,pathlib

MATERIALS=("B02","B05","B06","B11","B12","B16")
REPS=("L4","L6","R8","U4","U8","R16_OP")
CHECKPOINTS=("64","128","256","512","1024")
PRIMARY=("cumulative_bottom_rms","qavg_rms","qend_rms","mapped_theta_rms",
         "qavg_sign_mismatch","qend_sign_mismatch")


def find_result(root:pathlib.Path,m:str)->pathlib.Path:
    xs=list(root.rglob(f"LAYER_ROM_B1HCMR_{m}_RESULT.json"))
    if len(xs)!=1:
        raise SystemExit(f"{m}: expected one result, found {len(xs)}")
    return xs[0]


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_SEMANTIC_REPAIR_REBASE_RESPONSE":
        raise SystemExit("wrong B1HCMR preregistration")

    rows={}
    for m in MATERIALS:
        r=json.loads(find_result(a.input_dir,m).read_text())
        if r.get("material")!=m or r.get("work_unit")!="LAYER-ROM-B1HCMR":
            raise SystemExit(f"{m}: result identity drift")
        if not r["integrity"]["pass"] or not r["integrity"]["corrected_QEND_from_endpoint_state"]:
            raise SystemExit(f"{m}: integrity/QEND contract failed")
        rows[m]=r

    unresolved=[m for m,r in rows.items() if r["decision"]==pre["decisions"]["oracle_unresolved"]]
    decision=pre["decisions"]["oracle_unresolved"] if unresolved else pre["decisions"]["complete"]

    placement={}
    for label in ("dimension4","dimension8"):
        supported=[m for m,r in rows.items() if r["placement"][label]["stable_supported"]]
        placement[label]={
            "stable_supported":supported,
            "not_stable_supported":[m for m in MATERIALS if m not in supported],
            "support_count":len(supported),
            "material_count":len(MATERIALS),
            "by_material":{m:rows[m]["placement"][label] for m in MATERIALS},
        }

    transitions={}
    for key in ("L4_to_L6","L6_to_R8"):
        nw=[m for m,r in rows.items() if r["targeted_dimension_transitions"][key]["stable_componentwise_no_worse"]]
        strict=[m for m,r in rows.items() if r["targeted_dimension_transitions"][key]["stable_strict_improvement"]]
        transitions[key]={
            "stable_componentwise_no_worse_materials":nw,
            "stable_strict_improvement_materials":strict,
            "tradeoff_or_worse_materials":[m for m in MATERIALS if m not in nw],
            "by_material":{m:rows[m]["targeted_dimension_transitions"][key] for m in MATERIALS},
        }

    checkpoint_monotonicity={}
    tol=float(pre["placement_gate"]["tolerance_continuous"])
    for basis in ("Rstar","ultra"):
        checkpoint_monotonicity[basis]={}
        for cp in CHECKPOINTS:
            checkpoint_monotonicity[basis][cp]={}
            for metric,path in (
                ("cumulative_bottom_rms",("cumulative_bottom","rms")),
                ("qavg_rms",("qavg","rms")),
                ("qend_rms",("qend","rms")),
                ("mapped_theta_rms",("mapped_theta","rms")),
                ("upper_0_80_storage_rms",("upper_0_80_storage","rms")),
                ("lower_80_160_storage_rms",("lower_80_160_storage","rms")),
            ):
                yes=[];no=[]
                for m,r in rows.items():
                    vals=[
                        float(r["representations"][rid]["checkpoints"][cp][basis][path[0]][path[1]])
                        for rid in ("L4","L6","R8")
                    ]
                    ok=vals[1]<=vals[0]+tol and vals[2]<=vals[1]+tol
                    (yes if ok else no).append(m)
                checkpoint_monotonicity[basis][cp][metric]={
                    "nonincreasing_materials":yes,"nonmonotone_materials":no
                }

    selected={}
    for m,r in rows.items():
        selected[m]={}
        for rid in ("L4","L6","R8","R16_OP"):
            d=r["representations"][rid]["day1"]["Rstar"]
            selected[m][rid]={
                "storage_rms_cm":d["storage"]["rms"],
                "cumulative_bottom_rms_cm":d["cumulative_bottom"]["rms"],
                "qavg_rms_cm_per_day":d["qavg"]["rms"],
                "qend_rms_cm_per_day":d["qend"]["rms"],
                "mapped_theta_rms":d["mapped_theta"]["rms"],
                "upper_0_80_storage_rms_cm":d["upper_0_80_storage"]["rms"],
                "lower_80_160_storage_rms_cm":d["lower_80_160_storage"]["rms"],
                "qavg_sign_mismatch":d["qavg_sign_mismatch"],
                "qend_sign_mismatch":d["qend_sign_mismatch"],
                "max_abs_final_cumulative_bottom_error_cm":d["max_abs_final_cumulative_bottom_error_cm"],
                "oracle_resolved":r["representations"][rid]["oracle_resolved"],
            }

    eq={m:rows[m]["equal_grid_temporal_control"] for m in MATERIALS}
    result={
        "schema":"swap5.layer-rom.phase-b1hcmr.adjudication.v1",
        "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B1HCMR",
        "decision":decision,
        "unresolved_materials":unresolved,
        "placement_support":placement,
        "targeted_dimension_transitions":transitions,
        "checkpoint_monotonicity":checkpoint_monotonicity,
        "equal_grid_temporal_control":eq,
        "selected_Rstar_fidelity_vectors":selected,
        "integrity":{
            "pass":not unresolved,
            "all_six_materials_present":len(rows)==6,
            "all_candidate_oracles_resolved":not unresolved,
            "corrected_QEND_contract_all_materials":all(r["integrity"]["corrected_QEND_from_endpoint_state"] for r in rows.values()),
            "hydrological_model_changed":False,
            "new_reference_generated":False,
        },
        "scientific_adjudication":(
            [
                "All reduced Layer-ROM representations were evaluated with DOP853 and independently crosschecked by Radau after restoring the B1HCF terminal-Darcy QEND contract.",
                "R_star and the ultrafine Reference were both retained as reference bases; placement and dimension support is called stable only when its componentwise direction survives both.",
                "Remaining reduced-member residuals are free of the previously diagnosed candidate Heun error and first-order finite Reference truncation at the qualified scale.",
                "These residuals still combine vertical Richards spatial-discretization effects and Layer-ROM closure/localization effects. Same-partition CoRichards temporal qualification is required before decomposing them.",
                "No application acceptance follows from these fidelity vectors."
            ] if not unresolved else [
                "At least one material/representation independent numerical oracle did not resolve under the frozen gate.",
                "Do not use unresolved members for placement, dimension or closure attribution.",
                "Remain on candidate numerical integration for the affected members."
            ]
        ),
        "next":pre["next_if_complete"] if not unresolved else "RESOLVE_B1HCMR_NUMERICAL_ORACLE_ONLY",
        "application_acceptance_adjudicated":False,
        "performance_measurement_performed":False,
        "production_rom_authorized":False,
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "placement_support":{k:{x:y for x,y in v.items() if x!="by_material"} for k,v in placement.items()},
        "transitions":{k:{x:y for x,y in v.items() if x!="by_material"} for k,v in transitions.items()},
        "selected_Rstar_fidelity_vectors":selected,
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
