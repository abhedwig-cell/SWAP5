#!/usr/bin/env python3
from __future__ import annotations

import argparse
import itertools
import json
import math
import pathlib
from collections import defaultdict
from typing import Any

import numpy as np

FLOOR = 0.0005420462931603476
RADII = (0.25, 0.5, 1.0, 2.0, 4.0)
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


def quantiles(values: list[float]) -> dict[str, float | None]:
    if not values:
        return {"median": None, "p95": None, "maximum": None}
    arr = np.asarray(values, dtype=float)
    return {
        "median": float(np.median(arr)),
        "p95": float(np.quantile(arr, 0.95)),
        "maximum": float(np.max(arr)),
    }


def load_stage_profiles(
    path: pathlib.Path,
    expected: set[tuple[str, int]],
) -> dict[tuple[str, int], np.ndarray]:
    nodes: dict[tuple[str, int], list[float | None]] = {}
    for line in path.open(errors="replace"):
        if not line.startswith("LAREGW1_NODE|"):
            continue
        row = fields(line.split("|", 1)[1])
        key = (row["HISTORY"], int(row["STEP"]))
        if key not in expected:
            continue
        profile = nodes.setdefault(key, [None] * 16)
        profile[int(row["NODE"]) - 1] = float(row["THETA"])
    if set(nodes) != expected:
        missing = sorted(expected - set(nodes))
        raise SystemExit(f"missing stage profiles: {missing[:8]}")
    out = {}
    for key, values in nodes.items():
        if any(value is None for value in values):
            raise SystemExit(f"incomplete stage profile {key}")
        out[key] = np.asarray(values, dtype=float)
    return out


def load_p2_responses(
    path: pathlib.Path,
    expected: set[tuple[str, int]],
) -> tuple[
    dict[tuple[str, int, str, int], dict[str, float]],
    dict[tuple[str, int, str], list[tuple[int, float]]],
]:
    endpoint: dict[tuple[str, int, str, int], dict[str, float]] = {}
    steps: dict[tuple[str, int, str], list[tuple[int, float]]] = defaultdict(list)
    for line in path.open(errors="replace"):
        if line.startswith("LAREGW2_PROBE|"):
            row = fields(line.split("|", 1)[1])
            state = (row["HISTORY"], int(row["START_STEP"]))
            if state not in expected:
                continue
            key = (state[0], state[1], row["PROBE"], int(row["HORIZON_STEP"]))
            endpoint[key] = {
                "cum_bottom": float(row["CUM_BOTTOM_OUTWARD_EXCHANGE"]),
                "d_total": float(row["D_TOTAL_STORAGE"]),
                "d_upper": float(row["D_UPPER_STORAGE"]),
                "d_lower": float(row["D_LOWER_STORAGE"]),
                "terminal_bottom_flux": float(row["TERMINAL_BOTTOM_FLUX"]),
            }
        elif line.startswith("LAREGW2_STEP|"):
            row = fields(line.split("|", 1)[1])
            state = (row["HISTORY"], int(row["START_STEP"]))
            if state not in expected:
                continue
            key = (state[0], state[1], row["PROBE"])
            steps[key].append((int(row["STEP"]), float(row["BOTTOM_FLUX"])))
    return endpoint, steps


def representation_ends(p1: dict[str, Any], candidate_id: str) -> tuple[int, ...]:
    if candidate_id.startswith("D"):
        row = p1["selected_partitions"][candidate_id]
    elif candidate_id.startswith("CONTROL_"):
        row = p1["fixed_controls"][candidate_id.removeprefix("CONTROL_")]
    else:
        raise KeyError(candidate_id)
    return tuple(int(value) for value in row["end_indices"])


def projected_coordinate(profile: np.ndarray, ends: tuple[int, ...]) -> np.ndarray:
    values = []
    start = 0
    for end in ends:
        values.append(float(np.mean(profile[start:end])))
        start = end
    return np.asarray(values, dtype=float)


