#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import pathlib

WIDTHS = ("2.5", "5.0")
ROUTES = ("0.00005000", "0.00002500")
PHASES = ("RISE_1", "FALL", "RISE_2")
TAILS = ("FALL_TAIL", "RISE_2_TAIL")
REVERSALS = ("257", "513")


def load_case(path: pathlib.Path) -> dict:
    data = json.loads(path.read_text())
    if data["schema"] != "swap5.lare.bc2.c4d.case-result.v1":
        raise ValueError(f"wrong C4D case schema: {path}")
    return data


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--case", action="append", required=True, type=pathlib.Path)
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    pre = json.loads(args.prereg.read_text())
    assert pre["phase"] == "PREREGISTERED_AFTER_C3_CLOSEOUT_BEFORE_PHASE_RESOLVED_BIAS_EXECUTION"

    cases = {}
    for path in args.case:
        row = load_case(path)
        cases[str(row["width_cm"])] = row

    complete = set(cases) == set(WIDTHS) and all(
        cases[w]["complete"] and cases[w]["decision"] == "BC2_C4D_PHASE_RESOLVED_CYCLE_MAPPED"
        for w in WIDTHS
    )

    failures = {}
    for w in WIDTHS:
        if w not in cases:
            failures[w] = "MISSING"
        elif not cases[w]["complete"]:
            failures[w] = cases[w].get("failures", {})

    hard_max = 0.0
    route_rank_mismatches = []
    for w in WIDTHS:
        if w not in cases:
            continue
        for route in ROUTES:
            hard = cases[w]["routes"][route]["hard_checks"]
            hard_max = max(
                hard_max,
                max(float(v) for k, v in hard.items() if k not in ("gate", "qualified"))
            )
        for group, mapping in cases[w]["primary_cross_rank_match"].items():
            for name, matched in mapping.items():
                if not matched:
                    route_rank_mismatches.append(f"{w}:{group}:{name}")

    cancellation_by_width_route = {}
    phase_top_map = {}
    tail_top_map = {}
    reversal_top_map = {}
    for w in WIDTHS:
        if w not in cases:
            continue
        cancellation_by_width_route[w] = {}
        phase_top_map[w] = {}
        tail_top_map[w] = {}
        reversal_top_map[w] = {}
        for route in ROUTES:
            rr = cases[w]["routes"][route]
            cancellation_by_width_route[w][route] = {
                "QI": rr["cancellation"]["QI"],
                "QH": rr["cancellation"]["QH"],
                "Q90": rr["cancellation"]["Q90"],
            }
            phase_top_map[w][route] = rr["phase_top_families"]
            tail_top_map[w][route] = rr["tail_top_families"]
            reversal_top_map[w][route] = rr["reversal_top_families"]

    cancellation_support = False
    if complete:
        all_phase_qi = all(
            phase_top_map[w][r][p] == "QI"
            for w in WIDTHS for r in ROUTES for p in PHASES
        )
        all_tail_qi = all(
            tail_top_map[w][r][t] == "QI"
            for w in WIDTHS for r in ROUTES for t in TAILS
        )
        qi_both_signs = all(
            cancellation_by_width_route[w][r]["QI"]["has_both_signs"]
            for w in WIDTHS for r in ROUTES
        )
        whole_cycle_qh = all(cases[w]["whole_cycle_C3_top_family"] == "QH" for w in WIDTHS)
        cancellation_support = all_phase_qi and all_tail_qi and qi_both_signs and whole_cycle_qh
    else:
        all_phase_qi = all_tail_qi = qi_both_signs = whole_cycle_qh = False

    reversal_qh_steps = []
    if complete:
        for step in REVERSALS:
            if all(
                reversal_top_map[w][r][step] == "QH"
                for w in WIDTHS for r in ROUTES
            ):
                reversal_qh_steps.append(int(step))

    sustained_qh_segments = []
    if complete:
        for segment in PHASES:
            if all(
                phase_top_map[w][r][segment] == "QH"
                for w in WIDTHS for r in ROUTES
            ):
                sustained_qh_segments.append(segment)
        for segment in TAILS:
            if all(
                tail_top_map[w][r][segment] == "QH"
                for w in WIDTHS for r in ROUTES
            ):
                sustained_qh_segments.append(segment)

    mechanisms = {
        "H_CANCELLATION": {
            "supported": bool(cancellation_support),
            "checks": {
                "all_phase_top_QI": bool(all_phase_qi),
                "all_nonreversal_tail_top_QI": bool(all_tail_qi),
                "QI_phase_signed_bias_has_both_signs": bool(qi_both_signs),
                "whole_cycle_C3_top_QH_both_widths": bool(whole_cycle_qh),
            },
        },
        "H_REVERSAL_LOCAL": {
            "supported": bool(reversal_qh_steps),
            "QH_rank1_reversal_steps_consistent_both_widths_routes": reversal_qh_steps,
        },
        "H_QH_PHASE": {
            "supported": bool(sustained_qh_segments),
            "QH_rank1_sustained_segments_consistent_both_widths_routes": sustained_qh_segments,
        },
    }

    if not complete or hard_max > 1.0e-10:
        decision = "BC2_C4D_PHASE_DIAGNOSTIC_BLOCKED"
    else:
        decision = "BC2_C4D_PHASE_RESOLVED_MECHANISM_MAPPED"

    progression = []
    if decision == "BC2_C4D_PHASE_RESOLVED_MECHANISM_MAPPED":
        if mechanisms["H_CANCELLATION"]["supported"] and not mechanisms["H_QH_PHASE"]["supported"]:
            progression.append(
                "QI_TEACHER_ORACLE_ON_MONOTONE_PHASES_MAY_BE_PREREGISTERED_AS_CAUSAL_DIAGNOSTIC"
            )
        if mechanisms["H_REVERSAL_LOCAL"]["supported"]:
            progression.append(
                "REVERSAL_LOCAL_QH_ORACLE_MAY_BE_PREREGISTERED_SEPARATELY"
            )
        if mechanisms["H_QH_PHASE"]["supported"]:
            progression.append(
                "DIAGNOSE_COMMON_TERMINAL_SHAPE_GRADIENT_SOURCE_BEFORE_CHANNEL_SPECIFIC_CORRECTION"
            )
        if route_rank_mismatches:
            progression.append(
                "NUMERICAL_ROUTE_RANK_MISMATCH_REQUIRES_QUALIFICATION_BEFORE_MECHANISM_INTERVENTION"
            )

    result = {
        "schema": "swap5.lare.bc2.c4d.result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-BC2-C4D",
        "decision": decision,
        "complete": complete and hard_max <= 1.0e-10,
        "hard_checks": {
            "maximum_recorded_hard_residual_or_identity_error": hard_max,
            "gate": 1.0e-10,
            "failure_count": len(failures),
            "failures": failures,
        },
        "mechanisms": mechanisms,
        "primary_cross_rank_mismatch_segments": route_rank_mismatches,
        "phase_top_families": phase_top_map,
        "tail_top_families": tail_top_map,
        "reversal_top_families": reversal_top_map,
        "cancellation": cancellation_by_width_route,
        "next_authority": progression,
        "interpretation": [
            "C4D uses only the frozen A2 H-direction partition and the unchanged C3 signed-bias ledger.",
            "Whole-cycle QH dominance is not interpreted as a local QH closure defect unless QH also dominates a sustained phase or exact reversal interval under the preregistered checks.",
            "No effect-size threshold, fitted phase boundary, closure change, memory state or stabilizer is introduced."
        ],
        "model_changed": False,
        "next_model_change_authorized": False,
        "groundwater_feedback_authorized": False,
        "application_acceptance_adjudicated": False,
        "production_rom_authorized": False,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "decision": decision,
        "complete": result["complete"],
        "hard_max": hard_max,
        "mechanisms": mechanisms,
        "route_rank_mismatches": route_rank_mismatches,
        "next_authority": progression,
    }, sort_keys=True))
    return 0 if result["complete"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
