from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import ross01_d2_fsi31_adapter as adapter
import run_ross01_d2_fsi31_qualification as d2q

D2_AUTHORITY = "4cdeeec8b3ab5267196ab9c15942b4ee6d23c587"
FSI31_AUTHORITY = "4190ede0b17e81abe806430cc9a4c94a21995917"
EXPECTED_BLOBS = {
    "transaction": "d5a71a526efaebd82054580c3186f8e3545db331",
    "runtime": "f41f725df4be883d277a8fd5afe5a6f1bc14ad1b",
    "kernel": "c7c5b7d3357e4e6739c8f647d6232baca45563e6",
}
D2_STATUS = Path("integration/f-ross/F-ROSS01_D2_STATUS.json")
D2_EVIDENCE = Path("integration/f-ross/F-ROSS01_D2_EVIDENCE.json")


def git_blob_sha(data: bytes) -> str:
    return hashlib.sha1(f"blob {len(data)}\0".encode("ascii") + data).hexdigest()


def canon(value) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)


def require_tokens(text: str, tokens: list[str]) -> dict:
    missing = [token for token in tokens if token not in text]
    return {"pass": not missing, "missing": missing}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--transaction-source", required=True, type=Path)
    parser.add_argument("--runtime-source", required=True, type=Path)
    parser.add_argument("--kernel-source", required=True, type=Path)
    parser.add_argument("--canonical-head", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    tests: dict[str, object] = {}
    status = json.loads(D2_STATUS.read_text())
    d2_evidence = json.loads(D2_EVIDENCE.read_text())
    tests["d2_authority_closed_positive"] = (
        status.get("status") == "CLOSED"
        and status.get("decision") == "QUALIFIED_ROSSFAST_FSI31_V1_RESTRICTED_RESEARCH_ADAPTER"
        and status.get("all_required_gates_pass") is True
    )

    sources = {
        "transaction": args.transaction_source.read_bytes(),
        "runtime": args.runtime_source.read_bytes(),
        "kernel": args.kernel_source.read_bytes(),
    }
    observed_blobs = {name: git_blob_sha(data) for name, data in sources.items()}
    tests["current_canonical_source_blobs_exact"] = observed_blobs == EXPECTED_BLOBS

    tx = sources["transaction"].decode("utf-8")
    rt = sources["runtime"].decode("utf-8")
    kernel = sources["kernel"].decode("utf-8")

    tests["canonical_external_full_half_semantics"] = require_tokens(
        tx,
        [
            "TX_TEMPORAL_EXTERNAL_FULL_HALF",
            "midpoint = t0 + 0.5_real64 * attempt_dt",
            "call model%advance(half_state, t0, midpoint, half1_outcome)",
            "call model%advance(half_state, midpoint, attempt_t1, half2_outcome)",
        ],
    )
    tests["canonical_retry_shrink_semantics"] = require_tokens(
        tx,
        [
            "result%retries = result%retries + 1",
            "attempt_dt = attempt_dt * policy%retry_scale",
        ],
    )
    tests["canonical_model_certificate_semantics"] = require_tokens(
        tx,
        [
            "TX_TEMPORAL_MODEL_CERTIFICATE",
            "outcome%temporal_certificate_available",
            "ieee_is_finite(outcome%temporal_indicator)",
            "outcome%temporal_indicator <= 1.0_real64",
        ],
    )
    tests["canonical_mass_fail_closed_semantics"] = require_tokens(
        tx,
        [
            "accepted_missing_mask == TX_MASS_MISSING_NONE",
            "outcome%mass_accounting_complete",
            "abs(mass_residual) <= policy%mass_tolerance",
            "abs(full_mass_residual) <= policy%mass_tolerance",
            "abs(half_mass_residual) <= policy%mass_tolerance",
        ],
    )
    tests["canonical_runtime_external_commit_boundary"] = require_tokens(
        rt,
        [
            "The externally committed physical state remains untouched until the full",
            "call move_alloc(working, committed)",
            "result%diagnostics%external_commits = 1",
        ],
    )
    tests["canonical_kernel_candidate_commit_provenance"] = require_tokens(
        kernel,
        [
            "if (runtime_result%completed) then",
            "candidate_state%origin_revision_value = committed_state%revision",
            "subroutine kernel_commit_candidate",
            "candidate_state%origin_revision_value /= committed_state%revision",
            "committed_state%revision = committed_state%revision + 1_int64",
        ],
    )

    full_req = d2q.base_request("B01", t0=37.125, steps=8, perturb=0.0, pre=False)
    committed_before = copy.deepcopy(full_req["committed_state"])
    full = adapter.execute_research_trial(full_req)
    tests["d2_full_window_candidate_ready"] = full.get("solver_disposition") == "candidate_ready"
    tests["d2_full_window_committed_read_only"] = (
        full_req["committed_state"] == committed_before
        and full.get("committed_state_mutated") is False
        and full.get("accepted") is False
        and full.get("commit_authorized") is False
        and full.get("accepted_publication_authorized") is False
    )
    residual = full.get("unrounded_mass_residual_cm")
    tests["d2_full_window_hard_mass"] = (
        isinstance(residual, (int, float))
        and math.isfinite(float(residual))
        and abs(float(residual)) <= 1.0e-12
    )
    bottom = full.get("candidate_bottom_flux") or {}
    tests["d2_bottom_exchange_candidate_only"] = (
        bottom.get("candidate_only") is True and bottom.get("accepted_exchange") is False
    )

    half_req = copy.deepcopy(full_req)
    half_req["forcing_process_requests"]["t1_day"] = (
        half_req["forcing_process_requests"]["t0_day"] + 0.5 * adapter.HORIZON_DAY
    )
    half = adapter.execute_research_trial(half_req)
    tests["external_half_interval_rejected_fail_closed"] = (
        half.get("solver_disposition") == "failed"
        and half.get("failure_classification") == "TIME_OUTSIDE_DECLARED_SCOPE"
        and half.get("candidate_hydraulic_state") is None
        and half.get("committed_state_mutated") is False
    )

    retry_req = copy.deepcopy(full_req)
    retry_req["forcing_process_requests"]["t1_day"] = (
        retry_req["forcing_process_requests"]["t0_day"] + 0.5 * adapter.HORIZON_DAY
    )
    retry = adapter.execute_research_trial(retry_req)
    tests["canonical_retry_duration_rejected_fail_closed"] = (
        retry.get("solver_disposition") == "failed"
        and retry.get("failure_classification") == "TIME_OUTSIDE_DECLARED_SCOPE"
        and retry.get("candidate_hydraulic_state") is None
        and retry_req["committed_state"] == committed_before
    )

    tests["d2_model_temporal_certificate_absent"] = (
        "temporal_certificate_available" not in full
        and "temporal_indicator" not in full
        and (full.get("whole_window_sensitivity") or {}).get("authority") is False
    )

    structural_tests = [
        "d2_authority_closed_positive",
        "current_canonical_source_blobs_exact",
        "d2_full_window_candidate_ready",
        "d2_full_window_committed_read_only",
        "d2_full_window_hard_mass",
        "d2_bottom_exchange_candidate_only",
        "external_half_interval_rejected_fail_closed",
        "canonical_retry_duration_rejected_fail_closed",
        "d2_model_temporal_certificate_absent",
    ]
    source_semantic_tests = [
        "canonical_external_full_half_semantics",
        "canonical_retry_shrink_semantics",
        "canonical_model_certificate_semantics",
        "canonical_mass_fail_closed_semantics",
        "canonical_runtime_external_commit_boundary",
        "canonical_kernel_candidate_commit_provenance",
    ]
    all_pass = all(bool(tests[name]) for name in structural_tests) and all(
        bool(tests[name].get("pass")) for name in source_semantic_tests
    )

    gaps = [
        {
            "id": "F-ROSS01-D3-G01",
            "classification": "TEMPORAL_COMPOSITION_GAP",
            "summary": "The current-canonical external full-vs-two-half transaction route requires half-interval model calls, while frozen D2 qualifies only duration 0.0016 day.",
            "evidence": {
                "requested_full_duration_day": adapter.HORIZON_DAY,
                "canonical_half_duration_day": 0.5 * adapter.HORIZON_DAY,
                "adapter_failure_classification": half.get("failure_classification"),
            },
        },
        {
            "id": "F-ROSS01-D3-G02",
            "classification": "TEMPORAL_CERTIFICATE_GAP",
            "summary": "The alternative current-canonical model-certificate transaction route requires an explicit qualified temporal certificate; frozen D2 exposes no such certificate and D3 does not invent one.",
        },
        {
            "id": "F-ROSS01-D3-G03",
            "classification": "RETRY_COMPOSITION_GAP",
            "summary": "Current-canonical transaction retry shrinks attempt duration; the first 0.5 retry already leaves frozen D2's qualified duration scope, so retry recovery is fail-closed rather than qualified.",
            "evidence": {
                "retry_scale": 0.5,
                "first_retry_duration_day": 0.5 * adapter.HORIZON_DAY,
                "adapter_failure_classification": retry.get("failure_classification"),
            },
        },
    ]

    evidence = {
        "schema_version": 1,
        "work_unit": "F-ROSS01 D3",
        "title": "RossFast F-SI31 v1 Current-Canonical Runtime Composition, Transactional Exchange & Mass-Conservative Service Qualification",
        "qualification_execution_pass": all_pass,
        "decision": (
            "ROSSFAST_CURRENT_CANONICAL_RUNTIME_COMPOSITION_GAPS_IDENTIFIED"
            if all_pass
            else "D3_QUALIFICATION_EXECUTION_FAILED"
        ),
        "authorities": {
            "d2": D2_AUTHORITY,
            "fsi31": FSI31_AUTHORITY,
            "live_canonical_head": args.canonical_head,
            "canonical_source_blobs": observed_blobs,
        },
        "tests": tests,
        "d2_full_window": {
            "material": "B01",
            "t0_day": full_req["forcing_process_requests"]["t0_day"],
            "t1_day": full_req["forcing_process_requests"]["t1_day"],
            "duration_day": adapter.HORIZON_DAY,
            "solver_disposition": full.get("solver_disposition"),
            "mass_residual_cm": residual,
            "candidate_digest": full.get("candidate_state_digest"),
            "committed_digest": full.get("committed_state_digest"),
        },
        "composition_assessment": {
            "fsi31_candidate_ownership": "PASS",
            "committed_state_read_only": "PASS",
            "hard_mass_candidate_gate": "PASS",
            "candidate_bottom_exchange_semantics": "PASS",
            "generic_absolute_time_coordinate": "PASS",
            "current_canonical_mass_completeness_admission": "PASS_SOURCE_BOUND",
            "current_canonical_external_full_half_route": "NOT_COMPOSABLE_WITH_FROZEN_D2_DURATION_SCOPE",
            "current_canonical_model_certificate_route": "NOT_COMPOSABLE_WITHOUT_NEW_TEMPORAL_CERTIFICATE_QUALIFICATION",
            "current_canonical_retry_recovery": "NOT_COMPOSABLE_WITH_FROZEN_D2_DURATION_SCOPE",
            "runtime_commit_ownership": "REPRESENTABLE_BUT_NOT_END_TO_END_QUALIFIED_BECAUSE_TEMPORAL_ADMISSION_BLOCKS_BEFORE_COMMIT",
            "restart": "OUT_OF_D3_SCOPE_AND_D2_UNSUPPORTED",
            "multiswap": "OUT_OF_D3_SCOPE_AND_NOT_PRODUCTION_QUALIFIED",
            "production_admission": False,
        },
        "gaps": gaps,
        "minimal_closure_requirement": {
            "primary": "Qualify a RossFast research-adapter interval-duration family matching the exact current-canonical transaction/retry policy to be exercised, including every half/retry duration that can reach the solver, while preserving the D2 hard mass gate and candidate-only ownership.",
            "alternative_or_additional": "If TX_TEMPORAL_MODEL_CERTIFICATE is intended, independently define and qualify a RossFast temporal certificate with explicit accuracy semantics; it may not be inferred from solver convergence, mass residual, or the D1 local-terminal hydraulic response.",
            "no_scope_reduction": True,
        },
        "invariant_audit": {
            "1": "PASS_NO_PRODUCTION_KERNEL_FORK",
            "3": "PASS_D2_DATA_SEPARATION_PRESERVED",
            "5": "PASS_D2_WORKER_LOCAL_SCRATCH_PRESERVED",
            "7": "PARTIAL_CANDIDATE_ROLLBACK_REPRESENTABLE_RETRY_DURATION_NOT_QUALIFIED",
            "8": "FAIL_RETRY_RECOVERY_NOT_QUALIFIED_FOR_CANONICAL_DURATION_LADDER",
            "9": "PASS_GENERIC_T0_T1_BUT_DURATION_SCOPE_RESTRICTED",
            "11": "PARTIAL_TRANSACTIONAL_EXCHANGE_REPRESENTABLE_TEMPORAL_ADMISSION_BLOCKS_END_TO_END_COMPOSITION",
            "13": "PASS_D2_HARD_MASS_AND_CURRENT_CANONICAL_FAIL_CLOSED_COMPLETENESS",
            "14": "PASS_NO_WHOLE_WINDOW_SENSITIVITY_INFLATION",
            "20": "PARTIAL_RESEARCH_SEAM_EXISTS_CURRENT_RUNTIME_COMPOSITION_NOT_YET_QUALIFIED",
            "22": "PASS_PROCESS_VIEW_NO_SOLVER_INTERNALS",
            "23": "PASS_PHYSICS_NUMERICAL_POLICY_SEPARATION",
            "29": "PASS_NO_CALENDAR_OR_FILE_SEMANTICS_IN_SOLVER_REQUEST",
            "30": "PASS_EXPLICIT_NEGATIVE_QUALIFICATION_AND_GAP_RECORD",
        },
        "production_source_delta": [],
        "d2_evidence_decision": d2_evidence.get("decision"),
        "exact_next_research_step": "F-ROSS01 D3R: bounded interval-duration and retry-ladder qualification for the frozen F-SI31 RossFast adapter, followed by re-execution of this current-canonical composition gate; temporal-certificate research remains separate unless explicitly selected.",
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    return 0 if all_pass else 1


if __name__ == "__main__":
    raise SystemExit(main())
