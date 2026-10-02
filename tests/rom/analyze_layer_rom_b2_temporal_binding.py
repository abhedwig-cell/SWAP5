#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib

SUBSET={"L3":"R3","L4":"R4","L6":"R6"}
CONTEXT="R8"


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--b1",required=True,type=pathlib.Path)
    ap.add_argument("--binding",required=True,type=pathlib.Path)
    ap.add_argument("--c4v-result",required=True,type=pathlib.Path)
    ap.add_argument("--c4v-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--c4w-closeout",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    args=ap.parse_args()

    b1=json.loads(args.b1.read_text())
    bind=json.loads(args.binding.read_text())
    v=json.loads(args.c4v_result.read_text())
    vc=json.loads(args.c4v_closeout.read_text())
    wc=json.loads(args.c4w_closeout.read_text())

    if bind["phase"]!="FROZEN_EXTRACTION_OF_PREEXISTING_PROSPECTIVE_EVIDENCE":
        raise SystemExit("wrong B2 binding phase")
    if b1["decision"]!="B1_DIMENSION4_GW_FRONTIER_REPLICATED":
        raise SystemExit("B2 predecessor drift")
    if v["decision"]!="C4V_HIGHER_DIMENSION_GW_FRONTIER_PERSISTS":
        raise SystemExit("C4V decision drift")
    if vc["decision"]!="C4V_HIGHER_DIMENSION_GW_FRONTIER_PERSISTS":
        raise SystemExit("C4V closeout drift")
    if wc["decision"]!="C4W_SPURIOUS_REVERSAL_MAGNITUDE_CHARACTERIZED":
        raise SystemExit("C4W decision drift")
    if bind["evidence_classification"]["Layer_ROM_B2"]!="RETROSPECTIVE_AUTHORITY_BINDING_AND_REANALYSIS_ONLY":
        raise SystemExit("B2 evidence classification drift")

    persistent=set(vc["persistent_crossing"]["both_comparators"])
    subset_persistent={lid:(src in persistent) for lid,src in SUBSET.items()}
    r8_persistent=CONTEXT in persistent

    day={}
    for lid,src in {**SUBSET,"R8_context":CONTEXT}.items():
        s=v["summaries"][f"LARE_{src}"]["1024"]
        day[lid]={
            "source_member":src,
            "storage_RMSE_cm":s["storage_rmse_cm"],
            "cumulative_bottom_RMSE_cm":s["cumulative_bottom_rmse_cm"],
            "bottom_flux_RMSE_cm_per_day":s["bottom_flux_rmse_cm_per_day"],
            "bottom_flux_sign_errors":s["bottom_flux_sign_errors"],
            "abs_mean_signed_bottom_flux_error_cm_per_day":s["abs_mean_signed_bottom_flux_error_cm_per_day"],
            "max_abs_final_cumulative_bottom_error_cm":s["max_abs_final_cumulative_bottom_error_cm"],
            "mapped_theta_RMSE":s["mapped_theta_rmse"],
            "persistent_crossing_both":src in persistent,
        }

    short={}
    for lid in ("L3","L4","L6"):
        s=b1["members"][lid]
        short[lid]={
            "horizon_day":0.064,
            "cumulative_bottom_RMSE_cm":s["cumulative_bottom_exchange_rmse_cm"],
            "bottom_flux_RMSE_cm_per_day":s["terminal_bottom_flux_rmse_cm_per_day"],
            "bottom_flux_sign_errors":s["bottom_flux_sign_error_count"],
            "mapped_theta_RMSE":s["mapped_R16_theta_rmse"],
        }

    v03=wc["V03_reversal_magnitude"]
    reversal={}
    for lid,src in {"L4":"R4","L6":"R6","R8_context":"R8"}.items():
        r=v03[src]
        reversal[lid]={
            "source_member":src,
            "candidate_reversal_steps":r["candidate_reversal_steps"],
            "mismatch_count":r["mismatch_count"],
            "first_mismatch":r["first_mismatch"],
        }

    if not any(subset_persistent.values()) and r8_persistent:
        decision="B2_ONE_DAY_GW_FRONTIER_NOT_REACHED_WITHIN_L3_L4_L6_R8_REQUIRED"
    elif any(subset_persistent.values()):
        decision="B2_ONE_DAY_GW_FRONTIER_PERSISTS_WITHIN_L3_L4_L6"
    else:
        decision="B2_SOURCE_AUTHORITY_INCONSISTENT"

    result={
        "schema":"swap5.layer-rom.phase-b2.result.v1",
        "workstream":"F-ROM-LAYER","work_unit":"LAYER-ROM-B2",
        "decision":decision,
        "evidence_classification":bind["evidence_classification"],
        "B1_short_horizon":short,
        "one_day_metrics":day,
        "persistent_crossing":{
            "source_C4V_both_comparators":vc["persistent_crossing"]["both_comparators"],
            "within_L3_L4_L6":subset_persistent,
            "R8_context":r8_persistent,
            "source_minimum_dimension":vc["persistent_crossing"]["minimum_both_dimension"],
        },
        "V03_reversal_context":reversal,
        "adjudication":[
            "The B1 dimension-4 groundwater frontier is a short-horizon result and does not persist to 1.024 day.",
            "Within the Layer-ROM L3/L4/L6 subset, no member persistently crosses both C4V groundwater comparators over all original prospective checkpoints.",
            "The source C4V ladder first reaches persistent one-day crossing at R8; R12 also crosses.",
            "The loss of L4/L6 one-day fidelity is not a mass-balance or numerical-qualification failure. C4W shows sustained wrong-sign V03 bottom flux at non-negligible Reference magnitudes.",
            "This establishes a strong horizon dependence of the minimum closure-capable representation in the bounded B01 fixed-water-table laboratory."
        ],
        "interpretation_firewalls":[
            "B2 itself is retrospective evidence binding, not a new blind or prospective validation.",
            "Original C4V prospective status beyond 0.064 day is preserved as source provenance.",
            "No application acceptance, deadband, closure retuning, moving-water-table claim, speed claim or production admission follows."
        ],
        "next":"SCIENTIFIC_CHOICE_REQUIRED_MATERIAL_CONSTITUTIVE_TRANSFER_OR_LOWER_BOUNDARY_SEMANTICS_TRANSFER",
        "production_rom_authorized":False,
    }
    args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
        "decision":decision,
        "persistent_crossing":result["persistent_crossing"],
        "one_day":day,
        "V03":reversal,
    },sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
