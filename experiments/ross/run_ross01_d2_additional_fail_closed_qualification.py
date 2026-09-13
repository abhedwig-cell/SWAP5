from __future__ import annotations

import copy
import json
import math
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import ross01_d2_fsi31_adapter as adapter
import run_ross01_d2_fsi31_qualification as mainq


def fail_closed(name: str, request: dict, expected: str) -> dict:
    committed_before = copy.deepcopy(request.get("committed_state"))
    result = adapter.execute_research_trial(request)
    passed = (
        result.get("solver_disposition") == "failed"
        and result.get("failure_classification") == expected
        and result.get("candidate_hydraulic_state") is None
        and result.get("process_hydraulic_view") is None
        and result.get("accepted") is False
        and result.get("commit_authorized") is False
        and result.get("accepted_publication_authorized") is False
        and result.get("committed_state_mutated") is False
        and result.get("implicit_full_richards_fallback") is False
        and request.get("committed_state") == committed_before
    )
    return {
        "name": name,
        "pass": passed,
        "expected_classification": expected,
        "actual_classification": result.get("failure_classification"),
        "failure_stage": result.get("failure_stage"),
        "committed_state_unchanged": request.get("committed_state") == committed_before,
        "candidate_published": result.get("candidate_hydraulic_state") is not None,
    }


def tangent_gate(name: str, metadata: dict, expected: str) -> dict:
    request = mainq.base_request("B01", pre=True, require=True)
    synthetic = {
        "solver_disposition": "candidate_ready",
        "candidate_hydraulic_state": {"pressure_head_cm": [0.0], "water_content": [0.0]},
        "process_hydraulic_view": {"pressure_head_cm": [0.0], "water_content": [0.0]},
        "unrounded_mass_residual_cm": 0.0,
        "local_terminal_preconditioner": metadata,
        "accepted": False,
        "commit_authorized": False,
        "accepted_publication_authorized": False,
        "committed_state_mutated": False,
        "implicit_full_richards_fallback": False,
    }
    result = adapter._enforce_result_contract(request, synthetic)
    return {
        "name": name,
        "pass": (
            result.get("solver_disposition") == "failed"
            and result.get("failure_classification") == expected
            and result.get("candidate_hydraulic_state") is None
            and result.get("accepted") is False
            and result.get("commit_authorized") is False
            and result.get("accepted_publication_authorized") is False
        ),
        "expected_classification": expected,
        "actual_classification": result.get("failure_classification"),
        "whole_window_authority_after_gate": False,
    }


def recursive_keys(value):
    if isinstance(value, dict):
        for key, child in value.items():
            yield key
            yield from recursive_keys(child)
    elif isinstance(value, list):
        for child in value:
            yield from recursive_keys(child)


