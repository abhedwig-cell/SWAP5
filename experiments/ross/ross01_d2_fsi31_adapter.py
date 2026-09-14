from __future__ import annotations

import copy
import importlib
import json
import math
import sys

_base = importlib.import_module("ross01_d2_fsi31_adapter_base")

# Re-export the frozen D2 implementation surface used by the qualification
# harnesses.  The base blob is byte-for-byte the pre-fix adapter; this module
# changes only the representation of the generic time coordinate presented to
# that translation-invariant research worker.
CONTRACT_ID = _base.CONTRACT_ID
CONTRACT_VERSION = _base.CONTRACT_VERSION
SOLVER_ID = _base.SOLVER_ID
MATERIAL_IDS = _base.MATERIAL_IDS
MATERIAL_ROWS = _base.MATERIAL_ROWS
N_CELLS = _base.N_CELLS
DZ_CM = _base.DZ_CM
HORIZON_DAY = _base.HORIZON_DAY
ALLOWED_SUBSTEPS = _base.ALLOWED_SUBSTEPS
SIGMA = _base.SIGMA
HARD_MASS_TOL_CM = _base.HARD_MASS_TOL_CM
BOUNDARY_ENVELOPE_FRACTION = _base.BOUNDARY_ENVELOPE_FRACTION
STATE_CONSISTENCY_TOL = _base.STATE_CONSISTENCY_TOL
REQUIRED_CAPABILITIES = _base.REQUIRED_CAPABILITIES
RequestError = _base.RequestError
_fail = _base._fail
_enforce_result_contract = _base._enforce_result_contract

TIME_ENDPOINT_ULP_MULTIPLIER = 2.0


def _finite_time(value, name: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise RequestError("INVALID_NUMERICAL_REQUEST", f"{name} must be numeric")
    value = float(value)
    if not math.isfinite(value):
        raise RequestError("INVALID_NUMERICAL_REQUEST", f"{name} must be finite")
    return value


def _qualified_time_coordinates(request: dict) -> tuple[float, float, float]:
    forcing = request.get("forcing_process_requests") if isinstance(request, dict) else None
    if not isinstance(forcing, dict):
        # Let the frozen base validator provide the canonical request-category
        # classification for malformed forcing objects.
        return 0.0, HORIZON_DAY, 0.0

    t0 = _finite_time(forcing.get("t0_day"), "t0_day")
    t1 = _finite_time(forcing.get("t1_day"), "t1_day")
    if not t1 > t0:
        raise RequestError("INVALID_TIME_INTERVAL", "t1 must be strictly greater than t0")

    expected_t1 = t0 + HORIZON_DAY
    coordinate_ulp = max(
        math.ulp(t0),
        math.ulp(t1),
        math.ulp(expected_t1),
        math.ulp(HORIZON_DAY),
    )
    endpoint_tolerance = TIME_ENDPOINT_ULP_MULTIPLIER * coordinate_ulp
    if abs(t1 - expected_t1) > endpoint_tolerance:
        raise RequestError(
            "TIME_OUTSIDE_DECLARED_SCOPE",
            (
                f"D2 qualifies duration {HORIZON_DAY} day only; "
                f"endpoint mismatch={t1 - expected_t1!r} exceeds "
                f"representation tolerance={endpoint_tolerance!r}"
            ),
        )
    return t0, t1, endpoint_tolerance


def _normalise_for_base(request: dict) -> tuple[dict, float, float, float]:
    t0, t1, endpoint_tolerance = _qualified_time_coordinates(request)
    normalised = copy.deepcopy(request)
    forcing = normalised.get("forcing_process_requests")
    if isinstance(forcing, dict):
        # The frozen RossFast research worker has no absolute-time physics in
        # this restricted profile.  Give it a local coordinate with the exact
        # qualified duration so floating-point cancellation at large t0 cannot
        # change either physics or the mass ledger.
        forcing["t0_day"] = 0.0
        forcing["t1_day"] = HORIZON_DAY
    return normalised, t0, t1, endpoint_tolerance


def validate_request(request: dict) -> dict:
    normalised, _, _, _ = _normalise_for_base(request)
    _base.validate_request(normalised)
    # Contract ownership remains with the caller's original generic
    # coordinate.  Validation never rewrites the caller object.
    return copy.deepcopy(request)


def execute_research_trial(request: dict) -> dict:
    before = copy.deepcopy(request)
    try:
        normalised, t0, t1, endpoint_tolerance = _normalise_for_base(request)
    except (RequestError, TypeError, ValueError) as exc:
        if isinstance(exc, RequestError):
            result = _fail(exc.classification, exc.detail)
        else:
            result = _fail("INVALID_REQUEST", repr(exc))
        result["request_object_unchanged"] = request == before
        return result

    result = _base.execute_research_trial(normalised)
    result["request_object_unchanged"] = request == before

    if result.get("solver_disposition") == "candidate_ready":
        result["time_interval"] = {
            "t0_day": t0,
            "t1_day": t1,
            "duration_day": HORIZON_DAY,
            "coordinate_difference_day": t1 - t0,
            "endpoint_representation_tolerance_day": endpoint_tolerance,
            "calendar_semantics": False,
            "worker_local_time_origin": 0.0,
            "worker_semantic_duration_day": HORIZON_DAY,
        }
        diagnostics = result.setdefault("solver_work_diagnostics", {})
        diagnostics["generic_time_coordinate_translation"] = True
        diagnostics["qualified_duration_normalised_exactly"] = True

    return result


def _worker_main() -> int:
    # Direct worker invocation is retained only as a research convenience.  The
    # public adapter path uses execute_research_trial(), which launches the
    # frozen base worker after generic-time validation/normalisation.
    return _base._worker_main()


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--worker":
        raise SystemExit(_worker_main())
    raise SystemExit(
        "RossFast D2 adapter is imported by qualification/runtime research harnesses; "
        "use --worker only for the isolated child process"
    )