def response_summary(
    pairs: list[tuple[tuple[str, int], tuple[str, int]]],
    probes: list[str],
    endpoint: dict[tuple[str, int, str, int], dict[str, float]],
    steps: dict[tuple[str, int, str], list[tuple[int, float]]],
) -> dict[str, Any]:
    if not pairs:
        return {
            "status": "NO_ALIAS_IN_COMMON_COHORT",
            "pair_count": 0,
            "gw_d": None,
            "gw_r": None,
        }

    gw_d_cum: list[float] = []
    gw_d_total: list[float] = []
    gw_d_lower: list[float] = []
    gw_d_flux: list[float] = []
    gw_r_cum: list[float] = []
    gw_r_total: list[float] = []
    gw_r_signed: list[float] = []
    gw_d_sign_mismatch = 0
    gw_r_sign_mismatch = 0
    reversal_sequence_mismatch = 0
    reversal_step_differences: list[int] = []
    comparison_records_gwd = 0
    comparison_records_gwr = 0

    for a, b in pairs:
        for probe in probes:
            ra = reversal_steps(steps[(a[0], a[1], probe)])
            rb = reversal_steps(steps[(b[0], b[1], probe)])
            if len(ra) != len(rb):
                reversal_sequence_mismatch += 1
            else:
                reversal_step_differences.extend(abs(x - y) for x, y in zip(ra, rb))

            for horizon in GW_D_HORIZONS:
                ea = endpoint[(a[0], a[1], probe, horizon)]
                eb = endpoint[(b[0], b[1], probe, horizon)]
                gw_d_cum.append(abs(ea["cum_bottom"] - eb["cum_bottom"]))
                gw_d_total.append(abs(ea["d_total"] - eb["d_total"]))
                gw_d_lower.append(abs(ea["d_lower"] - eb["d_lower"]))
                gw_d_flux.append(abs(ea["terminal_bottom_flux"] - eb["terminal_bottom_flux"]))
                gw_d_sign_mismatch += int(
                    flux_sign(ea["terminal_bottom_flux"]) != flux_sign(eb["terminal_bottom_flux"])
                )
                comparison_records_gwd += 1

            ea = endpoint[(a[0], a[1], probe, GW_R_HORIZON)]
            eb = endpoint[(b[0], b[1], probe, GW_R_HORIZON)]
            signed = ea["cum_bottom"] - eb["cum_bottom"]
            gw_r_signed.append(signed)
            gw_r_cum.append(abs(signed))
            gw_r_total.append(abs(ea["d_total"] - eb["d_total"]))
            gw_r_sign_mismatch += int(
                flux_sign(ea["terminal_bottom_flux"]) != flux_sign(eb["terminal_bottom_flux"])
            )
            comparison_records_gwr += 1

    return {
        "status": "ALIASES_PRESENT",
        "pair_count": len(pairs),
        "gw_d": {
            "comparison_record_count": comparison_records_gwd,
            "cumulative_bottom_exchange_cm": quantiles(gw_d_cum),
            "total_storage_cm": quantiles(gw_d_total),
            "lower_40_160cm_storage_cm": quantiles(gw_d_lower),
            "terminal_bottom_flux_cm_per_day": quantiles(gw_d_flux),
            "terminal_flux_sign_mismatch_count": gw_d_sign_mismatch,
            "reversal_sequence_mismatch_pair_probe_count": reversal_sequence_mismatch,
            "maximum_reversal_step_difference_when_sequence_lengths_match": (
                max(reversal_step_differences) if reversal_step_differences else 0
            ),
            "maximum_reversal_time_difference_minutes_when_sequence_lengths_match": (
                max(reversal_step_differences) * STEP_DAY * 1440.0
                if reversal_step_differences else 0.0
            ),
        },
        "gw_r": {
            "comparison_record_count": comparison_records_gwr,
            "one_day_cumulative_bottom_exchange_cm": quantiles(gw_r_cum),
            "one_day_total_storage_cm": quantiles(gw_r_total),
            "mean_signed_one_day_pair_exchange_difference_cm": (
                float(np.mean(gw_r_signed)) if gw_r_signed else 0.0
            ),
            "terminal_flux_sign_mismatch_count": gw_r_sign_mismatch,
        },
    }


def dominance_vector(row: dict[str, Any]) -> dict[str, float] | None:
    if row["status"] != "ALIASES_PRESENT":
        return None
    return {
        "pair_count": float(row["pair_count"]),
        "gw_d_max_cum_bottom": float(row["gw_d"]["cumulative_bottom_exchange_cm"]["maximum"]),
        "gw_d_max_total_storage": float(row["gw_d"]["total_storage_cm"]["maximum"]),
        "gw_d_max_terminal_flux": float(row["gw_d"]["terminal_bottom_flux_cm_per_day"]["maximum"]),
        "gw_d_sign_mismatches": float(row["gw_d"]["terminal_flux_sign_mismatch_count"]),
        "gw_d_reversal_sequence_mismatches": float(row["gw_d"]["reversal_sequence_mismatch_pair_probe_count"]),
        "gw_d_max_reversal_steps": float(row["gw_d"]["maximum_reversal_step_difference_when_sequence_lengths_match"]),
        "gw_r_max_one_day_exchange": float(row["gw_r"]["one_day_cumulative_bottom_exchange_cm"]["maximum"]),
        "gw_r_max_one_day_storage": float(row["gw_r"]["one_day_total_storage_cm"]["maximum"]),
        "gw_r_sign_mismatches": float(row["gw_r"]["terminal_flux_sign_mismatch_count"]),
    }