def main() -> int:
    probes = []

    top = mainq.base_request("B01", pre=False)
    top["forcing_process_requests"]["top_boundary"]["q_top_cm_per_day"] *= 10.0
    probes.append(fail_closed("prescribed_top_flux_outside_declared_envelope", top, "TOP_FLUX_OUTSIDE_DECLARED_SCOPE"))

    bottom = mainq.base_request("B01", pre=False)
    qbot = bottom["forcing_process_requests"]["bottom_boundary"]["qbot_cm_per_day"]
    bottom["forcing_process_requests"]["bottom_boundary"]["qbot_cm_per_day"] = qbot + max(abs(qbot), 1.0) * 10.0
    probes.append(fail_closed("prescribed_qbot_outside_declared_envelope", bottom, "BOTTOM_FLUX_OUTSIDE_DECLARED_SCOPE"))

    probes.append(tangent_gate(
        "required_terminal_tangent_unavailable_non_smooth",
        {
            "available": False,
            "dh_bottom_dqbot_day": None,
            "scope": "LOCAL_TERMINAL_SUBSTEP_ONLY",
            "method": "SAME_FACTORIZATION_DIRECT_QBOT_BACKSOLVE",
            "whole_window_authority": False,
            "use": "BOUNDED_PROPOSAL_PRECONDITIONER_ONLY",
            "reason": "TERMINAL_TABLE_CELL_TRANSITION_NON_SMOOTH",
        },
        "LOCAL_TERMINAL_TANGENT_UNAVAILABLE_OR_INVALID",
    ))

    probes.append(tangent_gate(
        "required_terminal_tangent_nonfinite_invalid",
        {
            "available": True,
            "dh_bottom_dqbot_day": float("nan"),
            "scope": "LOCAL_TERMINAL_SUBSTEP_ONLY",
            "method": "SAME_FACTORIZATION_DIRECT_QBOT_BACKSOLVE",
            "whole_window_authority": False,
            "use": "BOUNDED_PROPOSAL_PRECONDITIONER_ONLY",
            "reason": "NONFINITE_RESPONSE",
        },
        "LOCAL_TERMINAL_TANGENT_UNAVAILABLE_OR_INVALID",
    ))

    probes.append(tangent_gate(
        "terminal_tangent_wrong_scope_cannot_be_relabelled",
        {
            "available": True,
            "dh_bottom_dqbot_day": 1.0,
            "scope": "WHOLE_WINDOW",
            "method": "SAME_FACTORIZATION_DIRECT_QBOT_BACKSOLVE",
            "whole_window_authority": True,
            "use": "AUTHORITATIVE_SENSITIVITY",
            "reason": "SYNTHETIC_SCOPE_VIOLATION",
        },
        "LOCAL_TERMINAL_TANGENT_UNAVAILABLE_OR_INVALID",
    ))

    positive_request = mainq.base_request("B01", pre=True)
    positive = adapter.execute_research_trial(positive_request)
    forbidden = {"lookup_table", "factorization", "jacobian", "newton_vector", "warm_start_payload", "face_root_internal"}
    view_keys = set(recursive_keys(positive.get("process_hydraulic_view")))
    result_keys = set(recursive_keys(positive))
    process_view_probe = {
        "name": "process_view_and_scratch_separation",
        "pass": (
            positive.get("solver_disposition") == "candidate_ready"
            and forbidden.isdisjoint(view_keys)
            and positive.get("ownership", {}).get("scratch_persistent") is False
            and positive.get("ownership", {}).get("solver_never_commits") is True
            and positive.get("whole_window_sensitivity", {}).get("authority") is False
        ),
        "forbidden_process_view_keys_present": sorted(forbidden & view_keys),
        "scratch_persistent": positive.get("ownership", {}).get("scratch_persistent"),
        "whole_window_authority": positive.get("whole_window_sensitivity", {}).get("authority"),
        "result_contains_factorization_payload": "factorization" in result_keys,
    }
    probes.append(process_view_probe)

    passed = all(item["pass"] for item in probes)
    evidence = {
        "schema_version": 1,
        "work_unit": "F-ROSS01 D2",
        "qualification_slice": "ADDITIONAL_FAIL_CLOSED_AND_PROCESS_VIEW",
        "workflow": {
            "run_id": os.getenv("GITHUB_RUN_ID"),
            "job": os.getenv("GITHUB_JOB"),
            "trigger_sha": os.getenv("GITHUB_SHA"),
        },
        "probes": probes,
        "all_pass": passed,
        "semantic_nonclaims_preserved": {
            "true_whole_window_derivative": False,
            "canonical_interface_sensitivity": False,
            "production_modflow_coupling": False,
            "production_admission": False,
        },
        "decision": "QUALIFIED_ADDITIONAL_D2_FAIL_CLOSED_SLICE" if passed else "D2_ADDITIONAL_FAIL_CLOSED_GAPS_IDENTIFIED",
    }
    out = Path("integration/f-ross/F-ROSS01_D2_ADDITIONAL_FAIL_CLOSED_EVIDENCE.json")
    out.write_text(json.dumps(evidence, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({"all_pass": passed, "failed": [x["name"] for x in probes if not x["pass"]]}, sort_keys=True))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
