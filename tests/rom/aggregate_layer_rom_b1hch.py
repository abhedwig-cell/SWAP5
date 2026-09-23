#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib
from collections import Counter

MATERIALS=("B02","B05","B06","B11","B12","B16")
CORE=("storage_rms","cumulative_bottom_rms","qavg_rms","qend_rms","mapped_theta_rms")


def find_result(root:pathlib.Path,material:str)->pathlib.Path:
    matches=list(root.rglob(f"LAYER_ROM_B1HCH_{material}_RESULT.json"))
    if len(matches)!=1:
        raise RuntimeError(f"expected one B1HCH result for {material}, found {len(matches)}")
    return matches[0]


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input-dir",required=True,type=pathlib.Path)
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()

    pre=json.loads(a.prereg.read_text())
    if pre["phase"]!="PREREGISTERED_BEFORE_CANDIDATE_SELF_CONVERGENCE_RESULTS":
        raise SystemExit("wrong B1HCH preregistration")
    rows={m:json.loads(find_result(a.input_dir,m).read_text()) for m in MATERIALS}
    for m,r in rows.items():
        if r["material"]!=m or r["decision"]!="B1HCH_MATERIAL_SELF_CONVERGENCE_CHARACTERIZED":
            raise SystemExit(f"B1HCH material mismatch {m}")
        if not r["integrity"]["pass"] or r["integrity"]["reference_trajectory_used"]:
            raise SystemExit(f"B1HCH integrity failed {m}")

    primary={m:bool(rows[m]["primary_R16_OP_SELF_CONVERGENT"]) for m in MATERIALS}
    all_six=all(primary.values())
    labels=pre["panel_decision_labels"]
    decision=labels["all_six_self_convergent"] if all_six else labels["mixed"]

    class_counts={"R16_OP":{},"R8":{}}
    for rid,key in (("R16_OP","R16_OP"),("R8","R8_secondary")):
        for comp in CORE:
            class_counts[rid][comp]=dict(Counter(
                rows[m][key]["component_classification"][comp] for m in MATERIALS
            ))

    apparent_order={
        m:{
            "R16_OP":rows[m]["R16_OP"]["apparent_order"],
            "R8":rows[m]["R8_secondary"]["apparent_order"],
        } for m in MATERIALS
    }
    pairwise_rms={
        m:{
            "R16_OP":{
                "coarse_mid":{k:rows[m]["R16_OP"]["coarse_mid"][obs]["rms"] for k,obs in {
                    "storage_rms":"storage","cumulative_bottom_rms":"cumulative_bottom","qavg_rms":"qavg","qend_rms":"qend","mapped_theta_rms":"mapped_theta"
                }.items()},
                "mid_fine":{k:rows[m]["R16_OP"]["mid_fine"][obs]["rms"] for k,obs in {
                    "storage_rms":"storage","cumulative_bottom_rms":"cumulative_bottom","qavg_rms":"qavg","qend_rms":"qend","mapped_theta_rms":"mapped_theta"
                }.items()},
            }
        } for m in MATERIALS
    }

    if all_six:
        next_step="Preregister a finite-Reference temporal-contribution diagnostic on the frozen six-material panel before any closure/state redesign. Candidate self-convergence is established, but this does not identify the continuous-Richards limit."
        scientific=[
            "R16_OP candidate trajectories self-converge on all six frozen materials under the preregistered dt-halving classification.",
            "Because B1HCG retained nonzero Reference-relative residuals, self-convergence separates candidate numerical settling from candidate-versus-finite-Reference discrepancy.",
            "The next causal question is the temporal contribution of the finite Reference trajectory; closure or state redesign remains premature until that is separated."
        ]
    else:
        next_step="Hold closure/state redesign. Diagnose the materials/components without established R16_OP self-convergence before introducing any new state or closure family."
        scientific=[
            "R16_OP candidate self-convergence is not established uniformly across the frozen six-material panel.",
            "The research propagation route therefore remains numerically unresolved on at least one material/component independently of Reference discrepancy.",
            "Closure/state redesign remains held because candidate integrator behaviour has not yet been cleanly separated from model-form error."
        ]

    result={
        "schema":"swap5.layer-rom.phase-b1hch.aggregate-result.v1",
        "workstream":"F-ROM-LAYER",
        "work_unit":"LAYER-ROM-B1HCH",
        "decision":decision,
        "materials":list(MATERIALS),
        "R16_OP_SELF_CONVERGENT":primary,
        "all_six_R16_OP_self_convergent":all_six,
        "component_classification_counts":class_counts,
        "R16_OP_pairwise_rms":pairwise_rms,
        "apparent_order_diagnostic":apparent_order,
        "scientific_adjudication":scientific,
        "next":next_step,
        "firewalls":[
            "NO_REFERENCE_TRAJECTORY_USED_IN_PRIMARY_SELF_CONVERGENCE",
            "NO_ZERO_DT_APPLICATION_ACCEPTANCE",
            "NO_CLOSURE_OR_STATE_RETUNING",
            "NO_RUNTIME_OR_SPEED_CLAIM",
            "NO_PRODUCTION_ROM"
        ],
        "application_acceptance_adjudicated":False,
        "performance_measurement_performed":False,
        "production_rom_authorized":False
    }
    a.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "R16_OP_SELF_CONVERGENT":primary,
        "classification_counts":class_counts["R16_OP"],
        "next":next_step
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
