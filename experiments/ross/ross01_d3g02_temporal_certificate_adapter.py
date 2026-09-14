from __future__ import annotations

import copy
import json
import math
from pathlib import Path

import ross01_d3r_fsi31_duration_adapter as d3r

_CONTRACT = Path(__file__).resolve().parents[2] / "integration" / "f-ross" / "F-ROSS01_D3G02_TEMPORAL_CERTIFICATE_CONTRACT.json"


def _fail(classification: str, detail: str, stage: str = "d3g02_preflight") -> dict:
    out = d3r.base._fail(classification, detail, stage)
    out["temporal_certificate_available"] = False
    out["temporal_indicator"] = None
    out["temporal_certificate"] = {
        "available": False,
        "method": "INTERNAL_FULL_VS_TWO_HALF_STEP_DOUBLING",
        "reason": classification,
    }
    return out


def _qualified_constants() -> tuple[float, float]:
    try:
        contract = json.loads(_CONTRACT.read_text())
        cfg = contract["runtime_certificate_candidate"]
        factor = cfg.get("safety_factor")
        tolerance = cfg.get("accuracy_tolerance")
    except Exception as exc:
        raise RuntimeError(f"certificate contract unavailable: {exc!r}") from exc
    if not isinstance(factor, (int, float)) or not math.isfinite(float(factor)) or float(factor) <= 0.0:
        raise RuntimeError("no qualified finite positive temporal safety factor")
    if not isinstance(tolerance, (int, float)) or not math.isfinite(float(tolerance)) or float(tolerance) <= 0.0:
        raise RuntimeError("no qualified finite positive temporal accuracy tolerance")
    return float(factor), float(tolerance)


def _set_interval(request: dict, t0: float, dt: float) -> dict:
    out = copy.deepcopy(request)
    out["forcing_process_requests"]["t0_day"] = float(t0)
    out["forcing_process_requests"]["t1_day"] = float(t0 + dt)
    return out


def _mass_ok(result: dict) -> bool:
    value = result.get("unrounded_mass_residual_cm")
    return isinstance(value, (int, float)) and math.isfinite(float(value)) and abs(float(value)) <= d3r.HARD_MASS_TOL_CM


def _aggregate_refined_mass(initial_state: dict, final_result: dict, half1: dict, half2: dict) -> dict:
    initial_theta = tuple(float(v) for v in initial_state["water_content"])
    final_theta = tuple(float(v) for v in final_result["candidate_hydraulic_state"]["water_content"])
    storage_change = d3r.DZ_CM * (math.fsum(final_theta) - math.fsum(initial_theta))
    keys = ("top_boundary_transfer_cm", "bottom_boundary_transfer_cm", "source_transfer_cm", "sink_transfer_cm")
    terms = {}
    for key in keys:
        a = (half1.get("mass_terms") or {}).get(key)
        b = (half2.get("mass_terms") or {}).get(key)
        if not isinstance(a, (int, float)) or not isinstance(b, (int, float)):
            raise RuntimeError(f"missing/non-numeric refined mass term {key}")
        value = float(a) + float(b)
        if not math.isfinite(value):
            raise RuntimeError(f"non-finite refined mass term {key}")
        terms[key] = value
    residual = (
        storage_change
        - terms["top_boundary_transfer_cm"]
        - terms["bottom_boundary_transfer_cm"]
        - terms["source_transfer_cm"]
        + terms["sink_transfer_cm"]
    )
    if not math.isfinite(residual) or abs(residual) > d3r.HARD_MASS_TOL_CM:
        raise RuntimeError(f"aggregate refined mass gate failed: {residual!r}")
    terms["all_transfer_sign"] = "positive_into_column"
    return {"storage_change_cm": storage_change, "mass_terms": terms, "unrounded_mass_residual_cm": residual}


