from __future__ import annotations

import copy
import hashlib
import json
import math
import subprocess
import sys
from pathlib import Path

CONTRACT_ID = "SoilWaterSolverResearchContract"
CONTRACT_VERSION = "1.0.0"
SOLVER_ID = "RossFast"
MATERIAL_IDS = ("B01", "B12", "O01", "O05", "O14", "O18")
N_CELLS = 16
DZ_CM = 10.0
HORIZON_DAY = 0.0016
ALLOWED_SUBSTEPS = (2, 4, 8, 16)
SIGMA = 0.5
HARD_MASS_TOL_CM = 1.0e-12
BOUNDARY_ENVELOPE_FRACTION = 0.02
STATE_CONSISTENCY_TOL = 2.0e-12

# Exact frozen F-ROSS01 C1 rows used by D1.  Keeping the six admitted rows
# here makes the adapter request seam file-free and prevents a material ID from
# silently selecting altered constitutive parameters.
MATERIAL_ROWS = {
    "B01": {"sfu": "B01", "theta_r": 0.02, "theta_s": 0.427494, "alpha_per_cm": 0.021659, "n": 1.734737, "ksatfit_cm_per_day": 31.225016, "ksatexm_cm_per_day": 312.25016, "lambda": 0.98087, "h_enpr_cm": 0.0},
    "B12": {"sfu": "B12", "theta_r": 0.01, "theta_s": 0.529749, "alpha_per_cm": 0.016562, "n": 1.090671, "ksatfit_cm_per_day": 2.245895, "ksatexm_cm_per_day": 179.6716, "lambda": -4.493581, "h_enpr_cm": 0.0},
    "O01": {"sfu": "O01", "theta_r": 0.01, "theta_s": 0.365847, "alpha_per_cm": 0.015987, "n": 2.162751, "ksatfit_cm_per_day": 22.322154, "ksatexm_cm_per_day": 223.22154, "lambda": 2.867967, "h_enpr_cm": 0.0},
    "O05": {"sfu": "O05", "theta_r": 0.01, "theta_s": 0.336701, "alpha_per_cm": 0.030304, "n": 2.887502, "ksatfit_cm_per_day": 17.418504, "ksatexm_cm_per_day": 174.18504, "lambda": 0.0736, "h_enpr_cm": 0.0},
    "O14": {"sfu": "O14", "theta_r": 0.01, "theta_s": 0.393878, "alpha_per_cm": 0.003288, "n": 1.616573, "ksatfit_cm_per_day": 2.495984, "ksatexm_cm_per_day": 4.991968, "lambda": 0.514012, "h_enpr_cm": 0.0},
    "O18": {"sfu": "O18", "theta_r": 0.01, "theta_s": 0.580278, "alpha_per_cm": 0.012657, "n": 1.316172, "ksatfit_cm_per_day": 35.951279, "ksatexm_cm_per_day": 107.853837, "lambda": -0.785534, "h_enpr_cm": 0.0},
}

REQUIRED_CAPABILITIES = {
    "top.prescribed_flux",
    "bottom.prescribed_flux",
    "bottom_exchange.candidate_flux",
}


class RequestError(ValueError):
    def __init__(self, classification: str, detail: str):
        super().__init__(detail)
        self.classification = classification
        self.detail = detail


def _canonical_json(value) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def _digest(value) -> str:
    return hashlib.sha256(_canonical_json(value).encode("utf-8")).hexdigest()


