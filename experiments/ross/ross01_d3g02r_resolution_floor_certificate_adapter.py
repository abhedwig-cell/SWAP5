from __future__ import annotations

import copy
import json
import math
from pathlib import Path

import ross01_d3r_fsi31_duration_adapter as d3r
import ross01_d3g02_temporal_certificate_adapter as d3g02

_AUTHORITY = Path(__file__).resolve().parents[2] / "integration" / "f-ross" / "F-ROSS01_D3G02R_BOUND_AUTHORITY.json"
EXPECTED_RESOLUTION_FLOOR = 1.0e-10
EXPECTED_ACCURACY_TOLERANCE = 1.0e-5


def _fail(classification: str, detail: str, stage: str = "d3g02r_preflight") -> dict:
    out = d3r.base._fail(classification, detail, stage)
    out["temporal_certificate_available"] = False
    out["temporal_indicator"] = None
    out["temporal_certificate"] = {
        "available": False,
        "method": "RESOLUTION_FLOOR_BOUNDED_FULL_VS_TWO_HALF_STEP_DOUBLING",
        "reason": classification,
    }
    return out


def _qualified_policy() -> tuple[float, float]:
    try:
        authority = json.loads(_AUTHORITY.read_text())
    except Exception as exc:
        raise RuntimeError(f"qualified resolution-floor authority unavailable: {exc!r}") from exc
    if authority.get("status") != "QUALIFIED_BOUND" or authority.get("qualification_pass") is not True:
        raise RuntimeError("resolution-floor bound has no positive qualification authority")
    floor = authority.get("resolution_floor")
    tolerance = authority.get("accuracy_tolerance")
    if not isinstance(floor, (int, float)) or not math.isfinite(float(floor)) or float(floor) <= 0.0:
        raise RuntimeError("qualified resolution floor missing/nonpositive/nonfinite")
    if not isinstance(tolerance, (int, float)) or not math.isfinite(float(tolerance)) or float(tolerance) <= 0.0:
        raise RuntimeError("qualified accuracy tolerance missing/nonpositive/nonfinite")
    if float(floor) != EXPECTED_RESOLUTION_FLOOR:
        raise RuntimeError("qualified resolution floor differs from precommitted 1e-10")
    if float(tolerance) != EXPECTED_ACCURACY_TOLERANCE:
        raise RuntimeError("qualified accuracy tolerance differs from precommitted 1e-5")
    return float(floor), float(tolerance)


