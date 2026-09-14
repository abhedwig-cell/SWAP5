from __future__ import annotations

import argparse
import copy
import json
import math
from pathlib import Path

import ross01_d3r_fsi31_duration_adapter as adapter
import run_ross01_d2_fsi31_qualification as d2q
import run_ross01_d3g02_temporal_certificate_calibration as cal
import run_ross01_d3g02r_estimator_structure_material as prior_probe

LEVELS = (2, 4, 8, 16)
VARIANTS = {
    "TOP_PLUS2_BOTTOM_PLUS2": (0.02, 0.02),
    "TOP_PLUS2_BOTTOM_MINUS2": (0.02, -0.02),
    "TOP_MINUS2_BOTTOM_PLUS2": (-0.02, 0.02),
    "TOP_MINUS2_BOTTOM_MINUS2": (-0.02, -0.02),
}
MASS_TOL_CM = 1.0e-12
REFERENCE_SELF_TOL_SPAN = 1.0e-9
ACCURACY_TOL_SPAN = 1.0e-5


def independent_boundary_request(material: str, t0: float, steps: int, top_fraction: float, bottom_fraction: float) -> dict:
    nominal = d2q.base_request(material, t0=t0, steps=steps, perturb=0.0, pre=False)
    plus_one = d2q.base_request(material, t0=t0, steps=steps, perturb=0.01, pre=False)
    f0 = nominal["forcing_process_requests"]
    f1 = plus_one["forcing_process_requests"]

    qtop0 = float(f0["top_boundary"]["q_top_cm_per_day"])
    qtop1 = float(f1["top_boundary"]["q_top_cm_per_day"])
    qbot0 = float(f0["bottom_boundary"]["qbot_cm_per_day"])
    qbot1 = float(f1["bottom_boundary"]["qbot_cm_per_day"])
    top_scale = (qtop1 - qtop0) / 0.01
    bottom_scale = (qbot0 - qbot1) / 0.01
    if not (math.isfinite(top_scale) and top_scale > 0.0 and math.isfinite(bottom_scale) and bottom_scale > 0.0):
        raise RuntimeError("could not reconstruct frozen D2 state-local boundary scales")

    req = copy.deepcopy(nominal)
    forcing = req["forcing_process_requests"]
    forcing["top_boundary"]["q_top_cm_per_day"] = qtop0 + float(top_fraction) * top_scale
    forcing["bottom_boundary"]["qbot_cm_per_day"] = qbot0 - float(bottom_fraction) * bottom_scale
    return req


def theta(result: dict) -> tuple[float, ...] | None:
    if result.get("solver_disposition") != "candidate_ready":
        return None
    state = result.get("candidate_hydraulic_state") or {}
    values = state.get("water_content")
    if not isinstance(values, list):
        return None
    return tuple(float(v) for v in values)


def trial_ok(result: dict) -> bool:
    diag = result.get("solver_work_diagnostics") or {}
    residual = result.get("unrounded_mass_residual_cm")
    return (
        result.get("solver_disposition") == "candidate_ready"
        and isinstance(residual, (int, float))
        and math.isfinite(float(residual))
        and abs(float(residual)) <= MASS_TOL_CM
        and result.get("committed_state_mutated") is False
        and result.get("request_object_unchanged") is True
        and result.get("accepted") is False
        and result.get("commit_authorized") is False
        and result.get("accepted_publication_authorized") is False
        and diag.get("d3r_duration_worker_preflight") is True
    )


