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
import run_ross01_d3g02_temporal_certificate_calibration as cal
import run_ross01_gate_j1e_d1_local_terminal_coupling_preconditioner as d1


def reference_trajectory(theta0, table, ext, divisor: int):
    horizon = adapter.DURATION_LADDER_DAY[0]
    sol = solve_ivp(
        lambda t, y: d1.gate_f.reference_rhs(t, y, table, ext),
        (0.0, horizon),
        np.asarray(theta0, dtype=float),
        method="DOP853",
        rtol=cal.REFERENCE_RTOL,
        atol=cal.REFERENCE_ATOL,
        max_step=horizon / float(divisor),
        dense_output=True,
    )
    if not sol.success or sol.sol is None:
        raise RuntimeError(f"DOP853 dense reference failed: {sol.message}")
    return sol


def ref_state(sol, t: float) -> tuple[float, ...]:
    values = tuple(float(v) for v in sol.sol(float(t)))
    if not all(math.isfinite(v) for v in values):
        raise RuntimeError("DOP853 dense reference produced non-finite state")
    return values


def run_case(material: str, attempt: int, base: dict, reference32, reference64, span: float) -> dict:
    full_dt = adapter.DURATION_LADDER_DAY[attempt]
    half_dt = adapter.DURATION_LADDER_DAY[attempt + 1]
    t0 = 37.125 + attempt
    committed_before = copy.deepcopy(base["committed_state"])

    full_req = cal.set_dt(base, t0, full_dt)
    half1_req = cal.set_dt(base, t0, half_dt)
    full = adapter.execute_research_trial(copy.deepcopy(full_req))
    half1 = adapter.execute_research_trial(copy.deepcopy(half1_req))
    half2_req = cal.set_dt(base, t0 + half_dt, half_dt)
    if half1.get("solver_disposition") == "candidate_ready":
        half2_req["committed_state"] = copy.deepcopy(half1["candidate_hydraulic_state"])
    half2 = adapter.execute_research_trial(copy.deepcopy(half2_req))
    trials = (full, half1, half2)

    ready = all(r.get("solver_disposition") == "candidate_ready" for r in trials)
    mass = all(cal.mass_ok(r) for r in trials)
    immutable = base["committed_state"] == committed_before and all(r.get("committed_state_mutated") is False for r in trials)
    candidate_only = all(r.get("accepted") is False and r.get("commit_authorized") is False and r.get("accepted_publication_authorized") is False for r in trials)
    duration_preflight = all((r.get("solver_work_diagnostics") or {}).get("d3r_duration_worker_preflight") is True for r in trials)

    ref32 = ref_state(reference32, full_dt)
    ref64 = ref_state(reference64, full_dt)
    reference_self_delta = cal.normalized_linf(ref32, ref64, span)
    raw = None
    coarse_error = None
    refined_error = None
    ratio = None
    raw_zero_with_reference_error = None
    if ready:
        coarse_theta = tuple(float(v) for v in full["candidate_hydraulic_state"]["water_content"])
        refined_theta = tuple(float(v) for v in half2["candidate_hydraulic_state"]["water_content"])
        raw = cal.normalized_linf(refined_theta, coarse_theta, span)
        coarse_error = cal.normalized_linf(coarse_theta, ref64, span)
        refined_error = cal.normalized_linf(refined_theta, ref64, span)
        raw_zero_with_reference_error = raw <= cal.RAW_FLOOR and refined_error > cal.REFERENCE_SELF_TOL_SPAN
        if raw > cal.RAW_FLOOR:
            ratio = refined_error / raw
        elif refined_error <= cal.REFERENCE_SELF_TOL_SPAN:
            ratio = 0.0

    reference_ok = (
        math.isfinite(reference_self_delta)
        and reference_self_delta <= cal.REFERENCE_SELF_TOL_SPAN
        and raw is not None and math.isfinite(raw)
        and coarse_error is not None and math.isfinite(coarse_error)
        and refined_error is not None and math.isfinite(refined_error)
        and ratio is not None and math.isfinite(ratio)
        and not raw_zero_with_reference_error
    )
    checks = {
        "all_candidates_ready": ready,
        "hard_mass_all_three": mass,
        "committed_origin_unchanged": immutable,
        "candidate_only_all_three": candidate_only,
        "duration_child_preflight_all_three": duration_preflight,
        "independent_reference_self_consistent": reference_ok,
    }
    residuals = [abs(float(r["unrounded_mass_residual_cm"])) for r in trials if isinstance(r.get("unrounded_mass_residual_cm"), (int, float))]
    return {
        "attempt_index": attempt,
        "material": material,
        "full_duration_day": full_dt,
        "half_duration_day": half_dt,
        "pass": all(checks.values()),
        "checks": checks,
        "reference": {
            "method": "DOP853_INDEPENDENT_SHARED_FULL_WINDOW_DENSE_REFERENCE",
            "rtol": cal.REFERENCE_RTOL,
            "atol": cal.REFERENCE_ATOL,
            "max_step_divisors": [32, 64],
            "self_consistency_tolerance_span": cal.REFERENCE_SELF_TOL_SPAN,
            "self_delta_span_normalized_linf": reference_self_delta,
        },
        "temporal_metrics": {
            "state_quantity": "terminal_water_content",
            "norm": "span_normalized_linf",
            "raw_full_vs_two_half_estimator": raw,
            "coarse_reference_error": coarse_error,
            "refined_reference_error": refined_error,
            "refined_error_to_raw_ratio": ratio,
            "raw_zero_with_reference_error": raw_zero_with_reference_error,
        },
        "max_abs_mass_residual_cm": max(residuals, default=0.0),
        "certificate_available": False,
        "certificate_disposition": "CALIBRATION_ONLY_NO_RUNTIME_AUTHORITY",
    }


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--material", required=True)
    p.add_argument("--canonical-head", required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    if a.material not in adapter.MATERIAL_IDS:
        raise SystemExit("material outside frozen D2 set")

    base = d2q.base_request(a.material, t0=37.125, steps=8, perturb=0.0, pre=False)
    table = cal.configure_reference(a.material)
    theta0 = tuple(float(v) for v in base["committed_state"]["water_content"])
    ext = cal.reference_external(base)
    span = float(d1.gate_d.core().THETA_S - d1.gate_d.core().THETA_R)
    ref32 = reference_trajectory(theta0, table, ext, 32)
    ref64 = reference_trajectory(theta0, table, ext, 64)
    cases = [run_case(a.material, attempt, base, ref32, ref64, span) for attempt in range(adapter.CANONICAL_MAX_RETRIES + 1)]
    payload = {
        "work_unit": "F-ROSS01 D3G02",
        "kind": "temporal_certificate_material_calibration",
        "live_canonical_head": a.canonical_head,
        "material": a.material,
        "case_count": len(cases),
        "pass": len(cases) == 9 and all(c["pass"] for c in cases),
        "reference_reuse": "TWO_FULL_WINDOW_DOP853_TRAJECTORIES_EVALUATED_AT_ALL_NINE_RETRY_ENDPOINTS",
        "cases": cases,
        "production_source_delta": [],
    }
    a.output.write_text(json.dumps(payload, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({"material": a.material, "pass": payload["pass"], "case_count": len(cases), "max_ratio": max(float(c["temporal_metrics"]["refined_error_to_raw_ratio"]) for c in cases)}, sort_keys=True, allow_nan=False))
    return 0 if payload["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
