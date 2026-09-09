#!/usr/bin/env python3
"""Emit machine-readable F-SI21 evidence from the deterministic characterization log.

This parser is deliberately test-only.  It does not select a production temporal
metric, scalarization or tolerance.  It summarizes the predeclared F-SI21
same-endpoint characterization markers so the exact CI observation can be
persisted and audited without relying on ephemeral Actions stdout.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import re
import statistics
import sys
from collections import Counter, defaultdict
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"FSI21_EVIDENCE_EMITTER_FAIL {message}")


def fields(line: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for part in line.split(":"):
        if "=" in part:
            key, value = part.split("=", 1)
            out[key.strip()] = value.strip()
    return out


def as_bool(value: str) -> bool:
    if value in {"T", "PASS", "TRUE"}:
        return True
    if value in {"F", "FAIL", "FALSE"}:
        return False
    fail(f"invalid boolean marker {value!r}")


def finite_float(value: str) -> float:
    x = float(value)
    if not math.isfinite(x):
        fail(f"non-finite numeric marker {value!r}")
    return x


def numeric_stats(values: list[float]) -> dict[str, float] | None:
    if not values:
        return None
    return {
        "count": len(values),
        "minimum": min(values),
        "median": statistics.median(values),
        "maximum": max(values),
    }


def main() -> None:
    if len(sys.argv) != 3:
        fail("usage: fsi21_emit_characterization_evidence.py LOG OUTPUT_JSON")

    log_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    raw = log_path.read_bytes()
    text = raw.decode("utf-8")
    lines = text.splitlines()

    required_exact = [
        "FSI21_SOURCE_AND_CANDIDATE_MATRIX_LOCK=PASS",
        "FSI21_REFERENCE_TRIDAG=PASS",
        "FSI21_REPEAT_o0=PASS",
        "FSI21_REPEAT_o2=PASS",
        "FSI21_O0_O2_IDENTITY=PASS",
        "FSI21_SAME_ENDPOINT_CHARACTERIZATION_COMPLETE=PASS",
        "FSI21_PRODUCTION_SOURCE_UNCHANGED=PASS",
    ]
    missing_exact = [marker for marker in required_exact if marker not in lines]
    if missing_exact:
        fail(f"missing completion markers: {missing_exact}")

    driver_line = next((line for line in lines if line.startswith("FSI21_DRIVER PASS ")), None)
    if driver_line is None:
        fail("missing FSI21_DRIVER PASS marker")
    driver_match = re.fullmatch(r"FSI21_DRIVER PASS CASES=(\d+):TRAJECTORIES=(\d+):ROWS=(\d+)", driver_line)
    if driver_match is None:
        fail(f"malformed driver marker: {driver_line}")
    cases, driver_trajectories, driver_rows = map(int, driver_match.groups())

    rows_line = next((line for line in lines if line.startswith("FSI21_ROWS=")), None)
    if rows_line is None:
        fail("missing FSI21_ROWS summary")
    rows_match = re.fullmatch(
        r"FSI21_ROWS=(\d+):TRAJECTORIES=(\d+):SOLVER_FAILURE_ROWS=(\d+):MASS_FAILURE_ROWS=(\d+)",
        rows_line,
    )
    if rows_match is None:
        fail(f"malformed rows summary: {rows_line}")
    rows, trajectories, solver_failure_rows, mass_failure_rows = map(int, rows_match.groups())
    if (cases, driver_trajectories, driver_rows) != (24, 72, 432):
        fail(f"unexpected driver dimensions {(cases, driver_trajectories, driver_rows)}")
    if (rows, trajectories) != (432, 72):
        fail(f"unexpected parsed dimensions {(rows, trajectories)}")

    level_summary = []
    for line in lines:
        if not line.startswith("FSI21_N_SUMMARY:"):
            continue
        f = fields(line)
        level_summary.append({
            "N": int(f["N"]),
            "success": int(f["SUCCESS"]),
            "fail": int(f["FAIL"]),
            "headcalc_calls": int(f["HEADCALC_CALLS"]),
            "total_nonlinear_iterations": int(f["TOTAL_NITER"]),
        })
    level_summary.sort(key=lambda x: x["N"])
    expected_levels = [1, 2, 4, 8, 16, 32]
    if [row["N"] for row in level_summary] != expected_levels:
        fail(f"unexpected N summary levels: {[row['N'] for row in level_summary]}")

    horizon_level_summary = []
    for line in lines:
        if not line.startswith("FSI21_HORIZON_N:"):
            continue
        f = fields(line)
        horizon_level_summary.append({
            "horizon_id": int(f["HORIZON_ID"]),
            "target_horizon_day": finite_float(f["DT"]),
            "N": int(f["N"]),
            "success": int(f["SUCCESS"]),
            "fail": int(f["FAIL"]),
        })
    horizon_level_summary.sort(key=lambda x: (x["horizon_id"], x["N"]))
    if len(horizon_level_summary) != 18:
        fail(f"expected 18 horizon/N summaries, got {len(horizon_level_summary)}")

    mass_gate_line = next((line for line in lines if line.startswith("FSI21_GLOBAL_HARD_MASS_GATE=")), None)
    if mass_gate_line is None:
        fail("missing global hard mass gate marker")
    mass_gate_pass = mass_gate_line.endswith("=PASS")

    max_mass_line = next((line for line in lines if line.startswith("FSI21_MAX_MASS_ON_SUCCESS=")), None)
    if max_mass_line is None:
        fail("missing max mass on success marker")
    max_mass_on_success = finite_float(max_mass_line.split("=", 1)[1])

    max_solver_line = next((line for line in lines if line.startswith("FSI21_MAX_SINGLE_SOLVE_NITER=")), None)
    if max_solver_line is None:
        fail("missing max single solve marker")
    m = re.fullmatch(r"FSI21_MAX_SINGLE_SOLVE_NITER=(\d+):MAX_SINGLE_SOLVE_NBACK=(\d+)", max_solver_line)
    if m is None:
        fail(f"malformed max solver marker: {max_solver_line}")
    max_single_solve_niter, max_single_solve_nback = map(int, m.groups())

    c1_line = next((line for line in lines if line.startswith("FSI21_C1_SHAPE_SUMMARY:")), None)
    c2_line = next((line for line in lines if line.startswith("FSI21_C2_BASE_SUMMARY:")), None)
    c3_line = next((line for line in lines if line.startswith("FSI21_C3_PERSISTENT_DECAY_SUMMARY:")), None)
    if not all((c1_line, c2_line, c3_line)):
        fail("missing candidate summary marker")
    c1 = fields(c1_line)
    c2 = fields(c2_line)
    c3 = fields(c3_line)

    trajectory_rows: list[dict[str, object]] = []
    for line in lines:
        if not line.startswith("FSI21_TRAJECTORY:"):
            continue
        f = fields(line)
        fp_raw = f["FIRST_PERSISTENT_FINE_N"]
        trajectory_rows.append({
            "trajectory_id": int(f["TID"]),
            "c1_shape_pass": as_bool(f["C1_SHAPE_PASS"]),
            "c2_base_safe": as_bool(f["C2_BASE_SAFE"]),
            "first_persistent_fine_N": None if fp_raw == "NONE" else int(fp_raw),
        })
    trajectory_rows.sort(key=lambda x: int(x["trajectory_id"]))
    if len(trajectory_rows) != 72:
        fail(f"expected 72 trajectory summaries, got {len(trajectory_rows)}")

    persistence_distribution = Counter(
        "NONE" if row["first_persistent_fine_N"] is None else str(row["first_persistent_fine_N"])
        for row in trajectory_rows
    )
    emitted_distribution: dict[str, int] = {}
    for line in lines:
        if line.startswith("FSI21_FIRST_PERSISTENT_FINE_N:"):
            f = fields(line)
            emitted_distribution[f["N"]] = int(f["COUNT"])
    if dict(sorted(persistence_distribution.items())) != dict(sorted(emitted_distribution.items())):
        fail("trajectory persistence distribution disagrees with emitted summary")

    requires: dict[str, dict[str, float | int]] = {}
    for threshold in (2, 4):
        prefix = f"FSI21_REQUIRES_FINE_N_GT_{threshold}:"
        line = next((line for line in lines if line.startswith(prefix)), None)
        if line is None:
            fail(f"missing {prefix} marker")
        f = fields(line)
        requires[str(threshold)] = {
            "count": int(f["COUNT"]),
            "fraction": finite_float(f["FRACTION"]),
        }

    theoretical_line = next((line for line in lines if line.startswith("FSI21_THEORETICAL_COST:")), None)
    if theoretical_line is None:
        fail("missing theoretical cost marker")
    theoretical_fields = fields(theoretical_line)
    theoretical_cost = {key: int(value) for key, value in theoretical_fields.items()}

    actual_calls_line = next((line for line in lines if line.startswith("FSI21_ACTUAL_MAX_TOTAL_HEADCALC_CALLS_ALL_LEVELS=")), None)
    if actual_calls_line is None:
        fail("missing actual max HeadCalc calls marker")
    actual_max_total_headcalc_calls_all_levels = int(actual_calls_line.split("=", 1)[1])

    solver_failures = []
    for line in lines:
        if not line.startswith("FSI21_SOLVER_FAILURE:"):
            continue
        f = fields(line)
        solver_failures.append({
            "trajectory_id": int(f["TID"]),
            "case": int(f["CASE"]),
            "state_id": int(f["STATE"]),
            "jump_id": int(f["JUMP_ID"]),
            "horizon_id": int(f["HORIZON_ID"]),
            "N": int(f["N"]),
            "substep_duration_day": finite_float(f["SUBDT"]),
            "first_failed_step": int(f["FIRST_STEP"]),
            "status": int(f["STATUS"]),
            "max_nonlinear_iterations": int(f["MAX_NITER"]),
            "max_backtracking_attempts": int(f["MAX_NBACK"]),
        })
    if len(solver_failures) != solver_failure_rows:
        fail(f"solver failure detail count {len(solver_failures)} != summary {solver_failure_rows}")

    defect_values: dict[tuple[int, int], dict[str, list[float]]] = defaultdict(
        lambda: {"head_cm": [], "theta": [], "ponding_cm": [], "gwl_cm": []}
    )
    defect_unavailable: Counter[tuple[int, int]] = Counter()
    for line in lines:
        if not line.startswith("FSI21_DEFECT:"):
            continue
        f = fields(line)
        pair = (int(f["N_COARSE"]), int(f["N_FINE"]))
        if f["AVAILABLE"] == "F":
            defect_unavailable[pair] += 1
            continue
        defect_values[pair]["head_cm"].append(finite_float(f["DH"]))
        defect_values[pair]["theta"].append(finite_float(f["DTHETA"]))
        defect_values[pair]["ponding_cm"].append(finite_float(f["DPOND"]))
        defect_values[pair]["gwl_cm"].append(finite_float(f["DGWL"]))

    defect_aggregate = []
    for coarse in expected_levels[:-1]:
        pair = (coarse, coarse * 2)
        values = defect_values[pair]
        available = len(values["head_cm"])
        defect_aggregate.append({
            "N_coarse": coarse,
            "N_fine": coarse * 2,
            "available_trajectories": available,
            "unavailable_trajectories": defect_unavailable[pair],
            "head_sup_norm_cm": numeric_stats(values["head_cm"]),
            "theta_sup_norm": numeric_stats(values["theta"]),
            "ponding_abs_cm": numeric_stats(values["ponding_cm"]),
            "gwl_abs_cm": numeric_stats(values["gwl_cm"]),
        })

    decay: dict[tuple[int, int, str], dict[str, object]] = defaultdict(
        lambda: {"available": 0, "nonincreasing": 0, "ratios": [], "orders": []}
    )
    for line in lines:
        if not line.startswith("FSI21_DECAY:"):
            continue
        f = fields(line)
        key = (int(f["FROM_FINE_N"]), int(f["TO_FINE_N"]), f["COMP"])
        entry = decay[key]
        if f["AVAILABLE"] != "T":
            continue
        entry["available"] = int(entry["available"]) + 1
        if f["NONINCREASING"] == "T":
            entry["nonincreasing"] = int(entry["nonincreasing"]) + 1
        if f["RATIO"] != "NA":
            ratio = float(f["RATIO"])
            if math.isfinite(ratio):
                entry["ratios"].append(ratio)
        if f["ORDER"] not in {"NA", "INF"}:
            order = float(f["ORDER"])
            if math.isfinite(order):
                entry["orders"].append(order)

    decay_aggregate = []
    for key in sorted(decay):
        from_n, to_n, component = key
        entry = decay[key]
        decay_aggregate.append({
            "from_fine_N": from_n,
            "to_fine_N": to_n,
            "component": component,
            "available_trajectories": entry["available"],
            "nonincreasing_trajectories": entry["nonincreasing"],
            "ratio": numeric_stats(entry["ratios"]),
            "observed_order": numeric_stats(entry["orders"]),
        })

    evidence = {
        "schema_version": 1,
        "workstream": "F-SI",
        "work_unit": "F-SI21",
        "title": "Same-endpoint temporal characterization evidence",
        "evidence_class": "TEST_ONLY_CHARACTERIZATION_NOT_PRODUCTION_ADMISSION",
        "execution": {
            "source_head_sha": os.environ.get("GITHUB_SHA"),
            "github_run_id": os.environ.get("GITHUB_RUN_ID"),
            "github_run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
            "github_workflow": os.environ.get("GITHUB_WORKFLOW"),
            "log_sha256": hashlib.sha256(raw).hexdigest(),
            "repeat_o0": True,
            "repeat_o2": True,
            "o0_o2_identity": True,
            "production_source_unchanged": True,
            "source_and_candidate_matrix_lock": True,
            "reference_tridag_lock": True,
        },
        "matrix_observation": {
            "cases": cases,
            "trajectories": trajectories,
            "rows": rows,
            "levels": expected_levels,
            "solver_failure_rows": solver_failure_rows,
            "mass_failure_rows": mass_failure_rows,
            "global_hard_mass_gate_pass": mass_gate_pass,
            "max_mass_residual_on_success": max_mass_on_success,
            "max_single_solve_nonlinear_iterations": max_single_solve_niter,
            "max_single_solve_backtracking_attempts": max_single_solve_nback,
        },
        "level_summary": level_summary,
        "horizon_level_summary": horizon_level_summary,
        "candidate_observation": {
            "C1": {
                "shape_pass": int(c1["PASS"]),
                "shape_fail": int(c1["FAIL"]),
                "fixed_physical_solve_count": int(c1["FIXED_PHYSICAL_SOLVE_COUNT"]),
                "normal_path_admission": c1["NORMAL_PATH_ADMISSION"],
            },
            "C2": {
                "base_safe": int(c2["SAFE"]),
                "base_unsafe": int(c2["UNSAFE"]),
                "base_physical_solve_count": int(c2["BASE_PHYSICAL_SOLVE_COUNT"]),
                "numeric_trigger_selected": as_bool(c2["NUMERIC_TRIGGER_SELECTED"]),
            },
            "C3": {
                "persistent_decay_established_by_N32": int(c3["ESTABLISHED_BY_N32"]),
                "coverage_gap": int(c3["GAP"]),
                "reference_only": as_bool(c3["REFERENCE_ONLY"]),
            },
            "first_persistent_fine_N_distribution": dict(sorted(persistence_distribution.items())),
            "requires_fine_N_greater_than": requires,
        },
        "theoretical_physical_solve_cost": theoretical_cost,
        "actual_max_total_headcalc_calls_all_levels": actual_max_total_headcalc_calls_all_levels,
        "defect_aggregate": defect_aggregate,
        "decay_aggregate": decay_aggregate,
        "solver_failures": solver_failures,
        "trajectory_summary": trajectory_rows,
        "interpretation_guardrails": {
            "production_temporal_metric_selected": False,
            "production_temporal_tolerance_selected": False,
            "f_ci14_scalarization_inferred": False,
            "finite_refinement_level_treated_as_truth": False,
            "hard_mass_relaxation_allowed": False,
            "same_endpoint_production_transaction_semantics_admitted": False,
            "independent_f_vq_qualification_required_before_admission": True,
        },
        "decision": "CHARACTERIZATION_EVIDENCE_ONLY_NO_PRODUCTION_ADMISSION",
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(evidence, indent=2, sort_keys=False) + "\n", encoding="utf-8")
    print(f"FSI21_EVIDENCE_EMITTER=PASS:OUTPUT={output_path}")


if __name__ == "__main__":
    main()
