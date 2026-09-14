from __future__ import annotations

import argparse
import copy
import json
import math
from pathlib import Path

import numpy as np
from scipy.integrate import solve_ivp

import ross01_d3r_fsi31_duration_adapter as adapter
import run_ross01_d2_fsi31_qualification as d2q
import run_ross01_gate_j1e_d1_local_terminal_coupling_preconditioner as d1

MASS_TOL_CM = 1.0e-12
REFERENCE_RTOL = 1.0e-11
REFERENCE_ATOL = 1.0e-13
REFERENCE_SELF_TOL_SPAN = 1.0e-9
RAW_FLOOR = 1.0e-16


def set_dt(req: dict, t0: float, dt: float) -> dict:
    out = copy.deepcopy(req)
    out["forcing_process_requests"]["t0_day"] = float(t0)
    out["forcing_process_requests"]["t1_day"] = float(t0 + dt)
    return out


def mass_ok(result: dict) -> bool:
    value = result.get("unrounded_mass_residual_cm")
    return isinstance(value, (int, float)) and math.isfinite(float(value)) and abs(float(value)) <= MASS_TOL_CM


def normalized_linf(a, b, span: float) -> float:
    return max(abs(float(x) - float(y)) for x, y in zip(a, b)) / span


def configure_reference(material: str):
    row = copy.deepcopy(adapter.base.MATERIAL_ROWS[material])
    d1.j1a.c1r.base.c1.configure_core(row)
    table, _, failures = d1.j1a.c1r.base.generate_table(d1.j1a.N)
    if failures:
        raise RuntimeError(f"reference table generation failed: {len(failures)}")
    return table


def reference_external(request: dict) -> dict:
    forcing = request["forcing_process_requests"]
    return {
        "q_top": float(forcing["top_boundary"]["q_top_cm_per_day"]),
        "q_bottom": -float(forcing["bottom_boundary"]["qbot_cm_per_day"]),
        "source": tuple(0.0 for _ in range(adapter.base.N_CELLS)),
        "sink": tuple(0.0 for _ in range(adapter.base.N_CELLS)),
    }


