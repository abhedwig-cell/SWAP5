#!/usr/bin/env python3
from __future__ import annotations

import argparse
import collections
import json
import math
import pathlib

HARD_MASS_GATE_CM = 1.0e-12
GW_D_HORIZONS = (4, 64, 256)
GW_R_HORIZON = 1250
STEP_DAY = 0.0008


def fields(payload: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for part in payload.split("|"):
        if "=" in part:
            key, value = part.split("=", 1)
            out[key] = value
    return out


def flux_sign(value: float) -> int:
    if value > 0.0:
        return 1
    if value < 0.0:
        return -1
    return 0


def reversal_steps(rows: list[tuple[int, float]]) -> list[int]:
    events: list[int] = []
    previous = 0
    for step, value in sorted(rows):
        current = flux_sign(value)
        if current == 0:
            continue
        if previous != 0 and current != previous:
            events.append(step)
        previous = current
    return events


def load_reference_start_nodes(
    path: pathlib.Path,
    expected: set[tuple[str, int]],
) -> dict[tuple[str, int], dict[int, tuple[float, float]]]:
    out: dict[tuple[str, int], dict[int, tuple[float, float]]] = {}
    for line in path.open(errors="replace"):
        if not line.startswith("LAREGW1_NODE|"):
            continue
        row = fields(line.split("|", 1)[1])
        key = (row["HISTORY"], int(row["STEP"]))
        if key not in expected:
            continue
        out.setdefault(key, {})[int(row["NODE"])] = (
            float(row["H"]),
            float(row["THETA"]),
        )
    return out


def max_vector(records: list[dict[str, float]]) -> dict[str, float]:
    names = (
        "cum_bottom",
        "d_total",
        "d_upper",
        "d_lower",
        "terminal_bottom_flux",
    )
    if not records:
        return {name: 0.0 for name in names}
    return {
        name: max(abs(float(row[name])) for row in records)
        for name in names
    }


def pareto_noninferior(
    candidate: dict[str, float | int],
    control: dict[str, float | int],
    numeric: tuple[str, ...],
) -> dict[str, object]:
    comparisons = {
        name: float(candidate[name]) <= float(control[name])
        for name in numeric
    }
    strict = any(float(candidate[name]) < float(control[name]) for name in numeric)
    return {
        "noninferior_all_components": all(comparisons.values()),
        "strictly_better_at_least_one_component": strict,
        "promising_relative_to_control": all(comparisons.values()) and strict,
        "component_noninferiority": comparisons,
    }


GW_D_PARETO_COMPONENTS = (
    "gw_d_cum_bottom_cm",
    "gw_d_terminal_bottom_flux_cm_per_day",
    "gw_d_total_storage_cm",
    "gw_d_lower_storage_cm",
    "gw_d_max_reversal_step_difference",
    "gw_d_terminal_flux_sign_mismatch_count",
    "reversal_sequence_mismatch_count",
)

GW_R_PARETO_COMPONENTS = (
    "gw_r_one_day_cum_bottom_cm",
    "gw_r_one_day_total_storage_cm",
    "gw_r_abs_mean_signed_pair_exchange_difference_cm",
)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, type=pathlib.Path)
    ap.add_argument("--repeat", required=True, type=pathlib.Path)
    ap.add_argument("--reference", required=True, type=pathlib.Path)
    ap.add_argument("--selection", required=True, type=pathlib.Path)
    ap.add_argument("--p2-prereg", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    raw = args.input.read_text()
    repeat = args.repeat.read_text()
    selection = json.loads(args.selection.read_text())
    prereg = json.loads(args.p2_prereg.read_text())

    if selection["response_used_for_selection"] is not False:
        raise SystemExit("P2 representation selection was not response blind")
    if prereg["phase"] != "PREREGISTERED_BEFORE_FORMAL_P1_PAIR_FUTURE_RESPONSE_EXECUTION":
        raise SystemExit("wrong P2 preregistration phase")
    if prereg["prior_exposure"]["firewall"] == "":
        raise SystemExit("prior pilot firewall missing")

    expected_starts = {
        (row["history"], int(row["step"]))
        for row in selection["start_rows"]
    }
    reference_nodes = load_reference_start_nodes(args.reference, expected_starts)

    start_nodes: dict[tuple[str, int], dict[int, tuple[float, float]]] = {}
    endpoint: dict[tuple[str, int, str, int], dict[str, float | int]] = {}
    steps: dict[tuple[str, int, str], list[tuple[int, float]]] = collections.defaultdict(list)
    max_mass = 0.0
    fallback_classes = collections.Counter()
    unique_start_marker = None

    for line in raw.splitlines():
        if line.startswith("LAREGW2_START_NODE|"):
            row = fields(line.split("|", 1)[1])
            key = (row["HISTORY"], int(row["STEP"]))
            start_nodes.setdefault(key, {})[int(row["NODE"])] = (
                float(row["H"]), float(row["THETA"])
            )
        elif line.startswith("LAREGW2_PROBE|"):
            row = fields(line.split("|", 1)[1])
            key = (
                row["HISTORY"], int(row["START_STEP"]),
                row["PROBE"], int(row["HORIZON_STEP"])
            )
            endpoint[key] = {
                "d_total": float(row["D_TOTAL_STORAGE"]),
                "d_upper": float(row["D_UPPER_STORAGE"]),
                "d_lower": float(row["D_LOWER_STORAGE"]),
                "cum_top": float(row["CUM_TOP_EXCHANGE"]),
                "cum_bottom": float(row["CUM_BOTTOM_OUTWARD_EXCHANGE"]),
                "terminal_bottom_flux": float(row["TERMINAL_BOTTOM_FLUX"]),
                "fallback_count": int(row["FALLBACK_COUNT"]),
                "max_abs_mass": float(row["MAX_ABS_MASS"]),
            }
        elif line.startswith("LAREGW2_STEP|"):
            row = fields(line.split("|", 1)[1])
            key = (row["HISTORY"], int(row["START_STEP"]), row["PROBE"])
            step = int(row["STEP"])
            flux = float(row["BOTTOM_FLUX"])
            mass = abs(float(row["MASS"]))
            max_mass = max(max_mass, mass)
            steps[key].append((step, flux))
        elif line.startswith("LAREGW2_FALLBACK|"):
            row = fields(line.split("|", 1)[1])
            fallback_classes[row.get("CLASS", "UNKNOWN")] += 1
        elif line.startswith("LAREGW2_UNIQUE_START_COUNT="):
            unique_start_marker = int(line.rsplit("=", 1)[1])

    start_identity = True
    start_identity_failures = []
    for key in sorted(expected_starts):
        ref = reference_nodes.get(key, {})
        got = start_nodes.get(key, {})
        if set(ref) != set(range(1, 17)) or set(got) != set(range(1, 17)):
            start_identity = False
            start_identity_failures.append({
                "history": key[0], "step": key[1], "reason": "missing_nodes"
            })
            continue
        for node in range(1, 17):
            if ref[node] != got[node]:
                start_identity = False
                start_identity_failures.append({
                    "history": key[0], "step": key[1], "node": node,
                    "reference": ref[node], "probe": got[node],
                })
                break

    probes = [row["id"] for row in prereg["future_probes"]["definitions"]]
    horizons = (4, 64, 256, 1250)
    expected_endpoint = {
        (history, step, probe, horizon)
        for history, step in expected_starts
        for probe in probes
        for horizon in horizons
    }
    expected_step_keys = {
        (history, step, probe)
        for history, step in expected_starts
        for probe in probes
    }

    endpoint_complete = set(endpoint) == expected_endpoint
    step_complete = (
        set(steps) == expected_step_keys
        and all(len(rows) == 1250 for rows in steps.values())
    )

    representation_results = {}
    for representation in selection["representations"]:
        cid = representation["candidate_id"]
        comparisons = []
        reversal_summary = []

        for pair_index, pair in enumerate(representation["pairs"], start=1):
            a = (pair["a"]["history"], int(pair["a"]["step"]))
            b = (pair["b"]["history"], int(pair["b"]["step"]))

            for probe in probes:
                rev_a = reversal_steps(steps.get((a[0], a[1], probe), []))
                rev_b = reversal_steps(steps.get((b[0], b[1], probe), []))
                same_length = len(rev_a) == len(rev_b)
                if same_length and rev_a:
                    max_reversal_delta = max(abs(x - y) for x, y in zip(rev_a, rev_b))
                elif same_length:
                    max_reversal_delta = 0
                else:
                    max_reversal_delta = None

                reversal_summary.append({
                    "pair_index": pair_index,
                    "probe": probe,
                    "a_reversal_steps": rev_a,
                    "b_reversal_steps": rev_b,
                    "sequence_length_match": same_length,
                    "max_step_difference_when_match": max_reversal_delta,
                })

                for horizon in horizons:
                    ea = endpoint[(a[0], a[1], probe, horizon)]
                    eb = endpoint[(b[0], b[1], probe, horizon)]
                    comparisons.append({
                        "pair_index": pair_index,
                        "probe": probe,
                        "horizon_step": horizon,
                        "cum_bottom": float(ea["cum_bottom"]) - float(eb["cum_bottom"]),
                        "d_total": float(ea["d_total"]) - float(eb["d_total"]),
                        "d_upper": float(ea["d_upper"]) - float(eb["d_upper"]),
                        "d_lower": float(ea["d_lower"]) - float(eb["d_lower"]),
                        "terminal_bottom_flux": (
                            float(ea["terminal_bottom_flux"])
                            - float(eb["terminal_bottom_flux"])
                        ),
                        "terminal_sign_a": flux_sign(float(ea["terminal_bottom_flux"])),
                        "terminal_sign_b": flux_sign(float(eb["terminal_bottom_flux"])),
                    })

        gw_d_records = [
            row for row in comparisons
            if int(row["horizon_step"]) in GW_D_HORIZONS
        ]
        gw_r_records = [
            row for row in comparisons
            if int(row["horizon_step"]) == GW_R_HORIZON
        ]

        gw_d_max = max_vector(gw_d_records)
        gw_r_max = max_vector(gw_r_records)

        gw_d_sign_mismatches = sum(
            int(row["terminal_sign_a"] != row["terminal_sign_b"])
            for row in gw_d_records
        )
        gw_r_sign_mismatches = sum(
            int(row["terminal_sign_a"] != row["terminal_sign_b"])
            for row in gw_r_records
        )
        reversal_mismatches = sum(
            int(not row["sequence_length_match"])
            for row in reversal_summary
        )
        matched_reversal_deltas = [
            int(row["max_step_difference_when_match"])
            for row in reversal_summary
            if row["max_step_difference_when_match"] is not None
        ]
        max_reversal_steps = max(matched_reversal_deltas, default=0)

        signed_one_day = [
            float(row["cum_bottom"]) for row in gw_r_records
        ]
        mean_signed_one_day = (
            sum(signed_one_day) / len(signed_one_day)
            if signed_one_day else 0.0
        )
        metrics = {
            "gw_r_one_day_cum_bottom_cm": gw_r_max["cum_bottom"],
            "gw_r_one_day_cum_bottom_mm": 10.0 * gw_r_max["cum_bottom"],
            "gw_r_one_day_total_storage_cm": gw_r_max["d_total"],
            "gw_r_one_day_total_storage_mm": 10.0 * gw_r_max["d_total"],
            "gw_r_one_day_terminal_bottom_flux_cm_per_day": gw_r_max["terminal_bottom_flux"],
            "gw_r_mean_signed_pair_exchange_difference_cm": mean_signed_one_day,
            "gw_r_abs_mean_signed_pair_exchange_difference_cm": abs(mean_signed_one_day),
            "gw_r_terminal_flux_sign_mismatch_count": gw_r_sign_mismatches,
            "gw_d_cum_bottom_cm": gw_d_max["cum_bottom"],
            "gw_d_terminal_bottom_flux_cm_per_day": gw_d_max["terminal_bottom_flux"],
            "gw_d_total_storage_cm": gw_d_max["d_total"],
            "gw_d_lower_storage_cm": gw_d_max["d_lower"],
            "gw_d_upper_storage_cm": gw_d_max["d_upper"],
            "gw_d_max_reversal_step_difference": max_reversal_steps,
            "gw_d_max_reversal_time_difference_minutes": (
                max_reversal_steps * STEP_DAY * 1440.0
            ),
            "gw_d_terminal_flux_sign_mismatch_count": gw_d_sign_mismatches,
            "reversal_sequence_mismatch_count": reversal_mismatches,
        }

        representation_results[cid] = {
            "roles": representation["roles"],
            "dimension": representation["dimension"],
            "depth_boundaries_cm": representation["depth_boundaries_cm"],
            "collision_counts": representation["collision_counts"],
            "pair_count": len(representation["pairs"]),
            "metrics": metrics,
            "reversal_summary": reversal_summary,
        }

    uniform_controls = [
        cid for cid in ("CONTROL_U4", "CONTROL_U8_Z8")
        if cid in representation_results
    ]
    relative = {}
    primary_relative = {}
    for cid, row in representation_results.items():
        if not cid.startswith("D"):
            continue
        relative[cid] = {}
        eligible = [
            control_id for control_id in uniform_controls
            if int(representation_results[control_id]["dimension"]) >= int(row["dimension"])
        ]
        for control_id in eligible:
            candidate_metrics = row["metrics"]
            control_metrics = representation_results[control_id]["metrics"]
            relative[cid][control_id] = {
                "GW_D": pareto_noninferior(
                    candidate_metrics, control_metrics, GW_D_PARETO_COMPONENTS
                ),
                "GW_R": pareto_noninferior(
                    candidate_metrics, control_metrics, GW_R_PARETO_COMPONENTS
                ),
            }

        if not eligible:
            continue
        primary_control = min(
            eligible,
            key=lambda control_id: int(representation_results[control_id]["dimension"]),
        )
        purpose = relative[cid][primary_control]
        primary_relative[cid] = {
            "primary_uniform_control": primary_control,
            "GW_D": purpose["GW_D"],
            "GW_R": purpose["GW_R"],
            "research_progression": {
                "GW_D": (
                    "STATE_INFORMATION_PROMISING_FOR_GW_D_DYNAMICS"
                    if purpose["GW_D"]["promising_relative_to_control"]
                    else "STATE_INFORMATION_NOT_BETTER_THAN_COARSE_CONTROL_FOR_GW_D"
                ),
                "GW_R": (
                    "STATE_INFORMATION_PROMISING_FOR_GW_R_DYNAMICS"
                    if purpose["GW_R"]["promising_relative_to_control"]
                    else "STATE_INFORMATION_NOT_BETTER_THAN_COARSE_CONTROL_FOR_GW_R"
                ),
            },
        }

    evidence_complete = all([
        raw == repeat,
        start_identity,
        endpoint_complete,
        step_complete,
        unique_start_marker == len(expected_starts),
        max_mass <= HARD_MASS_GATE_CM,
        "LAREGW2_EXECUTION_COMPLETE=PASS" in raw,
    ])

    result = {
        "schema": "swap5.lare.rs1.gw.p2.result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-RS1-GW-P2",
        "decision": (
            "LARE_RS1_GW_P2_PURPOSE_AMBIGUITY_MAPPED"
            if evidence_complete else
            "LARE_RS1_GW_P2_EVIDENCE_BLOCKED"
        ),
        "evidence_complete": evidence_complete,
        "repeat_stdout_bitwise_identity": raw == repeat,
        "start_state_identity_with_stage_A_library": start_identity,
        "start_identity_failures": start_identity_failures[:12],
        "unique_start_state_count": len(expected_starts),
        "endpoint_record_count": len(endpoint),
        "expected_endpoint_record_count": len(expected_endpoint),
        "step_series_count": len(steps),
        "expected_step_series_count": len(expected_step_keys),
        "max_abs_committed_mass_residual_cm": max_mass,
        "fallback_class_counts": dict(fallback_classes),
        "selection_rule_result": selection["selection_rule_result"],
        "representations": representation_results,
        "relative_to_uniform_controls_by_purpose": relative,
        "primary_relative_progression_by_purpose": primary_relative,
        "interpretation_note": (
            "GW_D and GW_R are adjudicated separately. Combining them into one "
            "Pareto verdict would contradict the preregistered purpose-dependent "
            "acceptance framework. Representation-specific adversarial pair sets "
            "are response-blind but not identical across representations, so "
            "relative maxima are research-progression diagnostics rather than "
            "pointwise error comparisons."
        ),
        "application_acceptance": {
            "absolute_ACCEPT_FOR_PURPOSE_adjudicated": False,
            "reason": (
                "P2 maps critical purpose errors and comparator dominance. "
                "Absolute acceptance requires an external application parameter "
                "set or downstream coupled-response authority."
            ),
            "GW_R_critical_head_screen_formula": (
                "local storage-equivalent screening head = "
                "max one-day cumulative exchange ambiguity / declared Sy; "
                "this is diagnostic only and not a groundwater-model response substitute"
            ),
            "fallback_decision_if_no_external_envelope": (
                "REFERENCE_OR_APPLICATION_ENVELOPE_NOT_YET_AUTHORITATIVE"
            ),
        },
        "supplemental_two_layer_pilot_used_for_thresholds": False,
        "pair_reselection_after_response": False,
        "lare_dynamics_executed": False,
        "production_rom_authorized": False,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "schema": result["schema"],
        "decision": result["decision"],
        "evidence_complete": evidence_complete,
        "selection_rule_result": selection["selection_rule_result"],
        "metrics": {
            cid: row["metrics"] for cid, row in representation_results.items()
        },
        "relative_to_uniform_controls_by_purpose": relative,
        "primary_relative_progression_by_purpose": primary_relative,
    }, sort_keys=True))
    return 0 if evidence_complete else 2


if __name__ == "__main__":
    raise SystemExit(main())