def execute_research_trial(request: dict) -> dict:
    before = copy.deepcopy(request)
    try:
        factor, tolerance = _qualified_constants()
    except Exception as exc:
        out = _fail("TEMPORAL_CERTIFICATE_CONSTANTS_UNQUALIFIED", repr(exc))
        out["request_object_unchanged"] = request == before
        return out

    try:
        t0, t1, full_dt, ladder_index, endpoint_tolerance = d3r._match_duration(request.get("forcing_process_requests"))
    except Exception as exc:
        classification = exc.classification if isinstance(exc, d3r.RequestError) else "INVALID_REQUEST"
        out = _fail(classification, getattr(exc, "detail", repr(exc)))
        out["request_object_unchanged"] = request == before
        return out
    if ladder_index > d3r.CANONICAL_MAX_RETRIES:
        out = _fail("TIME_OUTSIDE_CERTIFICATE_INPUT_SCOPE", "D3G02 certificate input accepts full attempts 0..8; ladder level 9 is internal-half-only")
        out["request_object_unchanged"] = request == before
        return out

    half_dt = d3r.DURATION_LADDER_DAY[ladder_index + 1]
    full_req = _set_interval(request, t0, full_dt)
    half1_req = _set_interval(request, t0, half_dt)
    full = d3r.execute_research_trial(copy.deepcopy(full_req))
    half1 = d3r.execute_research_trial(copy.deepcopy(half1_req))
    if full.get("solver_disposition") != "candidate_ready" or half1.get("solver_disposition") != "candidate_ready":
        out = _fail("TEMPORAL_CERTIFICATE_COMPONENT_TRIAL_FAILED", "coarse full or first refined half was not candidate_ready", "d3g02_component_trial")
        out["component_dispositions"] = [full.get("solver_disposition"), half1.get("solver_disposition")]
        out["request_object_unchanged"] = request == before
        return out

    half2_req = _set_interval(request, t0 + half_dt, half_dt)
    half2_req["committed_state"] = copy.deepcopy(half1["candidate_hydraulic_state"])
    half2 = d3r.execute_research_trial(copy.deepcopy(half2_req))
    trials = (full, half1, half2)
    if half2.get("solver_disposition") != "candidate_ready":
        out = _fail("TEMPORAL_CERTIFICATE_COMPONENT_TRIAL_FAILED", "second refined half was not candidate_ready", "d3g02_component_trial")
        out["component_dispositions"] = [r.get("solver_disposition") for r in trials]
        out["request_object_unchanged"] = request == before
        return out
    if not all(_mass_ok(r) for r in trials):
        out = _fail("TEMPORAL_CERTIFICATE_COMPONENT_MASS_GATE_FAILED", "one or more component trials failed the hard mass gate", "d3g02_component_mass")
        out["request_object_unchanged"] = request == before
        return out
    if not all(r.get("committed_state_mutated") is False for r in trials):
        out = _fail("TEMPORAL_CERTIFICATE_OWNERSHIP_VIOLATION", "component trial reported committed-state mutation", "d3g02_ownership")
        out["request_object_unchanged"] = request == before
        return out

    coarse_theta = tuple(float(v) for v in full["candidate_hydraulic_state"]["water_content"])
    refined_theta = tuple(float(v) for v in half2["candidate_hydraulic_state"]["water_content"])
    row = request["physical_parameters"]["hydraulic_parameters"]
    span = float(row["theta_s"] - row["theta_r"])
    if not math.isfinite(span) or span <= 0.0:
        out = _fail("TEMPORAL_CERTIFICATE_NORMALIZATION_INVALID", "theta_s-theta_r must be finite and positive", "d3g02_indicator")
        out["request_object_unchanged"] = request == before
        return out
    raw = max(abs(a - b) for a, b in zip(refined_theta, coarse_theta)) / span
    indicator = factor * raw / tolerance
    if not math.isfinite(raw) or raw < 0.0 or not math.isfinite(indicator) or indicator < 0.0:
        out = _fail("TEMPORAL_CERTIFICATE_INDICATOR_INVALID", "temporal estimator or normalized indicator is non-finite/negative", "d3g02_indicator")
        out["request_object_unchanged"] = request == before
        return out

    try:
        aggregate = _aggregate_refined_mass(request["committed_state"], half2, half1, half2)
    except Exception as exc:
        out = _fail("TEMPORAL_CERTIFICATE_AGGREGATE_MASS_GATE_FAILED", repr(exc), "d3g02_aggregate_mass")
        out["request_object_unchanged"] = request == before
        return out

    result = copy.deepcopy(half2)
    result["time_interval"] = {
        "t0_day": t0,
        "t1_day": t1,
        "duration_day": full_dt,
        "coordinate_difference_day": t1 - t0,
        "endpoint_representation_tolerance_day": endpoint_tolerance,
        "duration_ladder_index": ladder_index,
        "calendar_semantics": False,
        "certificate_refined_from_two_halves": True,
    }
    result.update(aggregate)
    result["temporal_certificate_available"] = True
    result["temporal_indicator"] = indicator
    result["temporal_certificate"] = {
        "available": True,
        "method": "INTERNAL_FULL_VS_TWO_HALF_STEP_DOUBLING",
        "state_quantity": "terminal_water_content",
        "norm": "span_normalized_linf",
        "raw_estimator": raw,
        "safety_factor": factor,
        "accuracy_tolerance": tolerance,
        "indicator": indicator,
        "canonical_acceptance_threshold": 1.0,
        "candidate_route": "REFINED_TWO_HALF",
        "coarse_full_substeps": 8,
        "refined_half_substeps_each": 8,
        "effective_refined_substeps": 16,
        "full_attempt_ladder_index": ladder_index,
        "half_attempt_ladder_index": ladder_index + 1,
    }
    diagnostics = result.setdefault("solver_work_diagnostics", {})
    diagnostics["d3g02_temporal_certificate"] = True
    diagnostics["certificate_component_trial_count"] = 3
    diagnostics["certificate_candidate_route"] = "REFINED_TWO_HALF"
    diagnostics["certificate_acceptance_authority"] = "CANONICAL_RUNTIME_ONLY"
    result["accepted"] = False
    result["commit_authorized"] = False
    result["accepted_publication_authorized"] = False
    result["committed_state_mutated"] = False
    result["request_object_unchanged"] = request == before
    return result
