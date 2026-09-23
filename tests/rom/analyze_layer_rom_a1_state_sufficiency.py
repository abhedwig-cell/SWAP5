#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
import pathlib
from collections import defaultdict
from typing import Any

import numpy as np

EXPECTED_STATES = 41


def fields(payload: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for part in payload.split("|"):
        if "=" in part:
            key, value = part.split("=", 1)
            out[key] = value
    return out


def quantiles(values: list[float]) -> dict[str, float | None]:
    if not values:
        return {"median": None, "p95": None, "maximum": None}
    a = np.asarray(values, dtype=float)
    return {
        "median": float(np.median(a)),
        "p95": float(np.quantile(a, 0.95)),
        "maximum": float(np.max(a)),
    }


def flux_sign(value: float) -> int:
    return 1 if value > 0.0 else (-1 if value < 0.0 else 0)


def reversal_steps(rows: list[tuple[int, float]]) -> list[int]:
    events: list[int] = []
    previous = 0
    for step, value in sorted(rows):
        current = flux_sign(value)
        if current == 0:
            continue
        if previous and current != previous:
            events.append(step)
        previous = current
    return events


def load_start_profiles(path: pathlib.Path, expected: set[tuple[str, int]]) -> dict[tuple[str, int], np.ndarray]:
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
        raise SystemExit(f"missing Stage-A starts: {sorted(expected-set(nodes))[:8]}")
    out: dict[tuple[str, int], np.ndarray] = {}
    for key, values in nodes.items():
        if any(v is None for v in values):
            raise SystemExit(f"incomplete profile {key}")
        out[key] = np.asarray(values, dtype=float)
    return out


def load_probe_output(path: pathlib.Path, expected: set[tuple[str, int]]):
    endpoint: dict[tuple[str, int, str, int], dict[str, float]] = {}
    series: dict[tuple[str, int, str], list[tuple[int, float]]] = defaultdict(list)
    for line in path.open(errors="replace"):
        if line.startswith("LAREGW2_PROBE|"):
            row = fields(line.split("|", 1)[1])
            state = (row["HISTORY"], int(row["START_STEP"]))
            if state not in expected:
                continue
            endpoint[(state[0], state[1], row["PROBE"], int(row["HORIZON_STEP"]))] = {
                "cum_bottom": float(row["CUM_BOTTOM_OUTWARD_EXCHANGE"]),
                "d_total": float(row["D_TOTAL_STORAGE"]),
                "d_lower": float(row["D_LOWER_STORAGE"]),
                "terminal_bottom_flux": float(row["TERMINAL_BOTTOM_FLUX"]),
            }
        elif line.startswith("LAREGW2_STEP|"):
            row = fields(line.split("|", 1)[1])
            state = (row["HISTORY"], int(row["START_STEP"]))
            if state not in expected:
                continue
            series[(state[0], state[1], row["PROBE"])].append(
                (int(row["STEP"]), float(row["BOTTOM_FLUX"]))
            )
    return endpoint, series


def project(profile: np.ndarray, ends: tuple[int, ...]) -> np.ndarray:
    vals = []
    start = 0
    for end in ends:
        vals.append(float(np.mean(profile[start:end])))
        start = end
    return np.asarray(vals, dtype=float)


def reconstruct(coord: np.ndarray, ends: tuple[int, ...]) -> np.ndarray:
    out = np.empty(16, dtype=float)
    start = 0
    for value, end in zip(coord, ends):
        out[start:end] = value
        start = end
    return out


def response_summary(
    pairs: list[tuple[tuple[str, int], tuple[str, int]]],
    probes: list[str],
    endpoint: dict[tuple[str, int, str, int], dict[str, float]],
    series: dict[tuple[str, int, str], list[tuple[int, float]]],
    gwd_horizons: list[int],
    gwr_horizon: int,
    step_day: float,
) -> dict[str, Any]:
    if not pairs:
        return {"status": "NO_REDUCTION_INDUCED_ALIAS_IN_COMMON_COHORT", "pair_count": 0}

    gwd_cum: list[float] = []
    gwd_total: list[float] = []
    gwd_lower: list[float] = []
    gwd_flux: list[float] = []
    gwr_cum: list[float] = []
    gwr_total: list[float] = []
    gwr_signed: list[float] = []
    gwd_sign = 0
    gwr_sign = 0
    rev_mismatch = 0
    rev_step_diff: list[int] = []

    for a, b in pairs:
        for probe in probes:
            ra = reversal_steps(series[(a[0], a[1], probe)])
            rb = reversal_steps(series[(b[0], b[1], probe)])
            if len(ra) != len(rb):
                rev_mismatch += 1
            else:
                rev_step_diff.extend(abs(x-y) for x, y in zip(ra, rb))
            for horizon in gwd_horizons:
                ea = endpoint[(a[0], a[1], probe, horizon)]
                eb = endpoint[(b[0], b[1], probe, horizon)]
                gwd_cum.append(abs(ea["cum_bottom"]-eb["cum_bottom"]))
                gwd_total.append(abs(ea["d_total"]-eb["d_total"]))
                gwd_lower.append(abs(ea["d_lower"]-eb["d_lower"]))
                gwd_flux.append(abs(ea["terminal_bottom_flux"]-eb["terminal_bottom_flux"]))
                gwd_sign += int(flux_sign(ea["terminal_bottom_flux"]) != flux_sign(eb["terminal_bottom_flux"]))
            ea = endpoint[(a[0], a[1], probe, gwr_horizon)]
            eb = endpoint[(b[0], b[1], probe, gwr_horizon)]
            signed = ea["cum_bottom"]-eb["cum_bottom"]
            gwr_signed.append(signed)
            gwr_cum.append(abs(signed))
            gwr_total.append(abs(ea["d_total"]-eb["d_total"]))
            gwr_sign += int(flux_sign(ea["terminal_bottom_flux"]) != flux_sign(eb["terminal_bottom_flux"]))

    return {
        "status": "ALIASES_PRESENT",
        "pair_count": len(pairs),
        "GW_D": {
            "cumulative_bottom_exchange_cm": quantiles(gwd_cum),
            "total_storage_cm": quantiles(gwd_total),
            "lower_40_160_storage_cm": quantiles(gwd_lower),
            "terminal_bottom_flux_cm_per_day": quantiles(gwd_flux),
            "terminal_flux_sign_mismatch_count": gwd_sign,
            "reversal_sequence_mismatch_pair_probe_count": rev_mismatch,
            "maximum_reversal_step_difference_when_sequence_lengths_match": max(rev_step_diff) if rev_step_diff else 0,
            "maximum_reversal_time_minutes_when_sequence_lengths_match": (max(rev_step_diff)*step_day*1440.0) if rev_step_diff else 0.0,
        },
        "GW_R": {
            "one_day_cumulative_bottom_exchange_cm": quantiles(gwr_cum),
            "one_day_total_storage_cm": quantiles(gwr_total),
            "mean_signed_one_day_pair_exchange_difference_cm": float(np.mean(gwr_signed)) if gwr_signed else 0.0,
            "abs_mean_signed_one_day_pair_exchange_difference_cm": abs(float(np.mean(gwr_signed))) if gwr_signed else 0.0,
            "terminal_flux_sign_mismatch_count": gwr_sign,
        },
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stage-a", required=True, type=pathlib.Path)
    ap.add_argument("--probe-output", required=True, type=pathlib.Path)
    ap.add_argument("--selection", required=True, type=pathlib.Path)
    ap.add_argument("--prereg", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    prereg = json.loads(args.prereg.read_text())
    selection = json.loads(args.selection.read_text())
    if prereg["phase"] != "PREREGISTERED_BEFORE_LAYER_RESPONSE_REPLAY":
        raise SystemExit("wrong Layer-ROM preregistration phase")
    if selection["future_response_used"] is not False or selection["pair_reselection"] is not False:
        raise SystemExit("P2 selection is not response blind")
    starts = [(row["history"], int(row["step"])) for row in selection["start_rows"]]
    if len(starts) != EXPECTED_STATES or len(set(starts)) != EXPECTED_STATES:
        raise SystemExit("unexpected common cohort")
    start_set = set(starts)

    floor = float(prereg["diagnostic_state_scale"]["B01_theta_floor"])
    radii = [float(x) for x in prereg["diagnostic_state_scale"]["radii_multipliers"]]
    probes = list(prereg["future_response_common_cohort"]["probes"])
    gwd_horizons = [int(x) for x in prereg["future_response_common_cohort"]["GW_D_horizons_steps"]]
    gwr_horizon = int(prereg["future_response_common_cohort"]["GW_R_horizon_steps"][0])
    step_day = 0.0008

    profiles = load_start_profiles(args.stage_a, start_set)
    endpoint, series = load_probe_output(args.probe_output, start_set)

    expected_endpoints = EXPECTED_STATES * len(probes) * (len(gwd_horizons)+1)
    expected_series = EXPECTED_STATES * len(probes)
    if len(endpoint) != expected_endpoints:
        raise SystemExit(f"endpoint count {len(endpoint)} != {expected_endpoints}")
    if len(series) != expected_series or any(len(v) != gwr_horizon for v in series.values()):
        raise SystemExit("probe step-series structure mismatch")

    pairs = [(a,b) for a,b in itertools.combinations(sorted(starts),2) if a[0] != b[0]]
    full_dist = {(a,b): float(np.max(np.abs(profiles[a]-profiles[b]))) for a,b in pairs}
    full_diag = [(a,b) for a,b in pairs if full_dist[(a,b)] > floor]
    full_near = [(a,b) for a,b in pairs if full_dist[(a,b)] <= floor]

    results: dict[str, Any] = {}
    for spec in prereg["representations"]:
        rid = spec["id"]
        ends = tuple(int(x) for x in spec["end_indices"])
        coords = {s: project(profiles[s], ends) for s in starts}
        reduced_dist = {(a,b): float(np.max(np.abs(coords[a]-coords[b]))) for a,b in pairs}

        rmses, maxabs = [], []
        for s in starts:
            rec = reconstruct(coords[s], ends)
            delta = rec - profiles[s]
            rmses.append(float(np.sqrt(np.mean(delta*delta))))
            maxabs.append(float(np.max(np.abs(delta))))

        by_radius: dict[str, Any] = {}
        previous: set[tuple[tuple[str,int],tuple[str,int]]] = set()
        for radius in radii:
            alias = [(a,b) for a,b in full_diag if reduced_dist[(a,b)] <= radius*floor]
            aset = set(alias)
            if not previous.issubset(aset):
                raise SystemExit(f"nonmonotone aliases for {rid} at radius {radius}")
            summary = response_summary(alias, probes, endpoint, series, gwd_horizons, gwr_horizon, step_day)
            summary["radius_multiplier"] = radius
            summary["radius_theta"] = radius*floor
            summary["common_cohort_close_pair_count"] = len(alias)
            summary["fraction_of_full_diagnostic_common_pairs_marked_close"] = len(alias)/len(full_diag) if full_diag else 0.0
            summary["hidden_full_profile_theta_linf"] = quantiles([full_dist[p] for p in alias])
            by_radius[str(radius)] = summary
            previous = aset

        results[rid] = {
            "class": spec["class"],
            "dimension": len(ends),
            "end_indices": list(ends),
            "depth_boundaries_cm": spec["depth_boundaries_cm"],
            "current_profile_piecewise_constant_reconstruction": {
                "theta_rmse": quantiles(rmses),
                "theta_max_abs": quantiles(maxabs),
                "role": "secondary reconstruction diagnostic, not state-sufficiency acceptance"
            },
            "by_radius": by_radius,
        }

    result = {
        "schema": "swap5.layer-rom.phase-a.state-sufficiency-result.v1",
        "workstream": "F-ROM-LAYER",
        "work_unit": "LAYER-ROM-A1",
        "decision": "LAYER_ROM_A1_STATE_RESPONSE_REPLAY_COMPLETE",
        "evidence_class": "IMMUTABLE_REUSE_PARTLY_EXPOSED_DEVELOPMENT_EVIDENCE_NOT_BLIND_VALIDATION",
        "inputs": {
            "stage_a_sha256": hashlib.sha256(args.stage_a.read_bytes()).hexdigest(),
            "probe_output_sha256": hashlib.sha256(args.probe_output.read_bytes()).hexdigest(),
            "selection_sha256": hashlib.sha256(args.selection.read_bytes()).hexdigest(),
            "start_state_count": len(starts),
            "cross_history_pair_count": len(pairs),
            "full_state_diagnostic_pair_count": len(full_diag),
            "full_state_near_identical_pair_count": len(full_near),
        },
        "representations": results,
        "full_state_near_identical_baseline": response_summary(full_near, probes, endpoint, series, gwd_horizons, gwr_horizon, step_day),
        "error_attribution": {
            "measured_here": "state_information_error only",
            "not_measured_here": ["closure_error","numerical_discretization_error"],
            "reason": "all response trajectories are full Reference futures; no reduced propagation model is executed"
        },
        "interpretation_firewalls": [
            "No single aggregate score is computed.",
            "No application acceptance threshold is applied.",
            "D2/D3/D4-related state evidence was partly exposed in the predecessor LARE branch, so this replay is not blind confirmation.",
            "L6 and same-dimension controls are frozen before this replay but remain development evidence because the common cohort and future-probe library pre-exist.",
            "Zero aliases in this 41-state candidate-enriched cohort do not establish global sufficiency.",
            "No LARE, FMC, CoRichards or production ROM dynamics are executed."
        ],
        "production_rom_authorized": False,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True)+"\n")
    print(json.dumps({
        "decision": result["decision"],
        "inputs": result["inputs"],
        "radius_1x": {
            rid: {
                "pairs": row["by_radius"]["1.0"]["pair_count"],
                "gwd_flux_max": (row["by_radius"]["1.0"].get("GW_D") or {}).get("terminal_bottom_flux_cm_per_day",{}).get("maximum"),
                "gwr_exchange_max": (row["by_radius"]["1.0"].get("GW_R") or {}).get("one_day_cumulative_bottom_exchange_cm",{}).get("maximum")
            } for rid,row in results.items()
        }
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
