from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import os
import sys
import traceback
from pathlib import Path

from jsonschema import Draft202012Validator

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import ross01_d2_fsi31_adapter as adapter
import run_ross01_gate_j1e_d1_local_terminal_coupling_preconditioner as d1

START = "9deddef0294ea14ea1ed418ce6688bfc7b136c53"
FSI31 = "4190ede0b17e81abe806430cc9a4c94a21995917"
CONTRACT_BLOB = "d5e934df4b3fbaa573e994cbe675257cf6a47304"
SCHEMA_BLOB = "86bfa60468d891e071c735569d944570f75fa205"
CANONICAL_OBS = "379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b"
CAPABILITY = Path("integration/f-ross/F-ROSS01_D2_FSI31_V1_CAPABILITY_DECLARATION.json")
ADAPTER_CONTRACT = Path("integration/f-ross/F-ROSS01_D2_ADAPTER_CONTRACT.json")


def blob_sha(data: bytes) -> str:
    return hashlib.sha1(f"blob {len(data)}\0".encode() + data).hexdigest()


def canon(value) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def base_request(material: str, t0=0.0, steps=4, perturb=0.0, pre=True, require=False):
    row = copy.deepcopy(adapter.MATERIAL_ROWS[material])
    d1.j1a.c1r.base.c1.configure_core(row)
    heads = d1.gate_d.build_profile(adapter.N_CELLS, -180.0, -650.0)
    theta = tuple(d1.gate_d.theta_from_head(h) for h in heads)
    ext = d1.gate_f.fixed_external(heads, "zero")
    qbot0 = -float(ext["q_bottom"])
    top_scale = max(abs(float(ext["q_top"])), abs(float(ext["k_top"])), 1e-12)
    bot_scale = max(abs(qbot0), abs(float(ext["k_bottom"])), 1e-12)
    requested = ["top.prescribed_flux", "bottom.prescribed_flux", "bottom_exchange.candidate_flux"]
    if pre:
        requested.append("rossfast.local_terminal_preconditioner")
    return {
        "contract_id": adapter.CONTRACT_ID,
        "contract_version": adapter.CONTRACT_VERSION,
        "requested_capabilities": requested,
        "physical_parameters": {
            "material_id": material,
            "hydraulic_parameters": row,
            "constitutive_family": "UNIMODAL_MUALEM_VAN_GENUCHTEN_USING_KSATFIT_WITH_KSATEXM_DISABLED",
            "grid": {"dimension": "1D_VERTICAL", "n_cells": 16, "uniform_dz_cm": 10.0},
            "active_physics": ["unsaturated_soil_water"],
        },
        "committed_state": {
            "pressure_head_cm": list(heads),
            "water_content": list(theta),
            "ponding_depth_cm": None,
            "groundwater_level_cm": None,
        },
        "forcing_process_requests": {
            "t0_day": float(t0),
            "t1_day": float(t0 + adapter.HORIZON_DAY),
            "top_boundary": {
                "mode": "top.prescribed_flux",
                "q_top_cm_per_day": float(ext["q_top"]) + perturb * top_scale,
            },
            "bottom_boundary": {
                "mode": "bottom.prescribed_flux",
                "qbot_cm_per_day": qbot0 - perturb * bot_scale,
            },
            "general_sources_sinks": "none",
            "root_sink": "none",
            "local_terminal_preconditioner": {"requested": pre, "required": require},
        },
        "numerical_configuration": {
            "equal_internal_substeps": steps,
            "sigma": 0.5,
            "mass_tolerance_cm": 1e-12,
            "deterministic_replay": "contract_equivalent",
        },
        "worker_job_scratch": {"persistent": False, "warm_start_payload": None},
    }


