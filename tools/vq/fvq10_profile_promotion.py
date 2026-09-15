#!/usr/bin/env python3
"""Qualification-only temporal-profile promotion mechanics for F-VQ10.

This module validates candidate structure and held-out raw observations. It does
not provide or infer production temporal limits and cannot promote production
reference execution.
"""
from __future__ import annotations

import hashlib
import json
import math
from copy import deepcopy

METRIC_UNITS = {
    "h_cm": "cm", "theta": "1", "pond_cm": "cm", "gwl_cm": "cm",
    "volact_cm": "cm", "ldwet_cm": "cm", "spev_cm": "cm", "saev_cm": "cm",
}
METRICS = tuple(METRIC_UNITS)
RAW_RECORD_TYPE = "REAL_B1_10_FULL_VS_TWO_HALF_RAW_OBSERVATION"
CANDIDATE_RECORD_TYPE = "B1_10_TEMPORAL_PROFILE_CANDIDATE"
ALLOWED_ORIGIN = "INDEPENDENT_SCIENTIFIC_OR_ACCURACY_RATIONALE"
HARD_MASS_LIMIT_CM = 1.0e-6


def _finite(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value))


def _candidate_payload(candidate: dict) -> dict:
    keys = (
        "record_type", "profile_scope", "execution_environment_scope",
        "optional_process_scope", "calibration_observation_ids",
        "validation_observation_ids", "limits",
    )
    return {key: deepcopy(candidate.get(key)) for key in keys}