def execute_research_trial(request: dict) -> dict:
    before = copy.deepcopy(request)
    try:
        resolution_floor, tolerance = _qualified_policy()
    except Exception as exc:
        out = _fail("TEMPORAL_CERTIFICATE_POLICY_UNQUALIFIED", repr(exc))
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
        out = _fail("TIME_OUTSIDE_CERTIFICATE_INPUT_SCOPE", "D3G02R certificate accepts full attempts 0..8; ladder level 9 is internal-half-only")
        out["request_object_unchanged"] = request == before
        return out

    half_dt = d3r.DURATION_LADDER_DAY[ladder_index + 1]
    full_req = d3g02._set_interval(request, t0, full_dt)
    half1_req = d3g02._set_interval(request, t0, half_dt)
    full = d3r.execute_research_trial(copy.deepcopy(full_req))
    half1 = d3r.execute_research_trial(copy.deepcopy(half1_req))
    if full.get("solver_disposition") != "candidate_ready" or half1.get("solver_disposition") != "candidate_ready":
        out = _fail("TEMPORAL_CERTIFICATE_COMPONENT_TRIAL_FAILED", "coarse full or first refined half was not candidate_ready", "d3g02r_component_trial")
        out["component_dispositions"] = [full.get("solver_disposition"), half1.get("solver_disposition")]
        out["request_object_unchanged"] = request == before
        return out

    half2_req = d3g02._set_interval(request, t0 + half_dt, half_dt)
    half2_req["committed_state"] = copy.deepcopy(half1["candidate_hydraulic_state"])
    half2 = d3r.execute_research_trial(copy.deepcopy(half2_req))
    trials = (full, half1, half2)
    if half2.get("solver_disposition") != "candidate_ready":
        out = _fail("TEMPORAL_CERTIFICATE_COMPONENT_TRIAL_FAILED", "second refined half was not candidate_ready", "d3g02r_component_trial")
        out["component_dispositions"] = [r.get("solver_disposition") for r in trials]
        out["request_object_unchanged"] = request == before
        return out
    if not all(d3g02._mass_ok(r) for r in trials):
        out = _fail("TEMPORAL_CERTIFICATE_COMPONENT_MASS_GATE_FAILED", "one or more component trials failed hard mass gate", "d3g02r_component_mass")
        out["request_object_unchanged"] = request == before
        return out
    if not all(r.get("committed_state_mutated") is False for r in trials):
        out = _fail("TEMPORAL_CERTIFICATE_OWNERSHIP_VIOLATION", "component trial reported committed-state mutation", "d3g02r_ownership")
        out["request_object_unchanged"] = request == before
        return out

    coarse_theta = tuple(float(v) for v in full["candidate_hydraulic_state"]["water_content"])
    refined_theta = tuple(float(v) for v in half2["candidate_hydraulic_state"]["water_content"])
    row = request["physical_parameters"]["hydraulic_parameters"]
    span = float(row["theta_s"] - row["theta_r"])
    if not math.isfinite(span) or span <= 0.0:
        out = _fail("TEMPORAL_CERTIFICATE_NORMALIZATION_INVALID", "theta_s-theta_r must be finite and positive", "d3g02r_indicator")
        out["request_object_unchanged"] = request == before
        return out

    raw = max(abs(a - b) for a, b in zip(refined_theta, coarse_theta)) / span
    bound = max(raw, resolution_floor)
    indicator = bound / tolerance
    if not all(math.isfinite(v) and v >= 0.0 for v in (raw, bound, indicator)):
        out = _fail("TEMPORAL_CERTIFICATE_INDICATOR_INVALID", "raw estimator, bound or normalized indicator is non-finite/negative", "d3g02r_indicator")
        out["request_object_unchanged"] = request == before
        return out

    try:
        aggregate = d3g02._aggregate_refined_mass(request["committed_state"], half2, half1, half2)
    except Exception as exc:
        out = _fail("TEMPORAL_CERTIFICATE_AGGREGATE_MASS_GATE_FAILED", repr(exc), "d3g02r_aggregate_mass")
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
        "method": "RESOLUTION_FLOOR_BOUNDED_FULL_VS_TWO_HALF_STEP_DOUBLING",
        "state_quantity": "terminal_water_content",
        "norm": "span_normalized_linf",
        "raw_estimator": raw,
        "preexisting_resolution_floor": resolution_floor,
        "candidate_error_bound": bound,
        "accuracy_tolerance": tolerance,
        "indicator": indicator,
        "canonical_acceptance_threshold": 1.0,
        "bound_branch": "RAW_ESTIMATOR" if raw >= resolution_floor else "PREEXISTING_GATE_F_RESOLUTION_FLOOR",
        "candidate_route": "REFINED_TWO_HALF",
        "coarse_full_substeps": 8,
        "refined_half_substeps_each": 8,
        "effective_refined_substeps": 16,
        "full_attempt_ladder_index": ladder_index,
        "half_attempt_ladder_index": ladder_index + 1,
        "scope": "EXACT_D3R_QUALIFIED_DOMAIN_ONLY",
    }
    diagnostics = result.setdefault("solver_work_diagnostics", {})
    diagnostics["d3g02r_resolution_floor_certificate"] = True
    diagnostics["certificate_component_trial_count"] = 3
    diagnostics["certificate_candidate_route"] = "REFINED_TWO_HALF"
    diagnostics["certificate_acceptance_authority"] = "CANONICAL_RUNTIME_ONLY"
    result["accepted"] = False
    result["commit_authorized"] = False
    result["accepted_publication_authorized"] = False
    result["committed_state_mutated"] = False
    result["request_object_unchanged"] = request == before
    return result
