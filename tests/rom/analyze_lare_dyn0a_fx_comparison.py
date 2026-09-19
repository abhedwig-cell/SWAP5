#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import pathlib
import re
from collections import defaultdict

SE_BY_INDEX = {1: 0.65, 2: 0.85, 3: 0.95}
FORCING_BY_INDEX = {1: "EQ", 2: "WET", 3: "DRY", 4: "WET_DRY"}
PARTITIONS = {
    "D3": [0.0, 140.0, 150.0, 160.0],
    "D2": [0.0, 150.0, 160.0],
}
THETA_R = 0.02
THETA_S = 0.427494


def fields(payload: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for item in payload.split("|"):
        if "=" in item:
            key, value = item.split("=", 1)
            out[key] = value
    return out


def case_from_reference(case_id: str, partition: str) -> str:
    match = re.fullmatch(r"S([123])_B1_F([1234])", case_id)
    if not match:
        raise ValueError(case_id)
    se = SE_BY_INDEX[int(match.group(1))]
    forcing = FORCING_BY_INDEX[int(match.group(2))]
    return f"{partition}_SE{int(round(100*se)):03d}_FIXED_FLUX_{forcing}"


def load_status(path: pathlib.Path) -> dict[str, dict[str, dict[str, object]]]:
    payload = json.loads(path.read_text())
    if payload["decision"] != "LARE_DYN0A_FX_REFERENCE_CASES_CHARACTERIZED":
        raise SystemExit("wrong Reference status decision")
    return payload["geometries"]


def load_reference_case(path: pathlib.Path) -> dict[int, list[dict[str, float]]]:
    rows: dict[int, list[dict[str, float]]] = defaultdict(list)
    for line in path.open(errors="replace"):
        if not line.startswith("LAREDYN0R_NODE|"):
            continue
        row = fields(line.split("|", 1)[1])
        rows[int(row["STEP"])].append({
            "node": int(row["NODE"]),
            "z": float(row["Z"]),
            "dz": float(row["DZ"]),
            "theta": float(row["THETA"]),
        })
    for step in rows:
        rows[step].sort(key=lambda r: r["node"])
    return rows


def project_storage(
    rows: list[dict[str, float]],
    boundaries: list[float],
) -> list[float]:
    result = []
    for lo, hi in zip(boundaries, boundaries[1:]):
        storage = 0.0
        covered = 0.0
        for row in rows:
            center_depth = abs(row["z"])
            top = center_depth - 0.5 * row["dz"]
            bottom = center_depth + 0.5 * row["dz"]
            overlap = max(0.0, min(hi, bottom) - max(lo, top))
            if overlap > 0.0:
                storage += row["theta"] * overlap
                covered += overlap
        if abs(covered - (hi - lo)) > 1.0e-9:
            raise SystemExit(
                f"projection coverage {covered} != {hi-lo} for band {lo}-{hi}"
            )
        result.append(storage)
    return result


def storage_series(
    ref_dir: pathlib.Path,
    geometry: str,
    case_id: str,
    boundaries: list[float],
) -> list[list[float]]:
    path = ref_dir / f"{geometry}-{case_id}-o2.txt"
    if not path.exists():
        raise SystemExit(f"missing Reference case file {path}")
    rows = load_reference_case(path)
    if set(rows) != set(range(1, 1025)):
        raise SystemExit(f"incomplete qualified case {geometry} {case_id}")
    return [project_storage(rows[step], boundaries) for step in range(1, 1025)]


def metrics(candidate: list[list[float]], reference: list[list[float]]) -> dict[str, object]:
    if len(candidate) != len(reference):
        raise SystemExit("trajectory length mismatch")
    if not candidate:
        raise SystemExit("empty trajectory")
    nlayer = len(reference[0])
    diffs = [
        [float(c) - float(r) for c, r in zip(crow, rrow)]
        for crow, rrow in zip(candidate, reference)
    ]
    abs_all = [abs(v) for row in diffs for v in row]
    per_layer_max = [
        max(abs(row[i]) for row in diffs)
        for i in range(nlayer)
    ]
    per_layer_mean = [
        sum(abs(row[i]) for row in diffs) / len(diffs)
        for i in range(nlayer)
    ]
    final_signed = diffs[-1]
    return {
        "max_abs_layer_storage_cm": max(abs_all),
        "mean_abs_layer_storage_cm": sum(abs_all) / len(abs_all),
        "max_abs_bottom_layer_storage_cm": per_layer_max[-1],
        "mean_abs_bottom_layer_storage_cm": per_layer_mean[-1],
        "per_layer_max_abs_storage_cm": per_layer_max,
        "per_layer_mean_abs_storage_cm": per_layer_mean,
        "final_signed_layer_storage_cm": final_signed,
    }


def winner(left: float, right: float, tol: float = 1.0e-15) -> str:
    if left < right - tol:
        return "LARE"
    if right < left - tol:
        return "COARSE_RICHARDS"
    return "TIE"


def initial_theta(se: float) -> float:
    return THETA_R + se * (THETA_S - THETA_R)


def seed_drift_diagnostic(ref_dir: pathlib.Path, geometry: str, case_id: str) -> dict[str, float]:
    match = re.fullmatch(r"S([123])_B1_F1", case_id)
    if not match:
        raise ValueError(case_id)
    se = SE_BY_INDEX[int(match.group(1))]
    theta0 = initial_theta(se)
    rows = load_reference_case(ref_dir / f"{geometry}-{case_id}-o2.txt")
    first = rows[1]
    max_theta_drift = max(abs(row["theta"] - theta0) for row in first)
    return {
        "initial_theta": theta0,
        "max_abs_theta_difference_at_first_eq_observation": max_theta_drift,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ode", required=True, type=pathlib.Path)
    ap.add_argument("--reference-dir", required=True, type=pathlib.Path)
    ap.add_argument("--reference-status", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    args = ap.parse_args()

    ode = json.loads(args.ode.read_text())
    if ode["decision"] != "LARE_DYN0A_HEUN_REFINEMENT_CHARACTERIZED":
        raise SystemExit("wrong ODE decision")
    status = load_status(args.reference_status)

    per_partition = {}
    for partition in ("D3", "D2"):
        boundaries = PARTITIONS[partition]
        coarse_geometry = partition.lower()
        cases = []
        exclusions = []
        win_counts = {
            "max_abs_layer_storage_cm": {"LARE": 0, "COARSE_RICHARDS": 0, "TIE": 0},
            "mean_abs_layer_storage_cm": {"LARE": 0, "COARSE_RICHARDS": 0, "TIE": 0},
            "max_abs_bottom_layer_storage_cm": {"LARE": 0, "COARSE_RICHARDS": 0, "TIE": 0},
        }

        for ref_case in sorted(status["fine"]):
            lare_id = case_from_reference(ref_case, partition)
            lare_case = ode["cases"][lare_id]
            fine_status = status["fine"][ref_case]["status"]
            coarse_status = status[coarse_geometry][ref_case]["status"]
            lare_status = lare_case["status"]
            if not (
                fine_status == "QUALIFIED"
                and coarse_status == "QUALIFIED"
                and lare_status == "QUALIFIED"
            ):
                exclusions.append({
                    "reference_case": ref_case,
                    "lare_case": lare_id,
                    "fine_reference_status": fine_status,
                    "coarse_reference_status": coarse_status,
                    "lare_status": lare_status,
                    "exclusion_reason": "COMMON_QUALIFIED_COHORT_RULE",
                })
                continue

            fine = storage_series(args.reference_dir, "fine", ref_case, boundaries)
            coarse = storage_series(
                args.reference_dir, coarse_geometry, ref_case, boundaries
            )
            lare_full = lare_case["finest_reference"]["layer_storage_cm"]
            if len(lare_full) != 1025:
                raise SystemExit(f"unexpected LARE trajectory length {lare_id}")
            lare = [[float(v) for v in row] for row in lare_full[1:]]

            lare_metrics = metrics(lare, fine)
            coarse_metrics = metrics(coarse, fine)
            verdicts = {}
            for name in win_counts:
                verdict = winner(
                    float(lare_metrics[name]), float(coarse_metrics[name])
                )
                win_counts[name][verdict] += 1
                verdicts[name] = verdict

            cases.append({
                "reference_case": ref_case,
                "lare_case": lare_id,
                "lare_vs_fine": lare_metrics,
                "coarse_richards_vs_fine": coarse_metrics,
                "paired_verdict": verdicts,
            })

        def aggregate(model_key: str, metric: str) -> dict[str, float | None]:
            vals = [float(row[model_key][metric]) for row in cases]
            if not vals:
                return {"maximum": None, "mean": None}
            return {"maximum": max(vals), "mean": sum(vals) / len(vals)}

        per_partition[partition] = {
            "depth_boundaries_cm": boundaries,
            "common_qualified_case_count": len(cases),
            "excluded_case_count": len(exclusions),
            "excluded_cases": exclusions,
            "cases": cases,
            "paired_win_counts": win_counts,
            "aggregate": {
                "LARE": {
                    name: aggregate("lare_vs_fine", name)
                    for name in win_counts
                },
                "COARSE_RICHARDS": {
                    name: aggregate("coarse_richards_vs_fine", name)
                    for name in win_counts
                },
            },
        }

    seed = {}
    for geom in ("fine", "d3", "d2"):
        seed[geom] = {}
        for sidx in (1, 2, 3):
            cid = f"S{sidx}_B1_F1"
            if status[geom][cid]["status"] == "QUALIFIED":
                seed[geom][cid] = seed_drift_diagnostic(args.reference_dir, geom, cid)

    result = {
        "schema": "swap5.lare.dyn0a.fx.comparison.v1",
        "workstream": "F-ROM-LARE",
        "work_unit": "LARE-DYN0A-FX",
        "decision": "LARE_DYN0A_FX_COMMON_COHORT_COMPARISON_MAPPED",
        "comparison_basis": (
            "For each fixed partition, LARE and equal-partition coarse Richards "
            "are compared against the same projection of fine 16x10 cm Reference "
            "Richards. Only cases qualified in all three routes enter the paired "
            "comparison."
        ),
        "fixed_flux_interpretation": (
            "Layer-storage redistribution is the discriminating quantity. Total "
            "storage and prescribed bottom exchange are ledger controls because "
            "both boundary fluxes are imposed and no sinks are active."
        ),
        "partitions": per_partition,
        "seed_drift_diagnostic": seed,
        "absolute_application_acceptance_adjudicated": False,
        "speed_claim": False,
        "D4_executed": False,
        "production_rom_authorized": False,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "schema": result["schema"],
        "decision": result["decision"],
        "D3_common": per_partition["D3"]["common_qualified_case_count"],
        "D3_wins": per_partition["D3"]["paired_win_counts"],
        "D2_common": per_partition["D2"]["common_qualified_case_count"],
        "D2_wins": per_partition["D2"]["paired_win_counts"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
