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

LEVELS = (2, 4, 8, 16)
PERTURBATIONS = (("NEGATIVE_ONE_PERCENT", -0.01), ("POSITIVE_ONE_PERCENT", 0.01))
RAW_FLOOR = 1.0e-16


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
    out = tuple(float(v) for v in sol.sol(float(t)))
    if not all(math.isfinite(v) for v in out):
        raise RuntimeError("non-finite DOP853 reference state")
    return out


def theta(result: dict) -> tuple[float, ...] | None:
    if result.get("solver_disposition") != "candidate_ready":
        return None
    return tuple(float(v) for v in result["candidate_hydraulic_state"]["water_content"])


def trial_ok(result: dict) -> bool:
    return (
        result.get("solver_disposition") == "candidate_ready"
        and cal.mass_ok(result)
        and result.get("committed_state_mutated") is False
        and result.get("accepted") is False
        and result.get("commit_authorized") is False
        and result.get("accepted_publication_authorized") is False
        and (result.get("solver_work_diagnostics") or {}).get("d3r_duration_worker_preflight") is True
    )


def observed_order(delta_coarse: float, delta_fine: float) -> float | None:
    if delta_coarse > RAW_FLOOR and delta_fine > RAW_FLOOR:
        return math.log(delta_coarse / delta_fine, 2.0)
    return None