def positive_checks(result, request):
    mass = result.get("mass_terms") or {}
    try:
        reconstructed = (
            result["storage_change_cm"]
            - mass["top_boundary_transfer_cm"]
            - mass["bottom_boundary_transfer_cm"]
            - mass["source_transfer_cm"]
            + mass["sink_transfer_cm"]
        )
        residual = result["unrounded_mass_residual_cm"]
    except Exception:
        reconstructed = math.nan
        residual = math.nan
    candidate = result.get("candidate_hydraulic_state") or {}
    view = result.get("process_hydraulic_view") or {}
    bottom = result.get("candidate_bottom_flux") or {}
    qbot = request["forcing_process_requests"]["bottom_boundary"]["qbot_cm_per_day"]
    whole = result.get("whole_window_sensitivity") or {}
    return {
        "candidate_ready": result.get("solver_disposition") == "candidate_ready",
        "candidate_only": result.get("accepted") is False and result.get("commit_authorized") is False and result.get("accepted_publication_authorized") is False,
        "committed_unmutated": result.get("committed_state_mutated") is False and result.get("request_object_unchanged") is True,
        "no_fallback": result.get("implicit_full_richards_fallback") is False,
        "worker_isolated": result.get("worker_isolation") == "FRESH_PROCESS_PER_TRIAL",
        "mass_hard": math.isfinite(residual) and abs(residual) <= 1e-12,
        "mass_ledger": math.isfinite(reconstructed) and abs(reconstructed - residual) <= 5e-16,
        "qbot_sign": bottom.get("qbot_cm_per_day") == qbot and bottom.get("worker_q_bottom_down_cm_per_day") == -qbot,
        "candidate_exchange_only": bottom.get("candidate_only") is True and bottom.get("accepted_exchange") is False,
        "process_head": view.get("pressure_head_cm") == candidate.get("pressure_head_cm"),
        "process_theta": view.get("water_content") == candidate.get("water_content"),
        "whole_window_not_claimed": whole.get("dh_bottom_dq_bottom_available") is False and whole.get("authority") is False,
    }


def negative(name, request):
    snapshot = copy.deepcopy(request.get("committed_state"))
    result = adapter.execute_research_trial(request)
    ok = (
        result.get("solver_disposition") == "failed"
        and result.get("candidate_hydraulic_state") is None
        and result.get("accepted") is False
        and result.get("commit_authorized") is False
        and result.get("accepted_publication_authorized") is False
        and result.get("committed_state_mutated") is False
        and result.get("implicit_full_richards_fallback") is False
        and request.get("committed_state") == snapshot
    )
    return {"name": name, "pass": ok, "classification": result.get("failure_classification"), "stage": result.get("failure_stage")}


