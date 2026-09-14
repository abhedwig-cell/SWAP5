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

REFERENCE_RTOL = 1.0e-11
REFERENCE_ATOL = 1.0e-13
REFERENCE_SPREAD_LIMIT = 1.0e-9
ACCURACY_TOLERANCE = 1.0e-5
MASS_TOL_CM = 1.0e-12


def reference_trajectory(theta0, table, ext, method: str, divisor: int):
    horizon = adapter.DURATION_LADDER_DAY[0]
    sol = solve_ivp(
        lambda t, y: d1.gate_f.reference_rhs(t, y, table, ext),
        (0.0, horizon),
        np.asarray(theta0, dtype=float),
        method=method,
        rtol=REFERENCE_RTOL,
        atol=REFERENCE_ATOL,
        max_step=horizon / float(divisor),
        dense_output=True,
    )
    if not sol.success or sol.sol is None:
        raise RuntimeError(f"{method} reference failed: {sol.message}")
    return sol


def ref_state(sol, t: float) -> tuple[float, ...]:
    out = tuple(float(v) for v in sol.sol(float(t)))
    if not all(math.isfinite(v) for v in out):
        raise RuntimeError("reference ensemble produced non-finite state")
    return out


def run_case(material: str, attempt: int, base: dict, dop64, dop128, rad128, span: float) -> dict:
    full_dt = adapter.DURATION_LADDER_DAY[attempt]
    half_dt = adapter.DURATION_LADDER_DAY[attempt + 1]
    t0 = 73.25 + attempt
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
    candidate_only = all(
        r.get("accepted") is False
        and r.get("commit_authorized") is False
        and r.get("accepted_publication_authorized") is False
        for r in trials
    )
    duration_preflight = all((r.get("solver_work_diagnostics") or {}).get("d3r_duration_worker_preflight") is True for r in trials)

    raw = None
    coarse_error = None
    refined_error = None
    reference_spread = None
    resolved_error = None
    apparent_underestimate = None
    apparent_underestimate_inside_reference_spread = None
    resolution_aware_conservative = None

    if ready:
        coarse_theta = tuple(float(v) for v in full["candidate_hydraulic_state"]["water_content"])
        refined_theta = tuple(float(v) for v in half2["candidate_hydraulic_state"]["water_content"])
        r64 = ref_state(dop64, full_dt)
        r128 = ref_state(dop128, full_dt)
        rr128 = ref_state(rad128, full_dt)

        pairwise = (
            cal.normalized_linf(r64, r128, span),
            cal.normalized_linf(r64, rr128, span),
            cal.normalized_linf(r128, rr128, span),
        )
        reference_spread = max(pairwise)
        raw = cal.normalized_linf(refined_theta, coarse_theta, span)
        coarse_error = cal.normalized_linf(coarse_theta, r128, span)
        refined_error = cal.normalized_linf(refined_theta, r128, span)
        resolved_error = max(0.0, refined_error - reference_spread)
        apparent_underestimate = refined_error > raw
        apparent_underestimate_inside_reference_spread = (not apparent_underestimate) or refined_error <= reference_spread
        resolution_aware_conservative = resolved_error <= raw

    residuals = [abs(float(r["unrounded_mass_residual_cm"])) for r in trials if isinstance(r.get("unrounded_mass_residual_cm"), (int, float))]
    max_mass = max(residuals, default=float("inf"))
    reference_ok = (
        reference_spread is not None
        and math.isfinite(reference_spread)
        and reference_spread <= REFERENCE_SPREAD_LIMIT
        and raw is not None and math.isfinite(raw) and raw >= 0.0
        and coarse_error is not None and math.isfinite(coarse_error) and coarse_error >= 0.0
        and refined_error is not None and math.isfinite(refined_error) and refined_error >= 0.0
        and resolved_error is not None and math.isfinite(resolved_error) and resolved_error >= 0.0
    )

    checks = {
        "all_candidates_ready": ready,
        "hard_mass_all_three": mass and max_mass <= MASS_TOL_CM,
        "committed_origin_unchanged": immutable,
        "candidate_only_all_three": candidate_only,
        "duration_child_preflight_all_three": duration_preflight,
        "reference_ensemble_spread_le_1e_9": reference_ok,
        "resolved_error_le_raw": resolution_aware_conservative is True,
        "apparent_underestimate_fully_inside_reference_spread": apparent_underestimate_inside_reference_spread is True,
        "refined_error_le_1e_5": refined_error is not None and refined_error <= ACCURACY_TOLERANCE,
    }

    return {
        "attempt_index": attempt,
        "material": material,
        "full_duration_day": full_dt,
        "half_duration_day": half_dt,
        "pass": all(checks.values()),
        "checks": checks,
        "reference": {
            "ensemble": ["DOP853_64", "DOP853_128", "RADAU_128"],
            "rtol": REFERENCE_RTOL,
            "atol": REFERENCE_ATOL,
            "center": "DOP853_128",
            "spread_hard_limit_span": REFERENCE_SPREAD_LIMIT,
            "spread_span_normalized_linf": reference_spread,
        },
        "temporal_metrics": {
            "state_quantity": "terminal_water_content",
            "norm": "span_normalized_linf",
            "raw_full_vs_two_half_estimator": raw,
            "coarse_reference_error": coarse_error,
            "refined_reference_error": refined_error,
            "resolved_refined_error_lower_bound": resolved_error,
            "apparent_underestimate": apparent_underestimate,
            "apparent_underestimate_inside_reference_spread": apparent_underestimate_inside_reference_spread,
            "resolution_aware_conservative": resolution_aware_conservative,
            "candidate_safety_factor": 1.0,
            "candidate_accuracy_tolerance": ACCURACY_TOLERANCE,
        },
        "max_abs_mass_residual_cm": max_mass,
        "certificate_available": False,
        "certificate_disposition": "QUALIFICATION_ONLY_PENDING_EXECUTABLE_BINDING",
    }


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--material", required=True)
    p.add_argument("--canonical-head", required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    if a.material not in adapter.MATERIAL_IDS:
        raise SystemExit("material outside frozen D2 set")

    base = d2q.base_request(a.material, t0=73.25, steps=8, perturb=0.0, pre=False)
    table = cal.configure_reference(a.material)
    theta0 = tuple(float(v) for v in base["committed_state"]["water_content"])
    ext = cal.reference_external(base)
    span = float(d1.gate_d.core().THETA_S - d1.gate_d.core().THETA_R)

    dop64 = reference_trajectory(theta0, table, ext, "DOP853", 64)
    dop128 = reference_trajectory(theta0, table, ext, "DOP853", 128)
    rad128 = reference_trajectory(theta0, table, ext, "Radau", 128)
    cases = [run_case(a.material, i, base, dop64, dop128, rad128, span) for i in range(adapter.CANONICAL_MAX_RETRIES + 1)]

    payload = {
        "work_unit": "F-ROSS01 D3G02R1",
        "kind": "reference_resolution_material_qualification",
        "live_canonical_head": a.canonical_head,
        "material": a.material,
        "case_count": len(cases),
        "pass": len(cases) == 9 and all(c["pass"] for c in cases),
        "cases": cases,
        "production_source_delta": [],
    }
    a.output.write_text(json.dumps(payload, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({
        "material": a.material,
        "pass": payload["pass"],
        "case_count": len(cases),
        "max_reference_spread": max(float(c["reference"]["spread_span_normalized_linf"]) for c in cases),
        "max_refined_error": max(float(c["temporal_metrics"]["refined_reference_error"]) for c in cases),
        "max_resolved_minus_raw": max(float(c["temporal_metrics"]["resolved_refined_error_lower_bound"]) - float(c["temporal_metrics"]["raw_full_vs_two_half_estimator"]) for c in cases),
    }, sort_keys=True, allow_nan=False))
    return 0 if payload["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