def compare_dominance(a: dict[str, Any], b: dict[str, Any]) -> dict[str, Any]:
    va = dominance_vector(a)
    vb = dominance_vector(b)
    if va is None or vb is None:
        return {
            "comparable": False,
            "reason": "at least one representation has no reduction-induced alias in this common cohort radius",
        }
    component = {name: va[name] <= vb[name] for name in va}
    strict = any(va[name] < vb[name] for name in va)
    return {
        "comparable": True,
        "noninferior_all_components": all(component.values()),
        "strictly_better_at_least_one_component": strict,
        "dominates": all(component.values()) and strict,
        "component_noninferiority": component,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stage-a", required=True, type=pathlib.Path)
    ap.add_argument("--p2-output", required=True, type=pathlib.Path)
    ap.add_argument("--p2-selection", required=True, type=pathlib.Path)
    ap.add_argument("--p1-result", required=True, type=pathlib.Path)
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    prereg = json.loads(args.prereg.read_text())
    selection = json.loads(args.p2_selection.read_text())
    p1 = json.loads(args.p1_result.read_text())

    assert prereg["phase"] == "PREREGISTERED_BEFORE_COMMON_COHORT_CROSS_PAIR_RESPONSE_ANALYSIS"
    assert prereg["pre_execution_alias_clarification"]["before_first_P2C_cross_pair_response_analysis"] is True
    assert selection["response_used_for_selection"] is False
    assert selection["unique_start_state_count"] == 41
    assert p1["future_probe_response_used"] is False

    starts = [(row["history"], int(row["step"])) for row in selection["start_rows"]]
    start_set = set(starts)
    if len(starts) != 41 or len(start_set) != 41:
        raise SystemExit("common cohort is not exactly 41 unique states")

    profiles = load_stage_profiles(args.stage_a, start_set)
    endpoint, steps = load_p2_responses(args.p2_output, start_set)
    probes = [row["id"] for row in json.loads(
        pathlib.Path("integration/f-rom/LARE_RS1_GW_P2_PREREGISTRATION.json").read_text()
    )["future_probes"]["definitions"]]

    expected_endpoints = 41 * len(probes) * 4
    expected_steps = 41 * len(probes)
    if len(endpoint) != expected_endpoints:
        raise SystemExit(f"endpoint structure mismatch {len(endpoint)} != {expected_endpoints}")
    if len(steps) != expected_steps or any(len(rows) != 1250 for rows in steps.values()):
        raise SystemExit("step-series structure mismatch")

    common_pairs = [
        (a, b)
        for a, b in itertools.combinations(sorted(starts), 2)
        if a[0] != b[0]
    ]

    full_distance = {
        (a, b): float(np.max(np.abs(profiles[a] - profiles[b])))
        for a, b in common_pairs
    }
    full_near = [(a, b) for a, b in common_pairs if full_distance[(a, b)] <= FLOOR]
    full_diag = [(a, b) for a, b in common_pairs if full_distance[(a, b)] > FLOOR]

    representation_results: dict[str, Any] = {}
    for cid in prereg["representations"]:
        ends = representation_ends(p1, cid)
        coords = {state: projected_coordinate(profiles[state], ends) for state in starts}
        distances = {
            (a, b): float(np.max(np.abs(coords[a] - coords[b])))
            for a, b in common_pairs
        }
        by_radius = {}
        previous_pairs: set[tuple[tuple[str, int], tuple[str, int]]] = set()
        previous_maxima: dict[str, float] | None = None

        for multiplier in RADII:
            alias_pairs = [
                (a, b) for a, b in full_diag
                if distances[(a, b)] <= multiplier * FLOOR
            ]
            alias_set = set(alias_pairs)
            if not previous_pairs.issubset(alias_set):
                raise SystemExit(f"nonmonotone pair set for {cid} at {multiplier}")
            summary = response_summary(alias_pairs, probes, endpoint, steps)
            summary["radius_multiplier"] = multiplier
            summary["radius_theta"] = multiplier * FLOOR
            summary["common_cohort_close_pair_count"] = len(alias_pairs)
            summary["fraction_of_full_diagnostic_common_pairs_marked_close"] = (
                len(alias_pairs) / len(full_diag) if full_diag else 0.0
            )

            if summary["status"] == "ALIASES_PRESENT":
                maxima = {
                    "gwd_cum": summary["gw_d"]["cumulative_bottom_exchange_cm"]["maximum"],
                    "gwd_total": summary["gw_d"]["total_storage_cm"]["maximum"],
                    "gwd_flux": summary["gw_d"]["terminal_bottom_flux_cm_per_day"]["maximum"],
                    "gwr_cum": summary["gw_r"]["one_day_cumulative_bottom_exchange_cm"]["maximum"],
                    "gwr_total": summary["gw_r"]["one_day_total_storage_cm"]["maximum"],
                }
                if previous_maxima is not None:
                    for name, value in maxima.items():
                        if value + 1e-15 < previous_maxima[name]:
                            raise SystemExit(f"nonmonotone maximum {cid} {multiplier} {name}")
                previous_maxima = maxima
            by_radius[str(multiplier)] = summary
            previous_pairs = alias_set

        representation_results[cid] = {
            "dimension": len(ends),
            "end_indices": list(ends),
            "depth_boundaries_cm": [0] + [10 * value for value in ends],
            "by_radius": by_radius,
        }

    baseline = response_summary(full_near, probes, endpoint, steps)
    baseline["pair_count"] = len(full_near)
    baseline["role"] = "FULL_STATE_NEAR_IDENTICAL_BASELINE_NOT_REDUCTION_INDUCED"

    dominance = {}
    for multiplier in RADII:
        key = str(multiplier)
        dominance[key] = {}
        ids = prereg["representations"]
        for a in ids:
            dominance[key][a] = {}
            for b in ids:
                if a == b:
                    continue
                dominance[key][a][b] = compare_dominance(
                    representation_results[a]["by_radius"][key],
                    representation_results[b]["by_radius"][key],
                )

    result = {
        "schema": "swap5.lare.rs1.gw.p2c.result.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-RS1-GW-P2C",
        "decision": "LARE_RS1_GW_P2C_COMMON_COHORT_AMBIGUITY_MAPPED",
        "cohort": {
            "unique_state_count": len(starts),
            "cross_history_pair_count": len(common_pairs),
            "full_state_near_identical_pair_count": len(full_near),
            "full_state_diagnostic_pair_count": len(full_diag),
            "response_blind_state_source": "formal P2 selection",
            "candidate_enriched": True,
            "population_probability_claim_authorized": False,
        },
        "full_state_near_identical_baseline": baseline,
        "representations": representation_results,
        "common_cohort_dominance": dominance,
        "interpretation_firewalls": [
            "All representations are evaluated on one frozen 41-state cohort and one common cross-history pair universe.",
            "Reduction-induced alias metrics exclude pairs already indistinguishable at the frozen full-state diagnostic floor.",
            "The cohort is candidate-enriched and does not estimate real-world alias frequency.",
            "No absolute application acceptance threshold is applied.",
            "No LARE dynamics or reduced propagation model is executed."
        ],
        "absolute_application_acceptance_adjudicated": False,
        "lare_dynamics_executed": False,
        "production_rom_authorized": False,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "schema": result["schema"],
        "decision": result["decision"],
        "cohort": result["cohort"],
        "radius_1x": {
            cid: {
                "pair_count": row["by_radius"]["1.0"]["pair_count"],
                "gw_d_max_bottom_cm": (
                    row["by_radius"]["1.0"]["gw_d"]["cumulative_bottom_exchange_cm"]["maximum"]
                    if row["by_radius"]["1.0"]["gw_d"] else None
                ),
                "gw_r_max_day_cm": (
                    row["by_radius"]["1.0"]["gw_r"]["one_day_cumulative_bottom_exchange_cm"]["maximum"]
                    if row["by_radius"]["1.0"]["gw_r"] else None
                ),
                "reversal_mismatch": (
                    row["by_radius"]["1.0"]["gw_d"]["reversal_sequence_mismatch_pair_probe_count"]
                    if row["by_radius"]["1.0"]["gw_d"] else None
                ),
            }
            for cid, row in representation_results.items()
        }
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
