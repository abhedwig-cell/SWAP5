from __future__ import annotations

import copy
import math
import threading
from pathlib import Path

import ross01_d2_fsi31_adapter_base as base

D3R_ADAPTER_ID = "RossFastFsi31D3RBoundedDurationAdapter"
D2_AUTHORITY = "4cdeeec8b3ab5267196ab9c15942b4ee6d23c587"
D3_AUTHORITY = "21bf6ec4a0a847b60b8713dba832f0b94d07f049"
CANONICAL_RETRY_SCALE = 0.5
CANONICAL_MAX_RETRIES = 8
TIME_ENDPOINT_ULP_MULTIPLIER = 2.0
DURATION_LADDER_DAY = tuple(base.HORIZON_DAY / (2 ** k) for k in range(CANONICAL_MAX_RETRIES + 2))

CONTRACT_ID = base.CONTRACT_ID
CONTRACT_VERSION = base.CONTRACT_VERSION
SOLVER_ID = base.SOLVER_ID
MATERIAL_IDS = base.MATERIAL_IDS
MATERIAL_ROWS = base.MATERIAL_ROWS
N_CELLS = base.N_CELLS
DZ_CM = base.DZ_CM
ALLOWED_SUBSTEPS = base.ALLOWED_SUBSTEPS
SIGMA = base.SIGMA
HARD_MASS_TOL_CM = base.HARD_MASS_TOL_CM
BOUNDARY_ENVELOPE_FRACTION = base.BOUNDARY_ENVELOPE_FRACTION
STATE_CONSISTENCY_TOL = base.STATE_CONSISTENCY_TOL
REQUIRED_CAPABILITIES = base.REQUIRED_CAPABILITIES
RequestError = base.RequestError

_BASE_VALIDATION_LOCK = threading.Lock()
_FROZEN_D2_HORIZON = float(base.HORIZON_DAY)
_D3R_WORKER = Path(__file__).resolve().with_name("ross01_d3r_duration_worker.py")


def _finite_time(value, name: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise RequestError("INVALID_NUMERICAL_REQUEST", f"{name} must be numeric")
    value = float(value)
    if not math.isfinite(value):
        raise RequestError("INVALID_NUMERICAL_REQUEST", f"{name} must be finite")
    return value


def _match_duration(forcing: dict) -> tuple[float, float, float, int, float]:
    if not isinstance(forcing, dict):
        raise RequestError("INVALID_FORCING_REQUEST", "forcing_process_requests must be an object")
    t0 = _finite_time(forcing.get("t0_day"), "t0_day")
    t1 = _finite_time(forcing.get("t1_day"), "t1_day")
    if not t1 > t0:
        raise RequestError("INVALID_TIME_INTERVAL", "t1 must be strictly greater than t0")

    nearest = None
    for index, duration in enumerate(DURATION_LADDER_DAY):
        expected_t1 = t0 + duration
        coordinate_ulp = max(math.ulp(t0), math.ulp(t1), math.ulp(expected_t1), math.ulp(duration))
        tolerance = TIME_ENDPOINT_ULP_MULTIPLIER * coordinate_ulp
        mismatch = abs(t1 - expected_t1)
        candidate = (mismatch, duration, index, tolerance)
        if nearest is None or mismatch < nearest[0]:
            nearest = candidate
        if mismatch <= tolerance:
            return t0, t1, duration, index, tolerance

    assert nearest is not None
    raise RequestError(
        "TIME_OUTSIDE_DECLARED_SCOPE",
        (
            "D3R accepts only the current-canonical bounded duration ladder; "
            f"nearest duration={nearest[1]!r}, endpoint mismatch={nearest[0]!r}, tolerance={nearest[3]!r}"
        ),
    )


def _normalise_for_base(request: dict) -> tuple[dict, float, float, float, int, float]:
    if not isinstance(request, dict):
        raise RequestError("INVALID_REQUEST", "request must be an object")
    t0, t1, semantic_duration, ladder_index, endpoint_tolerance = _match_duration(
        request.get("forcing_process_requests")
    )
    normalised = copy.deepcopy(request)
    forcing = normalised["forcing_process_requests"]
    forcing["t0_day"] = 0.0
    forcing["t1_day"] = semantic_duration
    return normalised, t0, t1, semantic_duration, ladder_index, endpoint_tolerance


def validate_request(request: dict) -> dict:
    normalised, _, _, semantic_duration, _, _ = _normalise_for_base(request)
    with _BASE_VALIDATION_LOCK:
        previous = base.HORIZON_DAY
        base.HORIZON_DAY = semantic_duration
        try:
            base.validate_request(normalised)
        finally:
            base.HORIZON_DAY = previous
    return copy.deepcopy(request)


def execute_research_trial(request: dict) -> dict:
    before = copy.deepcopy(request)
    try:
        normalised, t0, t1, semantic_duration, ladder_index, endpoint_tolerance = _normalise_for_base(request)
        # Reuse the frozen D2 fresh-process launcher. The only D3R execution
        # extension is a duration-aware child entry point that repeats the D2
        # preflight with the already-admitted ladder duration before calling the
        # unchanged RossFast worker computation.
        with _BASE_VALIDATION_LOCK:
            previous_horizon = base.HORIZON_DAY
            previous_file = base.__file__
            base.HORIZON_DAY = semantic_duration
            base.__file__ = str(_D3R_WORKER)
            try:
                base.validate_request(normalised)
                result = base.execute_research_trial(normalised)
            finally:
                base.HORIZON_DAY = previous_horizon
                base.__file__ = previous_file
    except (RequestError, TypeError, ValueError) as exc:
        if isinstance(exc, RequestError):
            result = base._fail(exc.classification, exc.detail)
        else:
            result = base._fail("INVALID_REQUEST", repr(exc))
        result["request_object_unchanged"] = request == before
        return result

    result["request_object_unchanged"] = request == before
    if result.get("solver_disposition") == "candidate_ready":
        result["time_interval"] = {
            "t0_day": t0,
            "t1_day": t1,
            "duration_day": semantic_duration,
            "coordinate_difference_day": t1 - t0,
            "endpoint_representation_tolerance_day": endpoint_tolerance,
            "duration_ladder_index": ladder_index,
            "calendar_semantics": False,
            "worker_local_time_origin": 0.0,
            "worker_semantic_duration_day": semantic_duration,
        }
        diagnostics = result.setdefault("solver_work_diagnostics", {})
        diagnostics["d3r_duration_ladder"] = True
        diagnostics["duration_ladder_index"] = ladder_index
        diagnostics["canonical_retry_scale"] = CANONICAL_RETRY_SCALE
        diagnostics["canonical_max_retries"] = CANONICAL_MAX_RETRIES
        diagnostics["d2_fresh_process_launcher_reused"] = True
        diagnostics["d3r_duration_worker_preflight"] = True
        diagnostics["generic_time_coordinate_translation"] = True
    return result


def duration_ladder_metadata() -> dict:
    return {
        "initial_duration_day": _FROZEN_D2_HORIZON,
        "retry_scale": CANONICAL_RETRY_SCALE,
        "max_retries": CANONICAL_MAX_RETRIES,
        "unique_solver_durations_day": list(DURATION_LADDER_DAY),
        "minimum_duration_day": DURATION_LADDER_DAY[-1],
        "count": len(DURATION_LADDER_DAY),
        "derivation": "initial / 2^k for k=0..9; full attempts k=0..8 plus half attempts k=1..9",
    }