def run_case(material: str, variant_id: str, top_fraction: float, bottom_fraction: float, attempt: int, refs, span: float) -> dict:
    full_dt = adapter.DURATION_LADDER_DAY[attempt]
    t0 = 219.375 + float(attempt)
    results: dict[int, dict] = {}
    requested_fluxes: dict[int, dict] = {}

    for level in LEVELS:
        req = independent_boundary_request(material, t0, level, top_fraction, bottom_fraction)
        req = cal.set_dt(req, t0, full_dt)
        requested_fluxes[level] = {
            "q_top_cm_per_day": float(req["forcing_process_requests"]["top_boundary"]["q_top_cm_per_day"]),
            "qbot_cm_per_day": float(req["forcing_process_requests"]["bottom_boundary"]["qbot_cm_per_day"]),
        }
        results[level] = adapter.execute_research_trial(req)

    numerical_pass = all(trial_ok(results[level]) for level in LEVELS)
    request_immutable = all(results[level].get("request_object_unchanged") is True for level in LEVELS)
    same_forcing_all_levels = len({(v["q_top_cm_per_day"], v["qbot_cm_per_day"]) for v in requested_fluxes.values()}) == 1

    reference32 = prior_probe.ref_state(refs[0], full_dt)
    reference64 = prior_probe.ref_state(refs[1], full_dt)
    reference_self_delta = cal.normalized_linf(reference32, reference64, span)

    states = {level: theta(results[level]) for level in LEVELS}
    metrics = None
    conservativity_pass = False
    accuracy_pass = False
    if numerical_pass and request_immutable and same_forcing_all_levels and all(states.values()):
        d24 = cal.normalized_linf(states[2], states[4], span)
        d48 = cal.normalized_linf(states[4], states[8], span)
        d816 = cal.normalized_linf(states[8], states[16], span)
        envelope = max(d24, d48, d816)
        refined_error = cal.normalized_linf(states[16], reference64, span)
        conservativity_pass = refined_error <= envelope
        accuracy_pass = refined_error <= ACCURACY_TOL_SPAN
        metrics = {
            "adjacent_deltas": {"2_to_4": d24, "4_to_8": d48, "8_to_16": d816},
            "multilevel_refinement_envelope": envelope,
            "theta16_reference_error": refined_error,
            "reference_error_to_envelope_ratio": (refined_error / envelope) if envelope > 0.0 else (0.0 if refined_error == 0.0 else None),
            "conservativity_margin": envelope - refined_error,
            "conservativity_pass": conservativity_pass,
            "accuracy_pass": accuracy_pass,
            "monotonicity_required": False,
        }

    residuals = [
        abs(float(r["unrounded_mass_residual_cm"]))
        for r in results.values()
        if isinstance(r.get("unrounded_mass_residual_cm"), (int, float))
    ]
    case_pass = bool(
        numerical_pass
        and request_immutable
        and same_forcing_all_levels
        and reference_self_delta <= REFERENCE_SELF_TOL_SPAN
        and metrics is not None
        and conservativity_pass
        and accuracy_pass
    )
    return {
        "material": material,
        "boundary_variant": variant_id,
        "top_fraction": top_fraction,
        "bottom_fraction": bottom_fraction,
        "attempt_index": attempt,
        "full_duration_day": full_dt,
        "pass": case_pass,
        "numerical_pass": numerical_pass,
        "request_immutable": request_immutable,
        "same_forcing_all_levels": same_forcing_all_levels,
        "reference_self_delta": reference_self_delta,
        "requested_fluxes": requested_fluxes[2],
        "temporal_metrics": metrics,
        "max_abs_mass_residual_cm": max(residuals, default=0.0),
        "certificate_available": False,
        "d3_g02_closed": False,
    }


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--material", required=True)
    p.add_argument("--boundary-variant", required=True)
    p.add_argument("--canonical-head", required=True)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()

    if a.material not in adapter.MATERIAL_IDS:
        raise SystemExit("material outside frozen D2 set")
    if a.boundary_variant not in VARIANTS:
        raise SystemExit("boundary variant outside frozen H1 holdout set")
    top_fraction, bottom_fraction = VARIANTS[a.boundary_variant]

    table = cal.configure_reference(a.material)
    row = adapter.base.MATERIAL_ROWS[a.material]
    span = float(row["theta_s"] - row["theta_r"])
    ref_req = independent_boundary_request(a.material, 219.375, 8, top_fraction, bottom_fraction)
    theta0 = tuple(float(v) for v in ref_req["committed_state"]["water_content"])
    ext = cal.reference_external(ref_req)
    refs = (
        prior_probe.reference_trajectory(theta0, table, ext, 32),
        prior_probe.reference_trajectory(theta0, table, ext, 64),
    )

    cases = [
        run_case(a.material, a.boundary_variant, top_fraction, bottom_fraction, attempt, refs, span)
        for attempt in range(adapter.CANONICAL_MAX_RETRIES + 1)
    ]
    passed = len(cases) == 9 and all(c["pass"] for c in cases)
    payload = {
        "work_unit": "F-ROSS01 D3G02H1",
        "kind": "multilevel_refinement_envelope_boundary_variant_holdout",
        "live_canonical_head": a.canonical_head,
        "transaction_reference_blob": "d5a71a526efaebd82054580c3186f8e3545db331",
        "material": a.material,
        "boundary_variant": a.boundary_variant,
        "top_fraction": top_fraction,
        "bottom_fraction": bottom_fraction,
        "case_count": len(cases),
        "expected_case_count": 9,
        "pass": passed,
        "certificate_available": False,
        "d3_g02_closed": False,
        "production_admission": False,
        "production_source_delta": [],
        "cases": cases,
    }
    a.output.write_text(json.dumps(payload, indent=2, sort_keys=True, allow_nan=False) + "\n")

    envelopes = [c["temporal_metrics"]["multilevel_refinement_envelope"] for c in cases if c.get("temporal_metrics")]
    errors = [c["temporal_metrics"]["theta16_reference_error"] for c in cases if c.get("temporal_metrics")]
    ratios = [c["temporal_metrics"]["reference_error_to_envelope_ratio"] for c in cases if c.get("temporal_metrics") and c["temporal_metrics"].get("reference_error_to_envelope_ratio") is not None]
    print(json.dumps({
        "material": a.material,
        "boundary_variant": a.boundary_variant,
        "case_count": len(cases),
        "pass": passed,
        "max_envelope": max(envelopes, default=None),
        "max_reference_error": max(errors, default=None),
        "max_reference_error_to_envelope_ratio": max(ratios, default=None),
        "max_mass_residual_cm": max(c["max_abs_mass_residual_cm"] for c in cases),
    }, sort_keys=True, allow_nan=False))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