def _finite_number(value, name: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise RequestError("INVALID_NUMERICAL_REQUEST", f"{name} must be numeric")
    value = float(value)
    if not math.isfinite(value):
        raise RequestError("INVALID_NUMERICAL_REQUEST", f"{name} must be finite")
    return value


def _fail(classification: str, detail: str, stage: str = "adapter_preflight") -> dict:
    return {
        "contract_id": CONTRACT_ID,
        "contract_version": CONTRACT_VERSION,
        "solver_id": SOLVER_ID,
        "solver_disposition": "failed",
        "failure_classification": classification,
        "failure_detail": detail,
        "failure_stage": stage,
        "candidate_hydraulic_state": None,
        "actual_top_flux": None,
        "candidate_bottom_flux": None,
        "process_hydraulic_view": None,
        "storage_change_cm": None,
        "mass_terms": None,
        "unrounded_mass_residual_cm": None,
        "accepted": False,
        "commit_authorized": False,
        "accepted_publication_authorized": False,
        "committed_state_mutated": False,
        "implicit_full_richards_fallback": False,
    }


def _validate_material_row(material_id: str, supplied: dict) -> None:
    expected = MATERIAL_ROWS[material_id]
    if supplied != expected:
        raise RequestError(
            "CONSTITUTIVE_MATERIAL_OUTSIDE_DECLARED_SCOPE",
            f"{material_id} parameters do not exactly match the frozen F-ROSS01 C1 row",
        )


def validate_request(request: dict) -> dict:
    if not isinstance(request, dict):
        raise RequestError("INVALID_REQUEST", "request must be an object")

    required_top = {
        "contract_id",
        "contract_version",
        "requested_capabilities",
        "physical_parameters",
        "committed_state",
        "forcing_process_requests",
        "numerical_configuration",
        "worker_job_scratch",
    }
    missing = sorted(required_top - set(request))
    if missing:
        raise RequestError("MISSING_CAPABILITY_OR_CATEGORY", f"missing request fields: {missing}")

    if request["contract_id"] != CONTRACT_ID or request["contract_version"] != CONTRACT_VERSION:
        raise RequestError("CONTRACT_MISMATCH", "request is not F-SI31 v1")

    requested = request["requested_capabilities"]
    if not isinstance(requested, list) or not REQUIRED_CAPABILITIES.issubset(set(requested)):
        raise RequestError(
            "MISSING_REQUIRED_CAPABILITY",
            "top.prescribed_flux, bottom.prescribed_flux and bottom_exchange.candidate_flux must be explicit",
        )
    unknown = set(requested) - (REQUIRED_CAPABILITIES | {"rossfast.local_terminal_preconditioner"})
    if unknown:
        raise RequestError("UNSUPPORTED_CAPABILITY", f"unsupported requested capabilities: {sorted(unknown)}")

    physical = request["physical_parameters"]
    if not isinstance(physical, dict):
        raise RequestError("INVALID_PHYSICAL_PARAMETERS", "physical_parameters must be an object")
    material_id = physical.get("material_id")
    if material_id not in MATERIAL_IDS:
        raise RequestError(
            "CONSTITUTIVE_MATERIAL_OUTSIDE_DECLARED_SCOPE",
            f"material {material_id!r} is outside {MATERIAL_IDS}",
        )
    _validate_material_row(material_id, physical.get("hydraulic_parameters"))
    if physical.get("constitutive_family") != "UNIMODAL_MUALEM_VAN_GENUCHTEN_USING_KSATFIT_WITH_KSATEXM_DISABLED":
        raise RequestError("CONSTITUTIVE_MATERIAL_OUTSIDE_DECLARED_SCOPE", "unsupported constitutive family")
    grid = physical.get("grid")
    if not isinstance(grid, dict):
        raise RequestError("GRID_GEOMETRY_OUTSIDE_DECLARED_SCOPE", "grid must be an object")
    if grid.get("dimension") != "1D_VERTICAL" or grid.get("n_cells") != N_CELLS or grid.get("uniform_dz_cm") != DZ_CM:
        raise RequestError(
            "GRID_GEOMETRY_OUTSIDE_DECLARED_SCOPE",
            "D2 requires a 1D vertical uniform 16-cell grid with dz=10.0 cm",
        )
    if physical.get("active_physics") != ["unsaturated_soil_water"]:
        raise RequestError("PHYSICS_OUTSIDE_DECLARED_SCOPE", "only unsaturated_soil_water is active in D2")

    committed = request["committed_state"]
    if not isinstance(committed, dict):
        raise RequestError("INVALID_COMMITTED_STATE", "committed_state must be an object")
    heads = committed.get("pressure_head_cm")
    theta = committed.get("water_content")
    if not isinstance(heads, list) or not isinstance(theta, list) or len(heads) != N_CELLS or len(theta) != N_CELLS:
        raise RequestError("INVALID_COMMITTED_STATE", "pressure_head_cm and water_content must each contain 16 values")
    for index, value in enumerate(heads):
        _finite_number(value, f"pressure_head_cm[{index}]")
    for index, value in enumerate(theta):
        _finite_number(value, f"water_content[{index}]")
    if committed.get("ponding_depth_cm") is not None or committed.get("groundwater_level_cm") is not None:
        raise RequestError("PHYSICS_OUTSIDE_DECLARED_SCOPE", "ponding and groundwater-level state are unsupported")

    forcing = request["forcing_process_requests"]
    if not isinstance(forcing, dict):
        raise RequestError("INVALID_FORCING_REQUEST", "forcing_process_requests must be an object")
    t0 = _finite_number(forcing.get("t0_day"), "t0_day")
    t1 = _finite_number(forcing.get("t1_day"), "t1_day")
    if not t1 > t0:
        raise RequestError("INVALID_TIME_INTERVAL", "t1 must be strictly greater than t0")
    if not math.isclose(t1 - t0, HORIZON_DAY, rel_tol=0.0, abs_tol=2.0e-15):
        raise RequestError("TIME_OUTSIDE_DECLARED_SCOPE", f"D2 qualifies duration {HORIZON_DAY} day only")

    top = forcing.get("top_boundary")
    bottom = forcing.get("bottom_boundary")
    if not isinstance(top, dict) or top.get("mode") != "top.prescribed_flux":
        raise RequestError("UNSUPPORTED_TOP_BOUNDARY", "only top.prescribed_flux is supported")
    if not isinstance(bottom, dict) or bottom.get("mode") != "bottom.prescribed_flux":
        mode = bottom.get("mode") if isinstance(bottom, dict) else None
        raise RequestError("UNSUPPORTED_BOTTOM_BOUNDARY", f"unsupported bottom mode {mode!r}")
    _finite_number(top.get("q_top_cm_per_day"), "q_top_cm_per_day")
    _finite_number(bottom.get("qbot_cm_per_day"), "qbot_cm_per_day")
    if forcing.get("general_sources_sinks") not in (None, "none"):
        raise RequestError("UNSUPPORTED_SOURCES_SINKS", "general sources/sinks are unsupported in D2")
    if forcing.get("root_sink") not in (None, "none"):
        raise RequestError("UNSUPPORTED_ROOT_SINK", "root sink is unsupported in D2")

    pre = forcing.get("local_terminal_preconditioner", {"requested": False, "required": False})
    if not isinstance(pre, dict) or not isinstance(pre.get("requested", False), bool) or not isinstance(pre.get("required", False), bool):
        raise RequestError("INVALID_PRECONDITIONER_REQUEST", "local_terminal_preconditioner flags must be boolean")
    if pre.get("required", False) and not pre.get("requested", False):
        raise RequestError("INVALID_PRECONDITIONER_REQUEST", "required local-terminal metadata must also be requested")
    if pre.get("requested", False) and "rossfast.local_terminal_preconditioner" not in requested:
        raise RequestError("MISSING_REQUIRED_CAPABILITY", "local-terminal metadata must be explicitly requested as a RossFast extension")

    numerical = request["numerical_configuration"]
    if not isinstance(numerical, dict):
        raise RequestError("INVALID_NUMERICAL_REQUEST", "numerical_configuration must be an object")
    step_count = numerical.get("equal_internal_substeps")
    if step_count not in ALLOWED_SUBSTEPS:
        raise RequestError("INVALID_NUMERICAL_REQUEST", f"equal_internal_substeps must be one of {ALLOWED_SUBSTEPS}")
    if numerical.get("sigma") != SIGMA:
        raise RequestError("INVALID_NUMERICAL_REQUEST", f"sigma must equal {SIGMA}")
    mass_tol = _finite_number(numerical.get("mass_tolerance_cm"), "mass_tolerance_cm")
    if mass_tol <= 0.0 or mass_tol > HARD_MASS_TOL_CM:
        raise RequestError("INVALID_NUMERICAL_REQUEST", "mass tolerance must be positive and may not exceed 1e-12 cm")
    if numerical.get("deterministic_replay") != "contract_equivalent":
        raise RequestError("INVALID_NUMERICAL_REQUEST", "D2 declares contract_equivalent replay")

    scratch = request["worker_job_scratch"]
    if not isinstance(scratch, dict):
        raise RequestError("INVALID_SCRATCH_REQUEST", "worker_job_scratch must be an object")
    if scratch.get("persistent", False):
        raise RequestError("PERSISTENT_SCRATCH_FORBIDDEN", "scratch may not persist per column")
    if scratch.get("warm_start_payload") not in (None, {}):
        raise RequestError("PERSISTENT_SCRATCH_FORBIDDEN", "D2 does not accept persistent warm-start payloads")

    return copy.deepcopy(request)


def _enforce_result_contract(request: dict, worker_result: dict) -> dict:
    result = copy.deepcopy(worker_result)
    result.setdefault("accepted", False)
    result.setdefault("commit_authorized", False)
    result.setdefault("accepted_publication_authorized", False)
    result.setdefault("committed_state_mutated", False)
    result.setdefault("implicit_full_richards_fallback", False)

    if result.get("accepted") or result.get("commit_authorized") or result.get("accepted_publication_authorized"):
        return _fail("SOLVER_OWNERSHIP_VIOLATION", "RossFast result attempted runtime acceptance/commit/publication", "adapter_postflight")

    if result.get("solver_disposition") != "candidate_ready":
        result["candidate_hydraulic_state"] = None
        result["process_hydraulic_view"] = None
        result["actual_top_flux"] = None
        result["candidate_bottom_flux"] = None
        return result

    residual = result.get("unrounded_mass_residual_cm")
    if not isinstance(residual, (int, float)) or not math.isfinite(float(residual)) or abs(float(residual)) > HARD_MASS_TOL_CM:
        return _fail("HARD_MASS_GATE_FAILED", "candidate mass residual exceeds the non-relaxable D2 gate", "adapter_postflight")

    pre_request = request["forcing_process_requests"].get(
        "local_terminal_preconditioner", {"requested": False, "required": False}
    )
    if pre_request.get("requested", False):
        metadata = result.get("local_terminal_preconditioner")
        valid = (
            isinstance(metadata, dict)
            and metadata.get("scope") == "LOCAL_TERMINAL_SUBSTEP_ONLY"
            and metadata.get("method") == "SAME_FACTORIZATION_DIRECT_QBOT_BACKSOLVE"
            and metadata.get("whole_window_authority") is False
            and metadata.get("use") == "BOUNDED_PROPOSAL_PRECONDITIONER_ONLY"
        )
        if valid and metadata.get("available"):
            value = metadata.get("dh_bottom_dqbot_day")
            valid = isinstance(value, (int, float)) and math.isfinite(float(value)) and float(value) > 0.0
        if pre_request.get("required", False) and (not valid or not metadata.get("available", False)):
            return _fail(
                "LOCAL_TERMINAL_TANGENT_UNAVAILABLE_OR_INVALID",
                "required D1 local-terminal preconditioner metadata is unavailable, non-smooth or invalid",
                "adapter_postflight",
            )
        if not valid:
            result["local_terminal_preconditioner"] = {
                "available": False,
                "scope": "LOCAL_TERMINAL_SUBSTEP_ONLY",
                "method": "SAME_FACTORIZATION_DIRECT_QBOT_BACKSOLVE",
                "whole_window_authority": False,
                "use": "BOUNDED_PROPOSAL_PRECONDITIONER_ONLY",
                "reason": "UNAVAILABLE_OR_INVALID",
            }

    return result


def execute_research_trial(request: dict) -> dict:
    before = copy.deepcopy(request)
    try:
        validated = validate_request(request)
    except (RequestError, TypeError, ValueError) as exc:
        if isinstance(exc, RequestError):
            result = _fail(exc.classification, exc.detail)
        else:
            result = _fail("INVALID_REQUEST", repr(exc))
        result["request_object_unchanged"] = request == before
        return result

    worker_cmd = [sys.executable, str(Path(__file__).resolve()), "--worker"]
    try:
        completed = subprocess.run(
            worker_cmd,
            input=_canonical_json(validated),
            text=True,
            capture_output=True,
            check=False,
            timeout=180,
        )
    except Exception as exc:
        result = _fail("WORKER_EXECUTION_FAILED", repr(exc), "isolated_worker_launch")
        result["request_object_unchanged"] = request == before
        return result

    if completed.returncode not in (0, 2):
        result = _fail(
            "WORKER_EXECUTION_FAILED",
            f"worker rc={completed.returncode}; stderr={completed.stderr[-1000:]!r}",
            "isolated_worker",
        )
        result["request_object_unchanged"] = request == before
        return result

    try:
        lines = [line for line in completed.stdout.splitlines() if line.strip()]
        worker_result = json.loads(lines[-1])
    except Exception as exc:
        result = _fail("WORKER_RESULT_INVALID", repr(exc), "isolated_worker")
        result["request_object_unchanged"] = request == before
        return result

    result = _enforce_result_contract(validated, worker_result)
    result["request_object_unchanged"] = request == before
    result["committed_state_digest"] = _digest(validated["committed_state"])
    result["worker_isolation"] = "FRESH_PROCESS_PER_TRIAL"
    return result


def _worker_failure(classification: str, detail: str, stage: str) -> dict:
    result = _fail(classification, detail, stage)
    result["execution_route"] = "ROSSFAST_D2_RESTRICTED_RESEARCH_WORKER"
    return result


def _run_worker_window(theta0, table, ext, duration, step_count, request_terminal_tangent, gate_f, d1, gate_d):
    dt = duration / step_count
    checkpoint = tuple(float(v) for v in theta0)
    trial_state = checkpoint
    max_step_mass = 0.0
    max_cell_mass = 0.0
    max_linear = 0.0
    factorizations = 0
    normal_backsolves = 0
    tangent_backsolves = 0
    cell_transitions = 0
    terminal = None

    for step_index in range(step_count):
        is_terminal = step_index == step_count - 1
        if is_terminal and request_terminal_tangent:
            step = d1.terminal_step_with_local_qbot_tangent(trial_state, table, ext, dt)
            terminal = step
            linear = step["normal_linear_residual_theta"]
            tangent_backsolves += step["local_terminal_tangent_backsolves"]
        else:
            step = gate_f.candidate_step(trial_state, table, ext, dt)
            linear = step["linear_residual_theta"]
        max_step_mass = max(max_step_mass, step["abs_global_mass_residual_cm"])
        max_cell_mass = max(max_cell_mass, step["max_abs_cell_mass_residual_cm"])
        max_linear = max(max_linear, linear)
        factorizations += step["matrix_factorizations"]
        normal_backsolves += step["normal_backsolves"]
        cell_transitions += step["cell_transition_count"]
        if not step["domain_ok"] or not step["envelope_ok"] or step["nonfinite_count"]:
            raise ValueError(f"invalid RossFast candidate at substep {step_index}")
        if not step["input_state_unchanged"]:
            raise RuntimeError(f"RossFast mutated substep input at index {step_index}")
        trial_state = tuple(float(v) for v in step["theta"])

    initial_storage = gate_d.DZ_CM * math.fsum(checkpoint)
    final_storage = gate_d.DZ_CM * math.fsum(trial_state)
    source_transfer = duration * math.fsum(ext["source"])
    sink_transfer = duration * math.fsum(ext["sink"])
    top_transfer = duration * ext["q_top"]
    bottom_transfer_into_column = duration * (-ext["q_bottom"])
    signed_residual = (
        (final_storage - initial_storage)
        - top_transfer
        - bottom_transfer_into_column
        - source_transfer
        + sink_transfer
    )
    return {
        "theta": trial_state,
        "heads": gate_f.heads_from_theta(trial_state),
        "storage_change_cm": final_storage - initial_storage,
        "top_boundary_transfer_cm": top_transfer,
        "bottom_boundary_transfer_cm": bottom_transfer_into_column,
        "source_transfer_cm": source_transfer,
        "sink_transfer_cm": sink_transfer,
        "unrounded_mass_residual_cm": signed_residual,
        "max_abs_step_mass_residual_cm": max_step_mass,
        "max_abs_cell_mass_residual_cm": max_cell_mass,
        "max_linear_residual_theta": max_linear,
        "matrix_factorizations": factorizations,
        "normal_backsolves": normal_backsolves,
        "local_terminal_tangent_backsolves": tangent_backsolves,
        "cell_transition_count": cell_transitions,
        "terminal": terminal,
    }


def _worker_execute(request: dict) -> dict:
    # Import research implementation only inside the short-lived worker.  This
    # is intentional: RossFast's legacy research modules use mutable material
    # configuration, so D2 gives that state worker/job lifetime only.
    here = Path(__file__).resolve().parent
    if str(here) not in sys.path:
        sys.path.insert(0, str(here))
    import run_ross01_gate_j1e_d1_local_terminal_coupling_preconditioner as d1

    gate_f = d1.gate_f
    gate_d = gate_f.gate_d
    j1a = gate_f.j1a

    physical = request["physical_parameters"]
    material_id = physical["material_id"]
    row = MATERIAL_ROWS[material_id]
    j1a.c1r.base.c1.configure_core(row)

    heads = tuple(float(v) for v in request["committed_state"]["pressure_head_cm"])
    theta = tuple(float(v) for v in request["committed_state"]["water_content"])
    if not all(j1a.c1r.base.H_MIN < h < j1a.c1r.base.H_MAX for h in heads):
        return _worker_failure("COMMITTED_STATE_OUTSIDE_DECLARED_SCOPE", "pressure head outside RossFast table envelope", "worker_pretrial")
    try:
        expected_theta = tuple(gate_d.theta_from_head(h) for h in heads)
    except Exception as exc:
        return _worker_failure("COMMITTED_STATE_OUTSIDE_DECLARED_SCOPE", repr(exc), "worker_pretrial")
    if any(abs(a - b) > STATE_CONSISTENCY_TOL for a, b in zip(theta, expected_theta)):
        return _worker_failure("COMMITTED_STATE_INCONSISTENT", "pressure-head and water-content vectors are inconsistent", "worker_pretrial")

    table, _, generation_failures = j1a.c1r.base.generate_table(j1a.N)
    if generation_failures:
        return _worker_failure("ROSSFAST_TABLE_GENERATION_FAILED", f"{len(generation_failures)} table failures", "worker_pretrial")

    ext_ref = gate_f.fixed_external(heads, "zero")
    forcing = request["forcing_process_requests"]
    q_top = float(forcing["top_boundary"]["q_top_cm_per_day"])
    qbot = float(forcing["bottom_boundary"]["qbot_cm_per_day"])
    qbot_ref = -float(ext_ref["q_bottom"])
    top_scale = max(abs(float(ext_ref["q_top"])), abs(float(ext_ref["k_top"])), 1.0e-12)
    bottom_scale = max(abs(qbot_ref), abs(float(ext_ref["k_bottom"])), 1.0e-12)
    top_limit = BOUNDARY_ENVELOPE_FRACTION * top_scale
    bottom_limit = BOUNDARY_ENVELOPE_FRACTION * bottom_scale
    if abs(q_top - float(ext_ref["q_top"])) > top_limit + 1.0e-15:
        return _worker_failure("TOP_FLUX_OUTSIDE_DECLARED_SCOPE", "prescribed top flux outside D2 state-local envelope", "worker_pretrial")
    if abs(qbot - qbot_ref) > bottom_limit + 1.0e-15:
        return _worker_failure("BOTTOM_FLUX_OUTSIDE_DECLARED_SCOPE", "prescribed qbot outside D2 state-local envelope", "worker_pretrial")

    ext = {
        "q_top": q_top,
        "q_bottom": -qbot,
        "q_scale": ext_ref["q_scale"],
        "k_top": ext_ref["k_top"],
        "k_bottom": ext_ref["k_bottom"],
        "source": tuple(0.0 for _ in range(N_CELLS)),
        "sink": tuple(0.0 for _ in range(N_CELLS)),
    }
    t0 = float(forcing["t0_day"])
    t1 = float(forcing["t1_day"])
    duration = t1 - t0
    step_count = int(request["numerical_configuration"]["equal_internal_substeps"])
    pre_request = forcing.get("local_terminal_preconditioner", {"requested": False, "required": False})

    try:
        window = _run_worker_window(
            theta,
            table,
            ext,
            duration,
            step_count,
            bool(pre_request.get("requested", False)),
            gate_f,
            d1,
            gate_d,
        )
    except Exception as exc:
        return _worker_failure("ROSSFAST_TRIAL_INVALID", repr(exc), "rossfast_trial")

    residual = float(window["unrounded_mass_residual_cm"])
    if not math.isfinite(residual) or abs(residual) > HARD_MASS_TOL_CM:
        return _worker_failure("HARD_MASS_GATE_FAILED", f"residual={residual!r}", "rossfast_trial")

    terminal = window["terminal"]
    preconditioner_metadata = None
    if pre_request.get("requested", False):
        available = bool(terminal and terminal["local_terminal_tangent_available"])
        preconditioner_metadata = {
            "available": available,
            "dh_bottom_dqbot_day": terminal["local_terminal_dh_bottom_dqbot_day"] if available else None,
            "scope": "LOCAL_TERMINAL_SUBSTEP_ONLY",
            "method": "SAME_FACTORIZATION_DIRECT_QBOT_BACKSOLVE",
            "whole_window_authority": False,
            "use": "BOUNDED_PROPOSAL_PRECONDITIONER_ONLY",
            "acceptance_authority": "ACTUAL_ROSSFAST_CORRECTOR_RESULT_PLUS_HARD_MASS_GATES",
            "reason": terminal["local_terminal_tangent_reason"] if terminal else "NOT_AVAILABLE",
            "backsolves": window["local_terminal_tangent_backsolves"],
            "n_times_local_is_whole_window_derivative": False,
        }

    candidate_state = {
        "pressure_head_cm": [float(v) for v in window["heads"]],
        "water_content": [float(v) for v in window["theta"]],
        "ponding_depth_cm": None,
        "groundwater_level_cm": None,
    }
    result = {
        "contract_id": CONTRACT_ID,
        "contract_version": CONTRACT_VERSION,
        "solver_id": SOLVER_ID,
        "solver_disposition": "candidate_ready",
        "failure_classification": None,
        "failure_detail": None,
        "candidate_hydraulic_state": candidate_state,
        "actual_top_flux": {
            "q_top_cm_per_day": q_top,
            "sign_convention": "positive_downward_into_column",
        },
        "candidate_bottom_flux": {
            "qbot_cm_per_day": qbot,
            "sign_convention": "positive_upward_into_column",
            "worker_q_bottom_down_cm_per_day": -qbot,
            "candidate_only": True,
            "accepted_exchange": False,
        },
        "process_hydraulic_view": {
            "pressure_head_cm": list(candidate_state["pressure_head_cm"]),
            "water_content": list(candidate_state["water_content"]),
            "ponding_depth_cm": None,
            "groundwater_level_cm": None,
        },
        "time_interval": {
            "t0_day": t0,
            "t1_day": t1,
            "duration_day": duration,
            "calendar_semantics": False,
        },
        "storage_change_cm": float(window["storage_change_cm"]),
        "mass_terms": {
            "top_boundary_transfer_cm": float(window["top_boundary_transfer_cm"]),
            "bottom_boundary_transfer_cm": float(window["bottom_boundary_transfer_cm"]),
            "source_transfer_cm": float(window["source_transfer_cm"]),
            "sink_transfer_cm": float(window["sink_transfer_cm"]),
            "all_transfer_sign": "positive_into_column",
        },
        "unrounded_mass_residual_cm": residual,
        "solver_work_diagnostics": {
            "execution_route": "ROSSFAST_D2_RESTRICTED_RESEARCH_WORKER",
            "restricted_capability_route": True,
            "equal_internal_substeps": step_count,
            "matrix_factorizations": int(window["matrix_factorizations"]),
            "normal_backsolves": int(window["normal_backsolves"]),
            "local_terminal_tangent_backsolves": int(window["local_terminal_tangent_backsolves"]),
            "cell_transition_count": int(window["cell_transition_count"]),
            "max_abs_step_mass_residual_cm": float(window["max_abs_step_mass_residual_cm"]),
            "max_abs_cell_mass_residual_cm": float(window["max_abs_cell_mass_residual_cm"]),
            "max_linear_residual_theta": float(window["max_linear_residual_theta"]),
            "quality_indicator": "D2_RESTRICTED_UNSATURATED_PROFILE",
            "fallback_used": False,
            "retry_count": 0,
        },
        "capability_route": {
            "top.prescribed_flux": "restricted",
            "bottom.prescribed_flux": "restricted",
            "bottom_exchange.candidate_flux": "restricted_candidate_only",
            "top.dynamic_provider": "unsupported",
            "bottom.prescribed_head": "unsupported",
            "bottom.legacy_mode_7": "unsupported",
            "bottom.legacy_mode_minus2": "unsupported",
            "dh_bottom_dq_bottom": "unsupported_whole_window",
        },
        "local_terminal_preconditioner": preconditioner_metadata,
        "whole_window_sensitivity": {
            "dh_bottom_dq_bottom_available": False,
            "authority": False,
            "reason": "F-SI31_WHOLE_WINDOW_SENSITIVITY_UNQUALIFIED_FOR_ROSSFAST_D2",
        },
        "ownership": {
            "committed_base_read_only": True,
            "distinct_candidate": True,
            "solver_never_commits": True,
            "runtime_acceptance_required": True,
            "runtime_commit_required": True,
            "accepted_only_publication_required": True,
            "scratch_persistent": False,
        },
        "accepted": False,
        "commit_authorized": False,
        "accepted_publication_authorized": False,
        "committed_state_mutated": False,
        "implicit_full_richards_fallback": False,
    }
    return result


def _worker_main() -> int:
    try:
        request = json.loads(sys.stdin.read())
        result = _worker_execute(request)
    except Exception as exc:
        result = _worker_failure("WORKER_UNHANDLED_EXCEPTION", repr(exc), "isolated_worker")
    print(json.dumps(result, sort_keys=True, allow_nan=False))
    return 0 if result.get("solver_disposition") == "candidate_ready" else 2


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--worker":
        raise SystemExit(_worker_main())
    raise SystemExit("RossFast D2 adapter is imported by qualification/runtime research harnesses; use --worker only for the isolated child process")