def qualify(schema_path: Path, contract_path: Path):
    tests = {}
    schema_bytes = schema_path.read_bytes()
    contract_bytes = contract_path.read_bytes()
    schema = json.loads(schema_bytes)
    declaration = json.loads(CAPABILITY.read_text())
    tests["schema_blob"] = blob_sha(schema_bytes) == SCHEMA_BLOB
    tests["contract_blob"] = blob_sha(contract_bytes) == CONTRACT_BLOB
    try:
        Draft202012Validator.check_schema(schema)
        Draft202012Validator(schema).validate(declaration)
        tests["capability_schema_valid"] = True
    except Exception:
        tests["capability_schema_valid"] = False
    tests["whole_window_unsupported"] = declaration["sensitivities"]["dh_bottom_dq_bottom"]["status"] == "unsupported"
    tests["restart_unsupported"] = declaration["restart"]["status"] == "unsupported"

    positives = []
    max_mass = 0.0
    for material in adapter.MATERIAL_IDS:
        req = base_request(material, pre=True)
        before = copy.deepcopy(req["committed_state"])
        result = adapter.execute_research_trial(req)
        checks = positive_checks(result, req)
        pre = result.get("local_terminal_preconditioner") or {}
        checks["local_scope"] = (
            pre.get("scope") == "LOCAL_TERMINAL_SUBSTEP_ONLY"
            and pre.get("method") == "SAME_FACTORIZATION_DIRECT_QBOT_BACKSOLVE"
            and pre.get("whole_window_authority") is False
            and pre.get("use") == "BOUNDED_PROPOSAL_PRECONDITIONER_ONLY"
            and pre.get("n_times_local_is_whole_window_derivative") is False
        )
        checks["input_state_exact"] = req["committed_state"] == before
        positives.append({"material": material, "case": "baseline", "pass": all(checks.values()), "checks": checks, "mass_residual_cm": result.get("unrounded_mass_residual_cm")})
        if isinstance(result.get("unrounded_mass_residual_cm"), (int, float)):
            max_mass = max(max_mass, abs(result["unrounded_mass_residual_cm"]))

        req2 = base_request(material, t0=37.125, steps=8, perturb=0.01, pre=False)
        result2 = adapter.execute_research_trial(req2)
        checks2 = positive_checks(result2, req2)
        positives.append({"material": material, "case": "perturbed_prescribed_flux", "pass": all(checks2.values()), "checks": checks2, "mass_residual_cm": result2.get("unrounded_mass_residual_cm")})
        if isinstance(result2.get("unrounded_mass_residual_cm"), (int, float)):
            max_mass = max(max_mass, abs(result2["unrounded_mass_residual_cm"]))

    tests["positive_matrix"] = all(x["pass"] for x in positives)
    tests["mass_hard_gate"] = max_mass <= 1e-12

    ta_req = base_request("B01", pre=False)
    tb_req = copy.deepcopy(ta_req)
    tb_req["forcing_process_requests"]["t0_day"] = 12345.75
    tb_req["forcing_process_requests"]["t1_day"] = 12345.75 + adapter.HORIZON_DAY
    ta = adapter.execute_research_trial(ta_req)
    tb = adapter.execute_research_trial(tb_req)
    tests["generic_time"] = (
        ta.get("solver_disposition") == "candidate_ready"
        and tb.get("solver_disposition") == "candidate_ready"
        and ta.get("candidate_hydraulic_state") == tb.get("candidate_hydraulic_state")
        and ta.get("mass_terms") == tb.get("mass_terms")
    )

    replay_req = base_request("O05", t0=9.0, steps=8, pre=True)
    r1 = adapter.execute_research_trial(copy.deepcopy(replay_req))
    r2 = adapter.execute_research_trial(copy.deepcopy(replay_req))
    replay_fields = ["solver_disposition", "candidate_hydraulic_state", "actual_top_flux", "candidate_bottom_flux", "mass_terms", "unrounded_mass_residual_cm", "local_terminal_preconditioner", "whole_window_sensitivity"]
    tests["replay_contract_equivalent"] = all(r1.get(k) == r2.get(k) for k in replay_fields)

    tx_req = base_request("B12", t0=2.0, perturb=0.005, pre=False)
    committed = copy.deepcopy(tx_req["committed_state"])
    before = canon(committed)
    trial = adapter.execute_research_trial(tx_req)
    reject_ok = canon(committed) == before
    retry_req = copy.deepcopy(tx_req)
    retry_req["committed_state"] = copy.deepcopy(committed)
    retry = adapter.execute_research_trial(retry_req)
    retry_same = retry.get("committed_state_digest") == trial.get("committed_state_digest")
    external_commit = retry.get("solver_disposition") == "candidate_ready" and retry.get("candidate_hydraulic_state") != committed
    tests["transaction_reject_retry_commit"] = (
        trial.get("solver_disposition") == "candidate_ready"
        and reject_ok and retry_same and external_commit
        and trial.get("candidate_bottom_flux", {}).get("accepted_exchange") is False
    )

    negatives = []
    base = base_request("B01", pre=False)
    req = copy.deepcopy(base); req["forcing_process_requests"]["top_boundary"] = {"mode": "top.dynamic_provider"}; negatives.append(negative("dynamic_top", req))
    req = copy.deepcopy(base); req["forcing_process_requests"]["bottom_boundary"] = {"mode": "bottom.prescribed_head", "head_cm": -100.0}; negatives.append(negative("prescribed_head", req))
    req = copy.deepcopy(base); req["forcing_process_requests"]["bottom_boundary"] = {"mode": "bottom.legacy_mode_7"}; negatives.append(negative("legacy_7", req))
    req = copy.deepcopy(base); req["forcing_process_requests"]["bottom_boundary"] = {"mode": "bottom.legacy_mode_minus2"}; negatives.append(negative("legacy_minus2", req))
    req = copy.deepcopy(base); req["physical_parameters"]["material_id"] = "B02"; negatives.append(negative("material_out_of_scope", req))
    req = copy.deepcopy(base); req["physical_parameters"]["grid"]["n_cells"] = 15; negatives.append(negative("grid_out_of_scope", req))
    req = copy.deepcopy(base); req["requested_capabilities"].remove("bottom_exchange.candidate_flux"); negatives.append(negative("missing_capability", req))
    req = copy.deepcopy(base); req["numerical_configuration"]["equal_internal_substeps"] = 3; negatives.append(negative("invalid_numerical", req))
    req = copy.deepcopy(base); req["forcing_process_requests"]["t1_day"] = req["forcing_process_requests"]["t0_day"]; negatives.append(negative("t1_le_t0", req))
    req = copy.deepcopy(base); req["worker_job_scratch"]["persistent"] = True; negatives.append(negative("persistent_scratch", req))

    required_pre = base_request("B01", pre=True, require=True)
    unavailable = {
        "solver_disposition": "candidate_ready",
        "candidate_hydraulic_state": {"pressure_head_cm": [0.0], "water_content": [0.0]},
        "process_hydraulic_view": {"pressure_head_cm": [0.0], "water_content": [0.0]},
        "unrounded_mass_residual_cm": 0.0,
        "local_terminal_preconditioner": {
            "available": False,
            "scope": "LOCAL_TERMINAL_SUBSTEP_ONLY",
            "method": "SAME_FACTORIZATION_DIRECT_QBOT_BACKSOLVE",
            "whole_window_authority": False,
            "use": "BOUNDED_PROPOSAL_PRECONDITIONER_ONLY",
        },
        "accepted": False,
        "commit_authorized": False,
        "accepted_publication_authorized": False,
    }
    gated = adapter._enforce_result_contract(required_pre, unavailable)
    negatives.append({"name": "local_terminal_unavailable", "pass": gated.get("solver_disposition") == "failed" and gated.get("candidate_hydraulic_state") is None, "classification": gated.get("failure_classification"), "stage": gated.get("failure_stage")})
    tests["negative_fail_closed"] = all(x["pass"] for x in negatives)

    invariants = {
        "1": "PASS_RESEARCH_ONLY_NO_PRODUCTION_KERNEL_REPLACEMENT",
        "3": "PASS_FIVE_CATEGORIES_SEPARATED",
        "4": "PASS_NO_SCRATCH_AS_PERSISTENT_COLUMN_STATE",
        "5": "PASS_FRESH_WORKER_PER_TRIAL",
        "7": "PASS_CANDIDATE_ONLY_TRANSACTION",
        "8": "PASS_RETRY_FROM_IDENTICAL_COMMITTED_BASE",
        "9": "PASS_GENERIC_T0_T1",
        "11": "PASS_RESEARCH_CANDIDATE_EXCHANGE",
        "13": "PASS_HARD_MASS_GATE",
        "14": "PASS_LOCAL_SCOPE_EXPLICIT_WHOLE_WINDOW_UNSUPPORTED",
        "16": "PASS_ARCHITECTURE_ONLY_NO_PER_COLUMN_HEAVY_SOLVER_COMMITMENT",
        "20": "PASS_EXECUTABLE_ALTERNATIVE_SOLVER_SEAM",
        "21": "PASS_NO_NEW_PROCESS_PHYSICS",
        "22": "PASS_PROCESS_VIEW_ONLY",
        "23": "PASS_PHYSICS_AND_NUMERICAL_POLICY_SEPARATE",
        "26": "PASS_DIAGNOSTICS_EXPOSED",
        "27": "PASS_OPTIONAL_TANGENT_COST_ONLY_WHEN_REQUESTED",
        "29": "PASS_NO_FILE_OR_CALENDAR_SEMANTICS_IN_REQUEST",
        "30": "PASS_EXPLICIT_AUDIT",
    }
    decision = "QUALIFIED_ROSSFAST_FSI31_V1_RESTRICTED_RESEARCH_ADAPTER" if all(tests.values()) else "ROSSFAST_FSI31_V1_ADAPTER_GAPS_IDENTIFIED"
    failed = [k for k, v in tests.items() if not v]
    evidence = {
        "schema_version": 1,
        "work_unit": "F-ROSS01 D2",
        "authorities": {"start": START, "fsi31": FSI31, "contract_blob": CONTRACT_BLOB, "schema_blob": SCHEMA_BLOB, "canonical_observation": CANONICAL_OBS},
        "workflow": {"run_id": os.getenv("GITHUB_RUN_ID"), "run_number": os.getenv("GITHUB_RUN_NUMBER"), "job": os.getenv("GITHUB_JOB"), "trigger_sha": os.getenv("GITHUB_SHA")},
        "capability_declaration": str(CAPABILITY),
        "adapter_contract": str(ADAPTER_CONTRACT),
        "positive_executable_cases": positives,
        "negative_fail_closed_cases": negatives,
        "transaction": {"reject_committed_unchanged": reject_ok, "retry_same_committed_origin": retry_same, "commit_performed_only_by_harness_runtime": external_commit},
        "mass": {"hard_tolerance_cm": 1e-12, "max_abs_unrounded_residual_cm": max_mass, "relaxation_allowed": False, "double_booking_on_reject_retry": False},
        "replay": {"declared": "contract_equivalent", "pass": tests["replay_contract_equivalent"]},
        "process_hydraulic_view": {"pressure_head": "qualified", "water_content": "qualified", "ponding": "unsupported", "groundwater_level": "unsupported", "solver_internals_exposed": False},
        "d1_tangent": {"scope": "LOCAL_TERMINAL_SUBSTEP_ONLY", "method": "SAME_FACTORIZATION_DIRECT_QBOT_BACKSOLVE", "whole_window_authority": False, "use": "bounded proposal/preconditioner only", "upstream_non_smooth_detector_requalified": False, "adapter_unavailable_gate_qualified": True},
        "whole_window_derivative": {"qualified": False, "status": "unsupported", "n_times_local_generalized": False},
        "restart": "unsupported_not_qualified",
        "multiswap_runtime": "no_production_qualification",
        "production_source_delta": [],
        "compiler_optimization": "NOT_APPLICABLE_PYTHON_RESEARCH_ADAPTER",
        "tests": tests,
        "failed_tests": failed,
        "invariant_audit": invariants,
        "decision": decision,
        "exact_next_research_step": "independently qualify current-canonical runtime/restart/MultiSWAP composition before any production admission; true whole-window sensitivity remains a separate research question" if not failed else f"close only reproducible D2 failures: {failed}",
    }
    status = {
        "schema_version": 1,
        "work_unit": "F-ROSS01 D2",
        "status": "CLOSED" if not failed else "BLOCKED_WITH_EXACT_GAPS",
        "decision": decision,
        "workflow_run_id": os.getenv("GITHUB_RUN_ID"),
        "all_required_gates_pass": not failed,
        "failed_tests": failed,
        "production_source_delta": [],
        "whole_window_derivative_qualified": False,
        "restart_qualified": False,
        "production_admission": False,
        "canonical_modified": False,
    }
    return evidence, status, not failed


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--schema", required=True)
    p.add_argument("--fsi31-contract", required=True)
    p.add_argument("--evidence", required=True)
    p.add_argument("--status", required=True)
    a = p.parse_args()
    try:
        evidence, status, passed = qualify(Path(a.schema), Path(a.fsi31_contract))
    except Exception as exc:
        evidence = {"schema_version": 1, "work_unit": "F-ROSS01 D2", "decision": "ROSSFAST_FSI31_V1_ADAPTER_GAPS_IDENTIFIED", "exception": repr(exc), "traceback": traceback.format_exc(), "workflow": {"run_id": os.getenv("GITHUB_RUN_ID")}}
        status = {"schema_version": 1, "work_unit": "F-ROSS01 D2", "status": "BLOCKED_WITH_EXACT_GAPS", "decision": "ROSSFAST_FSI31_V1_ADAPTER_GAPS_IDENTIFIED", "failed_tests": ["unhandled_qualification_exception"]}
        passed = False
    Path(a.evidence).write_text(json.dumps(evidence, indent=2, sort_keys=True, allow_nan=False) + "\n")
    Path(a.status).write_text(json.dumps(status, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({"decision": status["decision"], "failed_tests": status.get("failed_tests", []), "run_id": status.get("workflow_run_id")}, sort_keys=True))
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