def reference_solve(theta0, table, ext, duration: float, divisor: int) -> tuple[float, ...]:
    sol = solve_ivp(
        lambda t, y: d1.gate_f.reference_rhs(t, y, table, ext),
        (0.0, duration),
        np.asarray(theta0, dtype=float),
        method="DOP853",
        rtol=REFERENCE_RTOL,
        atol=REFERENCE_ATOL,
        max_step=duration / float(divisor),
        dense_output=False,
    )
    if not sol.success:
        raise RuntimeError(f"DOP853 reference failed: {sol.message}")
    final = tuple(float(v) for v in sol.y[:, -1])
    if not all(math.isfinite(v) for v in final):
        raise RuntimeError("DOP853 reference produced non-finite state")
    return final


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--attempt-index", type=int, required=True)
    p.add_argument("--material", required=True)
    p.add_argument("--canonical-head", required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()

    if a.attempt_index not in range(adapter.CANONICAL_MAX_RETRIES + 1):
        raise SystemExit("attempt-index outside 0..8")
    if a.material not in adapter.MATERIAL_IDS:
        raise SystemExit("material outside frozen D2 set")

    full_dt = adapter.DURATION_LADDER_DAY[a.attempt_index]
    half_dt = adapter.DURATION_LADDER_DAY[a.attempt_index + 1]
    t0 = 37.125 + a.attempt_index
    base = d2q.base_request(a.material, t0=t0, steps=8, perturb=0.0, pre=False)
    committed_before = copy.deepcopy(base["committed_state"])

    full_req = set_dt(base, t0, full_dt)
    half1_req = set_dt(base, t0, half_dt)
    full = adapter.execute_research_trial(copy.deepcopy(full_req))
    half1 = adapter.execute_research_trial(copy.deepcopy(half1_req))

    half2_req = set_dt(base, t0 + half_dt, half_dt)
    if half1.get("solver_disposition") == "candidate_ready":
        half2_req["committed_state"] = copy.deepcopy(half1["candidate_hydraulic_state"])
    half2 = adapter.execute_research_trial(copy.deepcopy(half2_req))
    trials = (full, half1, half2)

    ready = all(r.get("solver_disposition") == "candidate_ready" for r in trials)
    mass = all(mass_ok(r) for r in trials)
    immutable = base["committed_state"] == committed_before and all(r.get("committed_state_mutated") is False for r in trials)
    candidate_only = all(r.get("accepted") is False and r.get("commit_authorized") is False and r.get("accepted_publication_authorized") is False for r in trials)
    duration_preflight = all((r.get("solver_work_diagnostics") or {}).get("d3r_duration_worker_preflight") is True for r in trials)

    checks = {
        "all_candidates_ready": ready,
        "hard_mass_all_three": mass,
        "committed_origin_unchanged": immutable,
        "candidate_only_all_three": candidate_only,
        "duration_child_preflight_all_three": duration_preflight,
    }

    coarse_theta = None
    refined_theta = None
    raw_estimator = None
    reference_error_coarse = None
    reference_error_refined = None
    reference_self_delta = None
    refined_error_to_raw_ratio = None
    raw_zero_with_reference_error = None
    reference_ok = False

    if ready:
        coarse_theta = tuple(float(v) for v in full["candidate_hydraulic_state"]["water_content"])
        refined_theta = tuple(float(v) for v in half2["candidate_hydraulic_state"]["water_content"])
        table = configure_reference(a.material)
        theta0 = tuple(float(v) for v in base["committed_state"]["water_content"])
        ext = reference_external(base)
        span = float(d1.gate_d.core().THETA_S - d1.gate_d.core().THETA_R)
        reference32 = reference_solve(theta0, table, ext, full_dt, 32)
        reference64 = reference_solve(theta0, table, ext, full_dt, 64)
        reference_self_delta = normalized_linf(reference32, reference64, span)
        raw_estimator = normalized_linf(refined_theta, coarse_theta, span)
        reference_error_coarse = normalized_linf(coarse_theta, reference64, span)
        reference_error_refined = normalized_linf(refined_theta, reference64, span)
        raw_zero_with_reference_error = raw_estimator <= RAW_FLOOR and reference_error_refined > REFERENCE_SELF_TOL_SPAN
        if raw_estimator > RAW_FLOOR:
            refined_error_to_raw_ratio = reference_error_refined / raw_estimator
        elif reference_error_refined <= REFERENCE_SELF_TOL_SPAN:
            refined_error_to_raw_ratio = 0.0
        reference_ok = (
            math.isfinite(reference_self_delta)
            and reference_self_delta <= REFERENCE_SELF_TOL_SPAN
            and not raw_zero_with_reference_error
            and math.isfinite(raw_estimator)
            and math.isfinite(reference_error_coarse)
            and math.isfinite(reference_error_refined)
            and refined_error_to_raw_ratio is not None
            and math.isfinite(refined_error_to_raw_ratio)
        )

    checks["independent_reference_self_consistent"] = reference_ok
    residuals = [abs(float(r["unrounded_mass_residual_cm"])) for r in trials if isinstance(r.get("unrounded_mass_residual_cm"), (int, float))]
    passed = all(checks.values())

    evidence = {
        "work_unit": "F-ROSS01 D3G02",
        "kind": "temporal_certificate_calibration_case",
        "live_canonical_head": a.canonical_head,
        "attempt_index": a.attempt_index,
        "material": a.material,
        "full_duration_day": full_dt,
        "half_duration_day": half_dt,
        "coarse_full_substeps": 8,
        "refined_half_substeps_each": 8,
        "effective_refined_substeps": 16,
        "pass": passed,
        "checks": checks,
        "reference": {
            "method": "DOP853_INDEPENDENT_REFERENCE",
            "rtol": REFERENCE_RTOL,
            "atol": REFERENCE_ATOL,
            "max_step_divisors": [32, 64],
            "self_consistency_tolerance_span": REFERENCE_SELF_TOL_SPAN,
            "self_delta_span_normalized_linf": reference_self_delta,
        },
        "temporal_metrics": {
            "state_quantity": "terminal_water_content",
            "norm": "span_normalized_linf",
            "raw_full_vs_two_half_estimator": raw_estimator,
            "coarse_reference_error": reference_error_coarse,
            "refined_reference_error": reference_error_refined,
            "refined_error_to_raw_ratio": refined_error_to_raw_ratio,
            "raw_zero_with_reference_error": raw_zero_with_reference_error,
        },
        "max_abs_mass_residual_cm": max(residuals, default=0.0),
        "certificate_available": False,
        "certificate_disposition": "CALIBRATION_ONLY_NO_RUNTIME_AUTHORITY",
        "production_source_delta": [],
    }
    a.output.write_text(json.dumps(evidence, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({
        "attempt_index": a.attempt_index,
        "material": a.material,
        "pass": passed,
        "raw": raw_estimator,
        "refined_reference_error": reference_error_refined,
        "ratio": refined_error_to_raw_ratio,
        "reference_self_delta": reference_self_delta,
    }, sort_keys=True, allow_nan=False))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