def run_case(material: str, perturb_id: str, perturb: float, attempt: int, refs, span: float) -> dict:
    full_dt = adapter.DURATION_LADDER_DAY[attempt]
    half_dt = adapter.DURATION_LADDER_DAY[attempt + 1]
    t0 = 137.125 + float(attempt)

    full_results: dict[int, dict] = {}
    committed_snapshots: dict[int, dict] = {}
    for level in LEVELS:
        req = d2q.base_request(material, t0=t0, steps=level, perturb=perturb, pre=False)
        committed_snapshots[level] = copy.deepcopy(req["committed_state"])
        req = cal.set_dt(req, t0, full_dt)
        full_results[level] = adapter.execute_research_trial(copy.deepcopy(req))

    base8 = d2q.base_request(material, t0=t0, steps=8, perturb=perturb, pre=False)
    half1_req = cal.set_dt(base8, t0, half_dt)
    half1 = adapter.execute_research_trial(copy.deepcopy(half1_req))
    half2_req = cal.set_dt(base8, t0 + half_dt, half_dt)
    if half1.get("solver_disposition") == "candidate_ready":
        half2_req["committed_state"] = copy.deepcopy(half1["candidate_hydraulic_state"])
    half2 = adapter.execute_research_trial(copy.deepcopy(half2_req))

    all_results = list(full_results.values()) + [half1, half2]
    numerical_pass = all(trial_ok(r) for r in all_results)
    committed_unchanged = all(
        d2q.base_request(material, t0=t0, steps=level, perturb=perturb, pre=False)["committed_state"] == committed_snapshots[level]
        for level in LEVELS
    )

    reference32 = ref_state(refs[0], full_dt)
    reference64 = ref_state(refs[1], full_dt)
    reference_self_delta = cal.normalized_linf(reference32, reference64, span)

    states = {level: theta(full_results[level]) for level in LEVELS}
    half_state = theta(half2)
    metrics = None
    structural_signal = False
    if numerical_pass and committed_unchanged and all(states.values()) and half_state is not None:
        errors = {level: cal.normalized_linf(states[level], reference64, span) for level in LEVELS}
        d24 = cal.normalized_linf(states[2], states[4], span)
        d48 = cal.normalized_linf(states[4], states[8], span)
        d816 = cal.normalized_linf(states[8], states[16], span)
        raw_two_half = cal.normalized_linf(states[8], half_state, span)
        half_error = cal.normalized_linf(half_state, reference64, span)
        full16_vs_two_half8 = cal.normalized_linf(states[16], half_state, span)
        ratio = half_error / raw_two_half if raw_two_half > RAW_FLOOR else (0.0 if half_error <= cal.REFERENCE_SELF_TOL_SPAN else None)
        error_monotone = errors[16] <= errors[8] <= errors[4] <= errors[2]
        delta_monotone = d816 <= d48 <= d24
        structural_signal = (
            reference_self_delta <= cal.REFERENCE_SELF_TOL_SPAN
            and error_monotone
            and delta_monotone
        )
        metrics = {
            "reference_errors": {str(k): errors[k] for k in LEVELS},
            "adjacent_deltas": {"2_to_4": d24, "4_to_8": d48, "8_to_16": d816},
            "observed_orders": {
                "from_2_4_vs_4_8": observed_order(d24, d48),
                "from_4_8_vs_8_16": observed_order(d48, d816),
            },
            "full8_vs_two_half8_raw_estimator": raw_two_half,
            "two_half8_reference_error": half_error,
            "two_half8_error_to_raw_ratio": ratio,
            "full16_vs_two_half8_equivalence_delta": full16_vs_two_half8,
            "reference_error_monotone_2_4_8_16": error_monotone,
            "adjacent_delta_monotone_2_4_8_16": delta_monotone,
        }

    residuals = [abs(float(r["unrounded_mass_residual_cm"])) for r in all_results if isinstance(r.get("unrounded_mass_residual_cm"), (int, float))]
    return {
        "material": material,
        "forcing_variant": perturb_id,
        "bounded_flux_perturbation": perturb,
        "attempt_index": attempt,
        "full_duration_day": full_dt,
        "half_duration_day": half_dt,
        "numerical_pass": numerical_pass and committed_unchanged and reference_self_delta <= cal.REFERENCE_SELF_TOL_SPAN,
        "structural_signal": structural_signal,
        "reference_self_delta": reference_self_delta,
        "temporal_metrics": metrics,
        "max_abs_mass_residual_cm": max(residuals, default=0.0),
        "certificate_available": False,
        "d3_g02_closed": False,
    }


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--material", required=True)
    p.add_argument("--canonical-head", required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    if a.material not in adapter.MATERIAL_IDS:
        raise SystemExit("material outside frozen D2 set")

    table = cal.configure_reference(a.material)
    row = adapter.base.MATERIAL_ROWS[a.material]
    span = float(row["theta_s"] - row["theta_r"])
    cases = []
    for perturb_id, perturb in PERTURBATIONS:
        ref_base = d2q.base_request(a.material, t0=137.125, steps=8, perturb=perturb, pre=False)
        theta0 = tuple(float(v) for v in ref_base["committed_state"]["water_content"])
        ext = cal.reference_external(ref_base)
        refs = (reference_trajectory(theta0, table, ext, 32), reference_trajectory(theta0, table, ext, 64))
        for attempt in range(adapter.CANONICAL_MAX_RETRIES + 1):
            cases.append(run_case(a.material, perturb_id, perturb, attempt, refs, span))

    numerical_pass = len(cases) == 18 and all(c["numerical_pass"] for c in cases)
    structural_signal = numerical_pass and all(c["structural_signal"] for c in cases)
    payload = {
        "work_unit": "F-ROSS01 D3G02R",
        "kind": "estimator_structure_material_holdout",
        "live_canonical_head": a.canonical_head,
        "material": a.material,
        "case_count": len(cases),
        "expected_case_count": 18,
        "numerical_pass": numerical_pass,
        "structural_signal": structural_signal,
        "certificate_available": False,
        "d3_g02_closed": False,
        "production_source_delta": [],
        "cases": cases,
    }
    a.output.write_text(json.dumps(payload, indent=2, sort_keys=True, allow_nan=False) + "\n")
    finite_ratios = [
        c["temporal_metrics"]["two_half8_error_to_raw_ratio"]
        for c in cases if c.get("temporal_metrics") and c["temporal_metrics"].get("two_half8_error_to_raw_ratio") is not None
    ]
    print(json.dumps({
        "material": a.material,
        "case_count": len(cases),
        "numerical_pass": numerical_pass,
        "structural_signal": structural_signal,
        "max_two_half_ratio": max(finite_ratios, default=None),
        "max_mass_residual_cm": max(c["max_abs_mass_residual_cm"] for c in cases),
    }, sort_keys=True, allow_nan=False))
    return 0 if numerical_pass else 2


if __name__ == "__main__":
    raise SystemExit(main())
