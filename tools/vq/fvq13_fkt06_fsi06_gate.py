#!/usr/bin/env python3
"""F-VQ13 source-bound F-KT06/F-SI06 admission and ownership-alignment gate."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FVQ12_FINAL = "7cd06ba606429c891dab7f355a85b58ca56a3bca"
FCI18 = "7f906fcc53a4133b0e410eac7cf79fbb4eb672ab"
FKT05_FINAL = "f50b8cd20221fac27a2059b6c6192ed0b7384be8"
FKT06_TESTED = "80a68dea3bfa45d7e8d533ec5a67fc89bdb786db"
FKT06_FINAL = "42872c266bc6f4fbf6815b1facbc3ed5d64df19a"
FKT06_CONTRACT_BLOB = "64f285ac6ae89297ca221048c2ff55cc580e3492"
FKT06_RUN = 34126785977
FKT06_FOCUSED_JOB = 101757222036
FKT06_FCI_JOB = 101757290282
FSI05_FINAL = "0227ae94edc3364b013f831f1efa6aaccac29b11"
FSI06_TESTED = "dfed799dbc0930bdf5218e713934ea0f148e3872"
FSI06_DOCUMENTED = "2fa63c41a4d7248ab7f4b5af46f72caddfda4f29"
FSI06_FINAL = "d0f0cc0817f2e2b8ca55dd90752cfda2f7b0e6e8"
FSI06_TEST_RUN = 34127234890
FSI06_TEST_JOB = 101758660973
FSI06_DOC_RUN = 34127506779
FSI06_DOC_JOB = 101759545451

STATUS_PATH = ROOT / "integration/f-vq/F-VQ13_STATUS.json"
MATRIX_PATH = ROOT / "integration/f-vq/F-VQ13_ADMISSION_MATRIX.json"
SCOPE_PATH = ROOT / "integration/f-vq/F-VQ13_SCOPE.json"
EVIDENCE_PATH = ROOT / "integration/f-vq/evidence/F-VQ13_QUALIFICATION.json"
QUALIFIABLE = {f"FVQ13-C{i:02d}" for i in range(1, 6)}
BLOCKED = {f"FVQ13-C{i:02d}" for i in range(6, 13)}
ALLOWED_HEAD_PATHS = (
    "integration/f-vq/",
    "tools/vq/",
    "docs/verification/",
    ".github/workflows/fvq12-downstream.yml",
    ".github/workflows/fvq13-downstream.yml",
    ".github/workflows/vq-reference.yml",
)


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def is_ancestor(base: str, head: str) -> bool:
    return subprocess.run(["git", "merge-base", "--is-ancestor", base, head], cwd=ROOT).returncode == 0


def changed(base: str, head: str = "HEAD") -> list[str]:
    out = git("diff", "--name-only", base, head)
    return [line for line in out.splitlines() if line]


def json_at(commit: str, path: str) -> dict:
    return json.loads(git("show", f"{commit}:{path}"))


def blob_at(commit: str, path: str) -> str:
    return git("rev-parse", f"{commit}:{path}")


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_matrix(matrix: dict, status: dict) -> dict[str, bool]:
    claims = {c.get("claim_id"): c for c in matrix.get("claims", [])}
    qualified = bool(status.get("qualified"))
    return {
        "claim_set_exact": set(claims) == QUALIFIABLE | BLOCKED,
        "qualifiable_targets": all(claims.get(cid, {}).get("target") == "QUALIFIABLE" for cid in QUALIFIABLE),
        "blocked_targets": all(claims.get(cid, {}).get("target") == "BLOCKED_FAIL_CLOSED" for cid in BLOCKED),
        "qualifiable_flags_follow_status": all(bool(claims.get(cid, {}).get("claim_qualified")) == qualified for cid in QUALIFIABLE),
        "blocked_flags_false": all(claims.get(cid, {}).get("claim_qualified") is False for cid in BLOCKED),
        "pretest_qualifiable_have_blockers": qualified or all(bool(claims.get(cid, {}).get("blocker")) for cid in QUALIFIABLE),
        "qualified_qualifiable_clear_blockers": (not qualified) or all(claims.get(cid, {}).get("blocker") is None for cid in QUALIFIABLE),
        "blocked_have_blockers": all(bool(claims.get(cid, {}).get("blocker")) for cid in BLOCKED),
    }


def validate_status(status: dict) -> dict[str, bool]:
    qualified = bool(status.get("qualified"))
    expected_decision = "QUALIFIED_FKT06_FSI06_SOURCE_BOUND_HISTORY_CONTINUATION_ALIGNMENT_ONLY" if qualified else "PENDING_FVQ13_CI"
    return {
        "work_unit": status.get("work_unit") == "F-VQ13",
        "scope": status.get("qualification_scope") == "DOWNSTREAM_SOURCE_BOUND_FKT06_FSI06_ADMISSION_WITH_HISTORY_CONTINUATION_ALIGNMENT_ONLY",
        "decision": status.get("decision") == expected_decision,
        "fkt06": bool(status.get("fkt06_source_bound_admitted")) == qualified,
        "fsi06": bool(status.get("fsi06_source_bound_admitted")) == qualified,
        "alignment": bool(status.get("fkt06_fsi06_history_continuation_alignment_qualified")) == qualified,
        "composition_false": status.get("fkt06_fsi06_composed_runtime_qualified") is False,
        "parallel_false": status.get("real_headcalc_parallel_reentrancy_qualified") is False,
        "macropore_false": status.get("macropore_production_admitted") is False and status.get("macropore_nstep_transaction_materialized") is False,
        "mass_false": status.get("full_unrounded_swap_mass_identity_qualified") is False,
        "reference_blocked": status.get("production_reference_admission") == "BLOCKED_FAIL_CLOSED",
        "multiswap_false": status.get("production_multiswap_admission") is False,
        "optional_false": status.get("optional_workspace_paths_complete") is False,
        "tangent_false": status.get("interface_tangent_qualified") is False,
        "production_unchanged": status.get("production_source_changed_by_fvq13") is False,
        "reference_unchanged": status.get("reference_source_changed_by_fvq13") is False,
    }


def validate_evidence(status: dict) -> dict[str, bool]:
    if not status.get("qualified"):
        return {"pretest_no_evidence_required": not EVIDENCE_PATH.exists()}
    if not EVIDENCE_PATH.exists():
        return {"evidence_exists": False}
    evidence = load(EVIDENCE_PATH)
    run = evidence.get("qualification_run", {})
    return {
        "evidence_exists": True,
        "decision": evidence.get("decision") == "QUALIFIED_FKT06_FSI06_SOURCE_BOUND_HISTORY_CONTINUATION_ALIGNMENT_ONLY",
        "tested_matches": evidence.get("tested_postimage") == status.get("tested_postimage"),
        "tested_ancestor": bool(status.get("tested_postimage")) and is_ancestor(status["tested_postimage"], "HEAD"),
        "run_success": run.get("conclusion") == "success",
        "composition_false": evidence.get("fkt06_fsi06_composed_runtime_qualified") is False,
        "parallel_false": evidence.get("real_headcalc_parallel_reentrancy_qualified") is False,
        "macropore_false": evidence.get("macropore_production_admitted") is False,
        "mass_false": evidence.get("full_unrounded_swap_mass_identity_qualified") is False,
        "reference_blocked": evidence.get("production_reference_admission") == "BLOCKED_FAIL_CLOSED",
        "multiswap_false": evidence.get("production_multiswap_admission") is False,
        "production_unchanged": evidence.get("production_source_changed_by_fvq13") is False,
    }


def validate_all() -> dict:
    status = load(STATUS_PATH)
    matrix = load(MATRIX_PATH)
    scope = load(SCOPE_PATH)
    fvq12 = json_at(FVQ12_FINAL, "integration/f-vq/F-VQ12_STATUS.json")
    fkt_status = json_at(FKT06_FINAL, "integration/f-kt/F-KT06_STATUS.json")
    fkt_qual = json_at(FKT06_FINAL, "qualification/f-kt/F-KT06_QUALIFICATION.json")
    fkt_contract = json_at(FKT06_FINAL, "integration/f-kt/F-KT06_OPTIONAL_CONTINUATION_CONTRACT.json")
    fsi = json_at(FSI06_FINAL, "integration/f-si/F-SI06_QUALIFICATION.json")
    head_delta = changed(FVQ12_FINAL)

    classification = fkt_contract.get("classification_contract", {})
    scaling = fkt_contract.get("optional_state_scaling", {})
    fkt_nonclaims = fkt_qual.get("nonclaims", {})
    fsi_history = fsi.get("history_ownership", {})
    fsi_alignment = fsi.get("fkt06_alignment", {})
    fsi_parallel = fsi.get("parallel_admission", {})
    fsi_deferred = fsi.get("deferred_not_claimed", {})
    fsi_materialization = fsi.get("production_materialization", {})
    fsi_policy = fsi.get("physics_and_policy", {})

    sections = {
        "basis": {
            "fvq12_ancestor": is_ancestor(FVQ12_FINAL, "HEAD"),
            "fvq12_qualified": fvq12.get("qualified") is True and fvq12.get("decision") == "QUALIFIED_FKT05_FSI05_SOURCE_BOUND_NONCONFLICT_ONLY",
            "fci18_to_fkt06": is_ancestor(FCI18, FKT06_TESTED),
            "fci18_to_fsi06": is_ancestor(FCI18, FSI06_TESTED),
            "fkt05_to_fkt06": is_ancestor(FKT05_FINAL, FKT06_TESTED),
            "fkt_test_to_final": is_ancestor(FKT06_TESTED, FKT06_FINAL),
            "fsi05_to_fsi06": is_ancestor(FSI05_FINAL, FSI06_TESTED),
            "fsi_test_to_documented": is_ancestor(FSI06_TESTED, FSI06_DOCUMENTED),
            "fsi_documented_to_final": is_ancestor(FSI06_DOCUMENTED, FSI06_FINAL),
        },
        "fkt06": {
            "final_delta_exact": sorted(changed(FKT06_TESTED, FKT06_FINAL)) == ["integration/f-kt/F-KT06_STATUS.json", "qualification/f-kt/F-KT06_QUALIFICATION.json"],
            "qualified": fkt_status.get("qualified") is True and fkt_status.get("qualification_status") == "QUALIFIED",
            "tested_exact": fkt_status.get("tested_postimage") == FKT06_TESTED,
            "run_exact": fkt_status.get("qualification_run", {}).get("run_id") == FKT06_RUN and fkt_status.get("qualification_run", {}).get("conclusion") == "success",
            "jobs_exact": fkt_status.get("qualification_run", {}).get("focused_job_id") == FKT06_FOCUSED_JOB and fkt_status.get("qualification_run", {}).get("fci_regression_job_id") == FKT06_FCI_JOB,
            "contract_blob_stable": blob_at(FKT06_TESTED, "integration/f-kt/F-KT06_OPTIONAL_CONTINUATION_CONTRACT.json") == FKT06_CONTRACT_BLOB == blob_at(FKT06_FINAL, "integration/f-kt/F-KT06_OPTIONAL_CONTINUATION_CONTRACT.json"),
            "physical_continuation_class": classification.get("state_that_can_change_future_accepted_physics") == "committed_per_column_continuation_state",
            "reporting_outside": classification.get("reporting_only_history") == "outside_physical_continuation_state",
            "nstep_failclosed": classification.get("fsi06_nstep") == "must_be_in_adapter_specific_transaction_state_before_macropore_admission",
            "no_fsi_import": classification.get("fkt_imports_fsi_types") is False and classification.get("fkt_hardcodes_nstep") is False,
            "inactive_unallocated": scaling.get("adapter_state_may_keep_optional_component_unallocated_when_inactive") is True and scaling.get("persistent_cost_scales_with_active_option") is True,
            "mass_rejection_preserves": fkt_status.get("qualified_behavior", {}).get("mass_rejection_preserves_committed_and_checkpoint_continuation") == "PASS",
            "macropore_not_claimed": fkt_nonclaims.get("macropore_production_admission") is False,
        },
        "fsi06": {
            "documented_delta_exact": sorted(changed(FSI06_TESTED, FSI06_DOCUMENTED)) == ["docs/integration/F-SI06_HISTORY_ISOLATION.md", "integration/f-si/F-SI06_QUALIFICATION.json"],
            "final_record_only": changed(FSI06_DOCUMENTED, FSI06_FINAL) == ["integration/f-si/F-SI06_QUALIFICATION.json"],
            "qualified": fsi.get("qualified") is True and fsi.get("status") == "QUALIFIED_HISTORY_ISOLATION_PARALLEL_BINDING_BLOCKED",
            "tested_exact": fsi.get("tested_checkpoint", {}).get("head") == FSI06_TESTED,
            "test_run_exact": fsi.get("tested_checkpoint", {}).get("workflow_run") == FSI06_TEST_RUN and fsi.get("tested_checkpoint", {}).get("job") == FSI06_TEST_JOB and fsi.get("tested_checkpoint", {}).get("conclusion") == "success",
            "documented_run_exact": fsi.get("final_postimage_verification", {}).get("head") == FSI06_DOCUMENTED and fsi.get("final_postimage_verification", {}).get("workflow_run") == FSI06_DOC_RUN and fsi.get("final_postimage_verification", {}).get("job") == FSI06_DOC_JOB and fsi.get("final_postimage_verification", {}).get("conclusion") == "success",
            "hidden_save_removed": fsi_history.get("headcalc_hidden_save_removed") is True,
            "reporting_history_explicit": fsi_history.get("flwarn") == "reporting_only_history" and fsi_history.get("iwarn") == "reporting_only_history",
            "nstep_not_scratch": fsi_history.get("nstep") == "column_dependent_solver_process_continuation_not_worker_scratch",
            "common_history_call_local": fsi_history.get("common_reference_history_owner") == "call_local a23bu_solver_history_t",
            "parallel_blocked": fsi_parallel.get("full_real_headcalc_reentrancy_qualified") is False and bool(fsi_parallel.get("blocker")),
            "transaction_unchanged": fsi_materialization.get("transaction_source_changed") is False and fsi_materialization.get("shared_fkt_type_changed") is False and fsi_policy.get("transaction_semantics_changed") is False and fsi_policy.get("generic_time_semantics_changed") is False,
        },
        "alignment": {
            "fsi_observed_contract_exact": fsi_alignment.get("optional_continuation_contract_blob") == FKT06_CONTRACT_BLOB,
            "decision_match": str(fsi_alignment.get("decision_alignment", "")).startswith("MATCH:"),
            "not_cross_consumed": fsi_alignment.get("consumed_as_qualification_evidence") is False,
            "reporting_alignment": classification.get("fsi06_flwarn_iwarn") == "reporting_only_history_not_FKT_committed_state" and fsi_history.get("flwarn") == "reporting_only_history",
            "nstep_alignment": "adapter-specific transaction-state materialization" in str(fsi_alignment.get("decision_alignment", "")) and classification.get("fsi06_nstep") == "must_be_in_adapter_specific_transaction_state_before_macropore_admission",
            "composition_not_claimed": "one composed F-KT06 plus F-SI06 executable production postimage" in scope.get("not_implied", []),
        },
        "negative_scope": {
            "parallel_not_admitted": fsi_deferred.get("full_reference_richards_parallel_reentrancy") == "NOT_QUALIFIED" and fsi_deferred.get("real_headcalc_1_2_4_8_workers") == "BLOCKED",
            "macropore_deferred": fsi_deferred.get("macropore_path") == "DEFERRED_FAIL_CLOSED" and fsi_deferred.get("macropore_nstep_transaction_materialization") == "DEFERRED_TO_FKT_ALIGNED_ADAPTER_STATE_SLICE",
            "optional_paths_deferred": all(fsi_deferred.get(k) == "DEFERRED" for k in ("implicit_conductivity_path", "minimum_timestep_path", "non_free_drainage_bottom_modes")),
            "mass_not_full": fsi_deferred.get("full_unrounded_swap_mass_balance") == "NOT_QUALIFIED",
            "tangent_not_implemented": fsi_deferred.get("interface_tangent") == "NOT_IMPLEMENTED",
            "multiswap_false": fsi_deferred.get("production_multiswap_admission") is False,
            "reference_blocked": fkt_qual.get("canonical_reference_admission") == "BLOCKED_FAIL_CLOSED",
        },
        "provenance": {
            "qualification_paths_only": all(any(path == prefix or path.startswith(prefix) for prefix in ALLOWED_HEAD_PATHS) for path in head_delta),
            "no_src_delta": not any(path.startswith("src/") for path in head_delta),
            "no_reference_delta": not any(path.startswith("reference/") for path in head_delta),
        },
        "matrix": validate_matrix(matrix, status),
        "status": validate_status(status),
        "evidence": validate_evidence(status),
    }
    failures = [f"{section}.{name}" for section, checks in sections.items() for name, ok in checks.items() if not ok]
    result = {
        "workstream": "F-VQ",
        "work_unit": "F-VQ13",
        "status": "PASS" if not failures else "FAIL",
        "qualification_scope": "DOWNSTREAM_SOURCE_BOUND_FKT06_FSI06_ADMISSION_WITH_HISTORY_CONTINUATION_ALIGNMENT_ONLY",
        "fkt06_source_bound_qualifiable": not failures,
        "fsi06_source_bound_qualifiable": not failures,
        "history_continuation_alignment_qualifiable": not failures,
        "composed_runtime_qualified": False,
        "real_headcalc_parallel_reentrancy_qualified": False,
        "macropore_production_admitted": False,
        "production_reference_admission": "BLOCKED_FAIL_CLOSED",
        "production_multiswap_admission": False,
        "sections": sections,
        "failed": failures,
    }
    return result


def main() -> int:
    result = validate_all()
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