def candidate_hash(candidate: dict) -> str:
    raw = json.dumps(_candidate_payload(candidate), sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def validate_candidate(candidate: dict, *, require_frozen_hash: bool = True) -> list[str]:
    errors: list[str] = []
    if candidate.get("record_type") != CANDIDATE_RECORD_TYPE:
        errors.append("candidate_record_type")
    if not candidate.get("profile_scope"):
        errors.append("profile_scope_missing")
    if not candidate.get("execution_environment_scope"):
        errors.append("execution_environment_scope_missing")
    optional = candidate.get("optional_process_scope")
    if not isinstance(optional, dict) or "complete" not in optional:
        errors.append("optional_process_scope_missing")

    cal = candidate.get("calibration_observation_ids")
    val = candidate.get("validation_observation_ids")
    if not isinstance(cal, list) or not cal:
        errors.append("calibration_set_empty")
        cal = []
    if not isinstance(val, list) or not val:
        errors.append("validation_set_empty")
        val = []
    if len(cal) != len(set(cal)) or len(val) != len(set(val)):
        errors.append("observation_ids_not_unique")
    if set(cal) & set(val):
        errors.append("calibration_validation_overlap")

    limits = candidate.get("limits")
    if not isinstance(limits, dict) or set(limits) != set(METRICS):
        errors.append("limit_metric_set")
    else:
        for metric in METRICS:
            item = limits[metric]
            if not isinstance(item, dict):
                errors.append(f"limit_shape:{metric}")
                continue
            value = item.get("value")
            if not _finite(value) or float(value) < 0.0:
                errors.append(f"limit_nonnegative_finite:{metric}")
            if item.get("unit") != METRIC_UNITS[metric]:
                errors.append(f"limit_unit:{metric}")
            if item.get("origin_class") != ALLOWED_ORIGIN:
                errors.append(f"limit_origin:{metric}")
            if not isinstance(item.get("rationale"), str) or not item["rationale"].strip():
                errors.append(f"limit_rationale:{metric}")
            refs = item.get("evidence_refs")
            if not isinstance(refs, list) or not refs or not all(isinstance(x, str) and x.strip() for x in refs):
                errors.append(f"limit_evidence_refs:{metric}")

    if require_frozen_hash:
        observed = candidate.get("frozen_profile_hash")
        if observed != candidate_hash(candidate):
            errors.append("frozen_profile_hash_mismatch")
    return errors


def validate_raw_observation(observation: dict) -> list[str]:
    errors: list[str] = []
    if observation.get("record_type") != RAW_RECORD_TYPE:
        errors.append("raw_record_type")
    if observation.get("temporal_numeric_limits") is not None:
        errors.append("raw_contains_temporal_limits")
    if observation.get("normalized_temporal_score") is not None:
        errors.append("raw_contains_temporal_score")
    if observation.get("raw_observation_is_production_temporal_acceptance") is not False:
        errors.append("raw_acceptance_flag")
    diffs = observation.get("endpoint_differences", {})
    if set(diffs) != set(METRICS):
        errors.append("raw_metric_set")
    else:
        for metric, value in diffs.items():
            if not _finite(value) or float(value) < 0.0:
                errors.append(f"raw_metric_nonnegative_finite:{metric}")
    for path in ("full_path", "two_half_path"):
        mass = observation.get("mass", {}).get(path, {})
        if mass.get("pass") is not True:
            errors.append(f"mass_gate:{path}")
        if mass.get("hard_limit_cm") != HARD_MASS_LIMIT_CM:
            errors.append(f"mass_limit:{path}")
        residual = mass.get("residual_cm")
        if not _finite(residual) or abs(float(residual)) > HARD_MASS_LIMIT_CM:
            errors.append(f"mass_residual:{path}")
    scope = observation.get("scope", {})
    if scope.get("compatible") is not True or scope.get("water_scope_complete") is not True:
        errors.append("water_scope_incomplete")
    if scope.get("allocation_mismatches") != 0:
        errors.append("allocation_mismatch")
    provenance = observation.get("provenance")
    if not isinstance(provenance, dict) or not provenance:
        errors.append("provenance_missing")
    return errors


def normalized_ratio(delta: float, limit: float) -> float:
    if not _finite(delta) or not _finite(limit) or delta < 0.0 or limit < 0.0:
        return math.inf
    if limit == 0.0:
        return 0.0 if delta == 0.0 else math.inf
    return delta / limit


def assess_observation(candidate: dict, observation: dict) -> dict:
    candidate_errors = validate_candidate(candidate)
    observation_errors = validate_raw_observation(observation)
    if candidate_errors or observation_errors:
        return {"complete": False, "accepted": False, "errors": candidate_errors + observation_errors}
    ratios = {
        metric: normalized_ratio(float(observation["endpoint_differences"][metric]), float(candidate["limits"][metric]["value"]))
        for metric in METRICS
    }
    normalized_error = max(ratios.values())
    metric_norm_pass = math.isfinite(normalized_error) and normalized_error <= 1.0
    process_complete = observation.get("scope", {}).get("process_scope_complete") is True
    candidate_complete_scope = candidate.get("optional_process_scope", {}).get("complete") is True
    return {
        "complete": True,
        "accepted": metric_norm_pass and process_complete and candidate_complete_scope,
        "metric_norm_pass": metric_norm_pass,
        "process_scope_complete": process_complete,
        "candidate_optional_process_scope_complete": candidate_complete_scope,
        "normalized_error": normalized_error,
        "ratios": ratios,
        "production_promotion_by_this_result": False,
    }


def validate_held_out_set(candidate: dict, observations_by_id: dict[str, dict]) -> dict:
    candidate_errors = validate_candidate(candidate)
    if candidate_errors:
        return {"complete": False, "accepted": False, "errors": candidate_errors}
    validation_ids = candidate["validation_observation_ids"]
    missing = [obs_id for obs_id in validation_ids if obs_id not in observations_by_id]
    if missing:
        return {"complete": False, "accepted": False, "errors": [f"validation_observation_missing:{x}" for x in missing]}
    results = {obs_id: assess_observation(candidate, observations_by_id[obs_id]) for obs_id in validation_ids}
    return {
        "complete": all(result.get("complete") is True for result in results.values()),
        "accepted": all(result.get("accepted") is True for result in results.values()),
        "results": results,
        "candidate_profile_hash": candidate_hash(candidate),
        "production_profile_promoted": False,
        "canonical_reference_admitted": False,
    }
