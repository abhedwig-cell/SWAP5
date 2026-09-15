#!/usr/bin/env python3
"""F-VQ03 admission gate for the qualified F-CI13 recoverable-status seam.

Qualification infrastructure only. F-VQ03 may admit the exact source-bound
F-CI13 status/transaction contract. It must not promote deterministic failure
forcing to hydrological regression, and it must keep reference execution
fail-closed while temporal policy and execute_reference_interval remain absent.
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any

from tools.vq.tx_time_harness import run_fixture_suite, check_stored_evidence

REPO_ROOT = Path(__file__).resolve().parents[2]
FCI13_SOURCE = "538d51df4be3780a5bb092767304749dfc800899"
FCI13_QUALIFICATION = "f56c5fe7cdbca36c3403fcd027c5998b0c7578f4"
FCI13_RUN = 34104845258
FCI13_JOB = 101687946143
FVQ02_FINAL = "0a042426a83fc8bfbc31f36b67c0d8e49447724c"
FVQ02_TESTED = "390bb2595c4cc33b8bb1198f6ff091fbf473068e"

STATUS = REPO_ROOT / "integration/f-ci/F-CI13_STATUS.json"
FAILURE = REPO_ROOT / "integration/f-ci/evidence/F-CI13_FAILURE_CLASSIFICATION.json"
FVQ02_EVIDENCE = REPO_ROOT / "integration/f-vq/evidence/F-VQ02_QUALIFICATION.json"
PROVENANCE = REPO_ROOT / "integration/f-vq/F-VQ03_PROVENANCE.json"
READINESS = REPO_ROOT / "integration/f-vq/F-VQ03_REFERENCE_READINESS.json"
MATRIX = REPO_ROOT / "integration/f-vq/F-VQ03_ADMISSION_MATRIX.json"
HARNESS_EVIDENCE = REPO_ROOT / "tools/vq/cases/vq-1e1-tx-time-harness-2026-09-06.json"

ALLOWED_CHANGED_PREFIXES = (
    ".github/workflows/vq-reference.yml",
    "docs/verification/",
    "integration/f-vq/",
    "tools/vq/",
)

EXPECTED_OVERLAY_OBJECTS = {
    "integration/f-vq": "eb69a83c9974a9e4f8613ceaaa413bc123ceb292",
    "docs/verification": "2c7f89a16957af7078122f4fa9fa6f4e2e3e3ab0",
    "tools/vq": "d423811ea0288dcd685d8ccdd4e2c54a1a00558c",
    ".github/workflows/vq-reference.yml": "69e67f4da3ac1bc8fe8a93664eb108a4a5a7e04b",
}

EXPECTED_VERIFIER_BLOBS = {
    "tools/vq/b2_seam_contract.py": "210847d9eb906fb1ddbf4ba4f65ca26156cad4af",
    "tools/vq/b2_result_contract.py": "75632937fcd7f99a75a99e227821afd3c4748999",
    "tools/vq/b2_result_record.py": "6e01be04258799f0f4d42040f0b5ffe4fe2b6be8",
    "tools/vq/tx_time_harness.py": "7b82912499bafcfe510a5e4219b50bbea7837f8c",
    "tools/vq/test_b2_seam_contract.py": "614b889e1bc30de3281c68446ce341a52b0bedef",
    "tools/vq/test_b2_result_contract.py": "a2af14f4ce31c956a5a125c096aa07ffb78ec93f",
    "tools/vq/test_b2_result_record.py": "8f9872c72cb2af9e50fd90ef4b3d26734e1f007d",
    "tools/vq/test_tx_time_harness.py": "eeb738bdf16d618f70cc1085e8c93646ff9bb9a4",
}


def _json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def _run(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=REPO_ROOT, text=True, capture_output=True, check=False)


def git_blob(path: str) -> str | None:
    proc = _run(["git", "hash-object", path])
    return proc.stdout.strip() if proc.returncode == 0 else None


def check_fci13_status() -> dict[str, bool]:
    data = _json(STATUS)
    q = data.get("qualification", {})
    parent = _run(["git", "rev-parse", f"{FCI13_QUALIFICATION}^"])
    return {
        "work_unit": data.get("work_unit") == "F-CI13",
        "qualified_source_exact": data.get("qualified_source_head") == FCI13_SOURCE,
        "qualification_commit_parent_is_source": parent.returncode == 0 and parent.stdout.strip() == FCI13_SOURCE,
        "oracle_b1_10": data.get("b1_oracle") == "B1.10",
        "trial_status_contract_pass": q.get("trial_status_contract") == "PASS",
        "terminal_mapping_source_bound": q.get("terminal_richards_nonconvergence_mapping") == "PASS_SOURCE_BOUND_CANONICAL_ONLY",
        "retryable_isolation_testdouble": q.get("retryable_trial_state_isolation") == "PASS_DETERMINISTIC_FAILURE_TESTDOUBLE",
        "canonical_ci_exact": q.get("canonical_ci") == "PASS_RUN_34104845258_JOB_101687946143",
        "dependency_chain_exact": q.get("full_dependency_chain") == "PASS_FCI03_THROUGH_FCI13",
        "real_failure_fixture_not_executed": q.get("real_b1_10_forced_terminal_nonconvergence_fixture") == "NOT_YET_EXECUTED",
        "temporal_policy_not_admitted": q.get("scalar_temporal_error_policy") == "NOT_ADMITTED",
        "reference_interval_fail_closed": q.get("execute_reference_interval") == "FAIL_CLOSED_NOT_ADMITTED",
        "formal_status_exact": data.get("status") == "PASS_RECOVERABLE_TRIAL_STATUS_CONTRACT_REFERENCE_TEMPORAL_POLICY_BLOCKED",
    }


def check_failure_evidence() -> dict[str, bool]:
    data = _json(FAILURE)
    classes = {
        item.get("class"): item.get("outer_trial_status")
        for item in data.get("classification", [])
        if isinstance(item, dict)
    }
    executed = data.get("executed_checks", {})
    scope = data.get("scope", {})
    return {
        "source_exact": data.get("qualified_source_head") == FCI13_SOURCE,
        "workflow_exact": data.get("canonical_workflow_run") == FCI13_RUN,
        "job_exact": data.get("canonical_job") == FCI13_JOB,
        "gate_pass": data.get("gate_result") == "FCI13_GATE_PASS",
        "chain_pass": data.get("dependency_chain") == "PASS_FCI03_THROUGH_FCI13",
        "retryable_mapping_exact": classes.get("RETRYABLE_NUMERICAL") == "B1_10_TRIAL_STATUS_RETRYABLE_NUMERICAL",
        "fatal_mapping_exact": classes.get("FATAL_CONTRACT") == "FAIL_FAST_NOT_RETRYABLE",
        "internal_retry_preserved": classes.get("INTERNAL_RETRY") == "NONE",
        "success_path_pass": executed.get("success_status_path") == "PASS_O0_O2",
        "retryable_path_testdouble_pass": executed.get("retryable_status_and_state_restore") == "PASS_O0_O2_DETERMINISTIC_FAILURE_TESTDOUBLE",
        "temporal_negative_control_pass": executed.get("scalar_temporal_negative_control") == "PASS_FAIL_CLOSED",
        "qualification_limit_testdouble_explicit": "deterministic legacy testdouble" in data.get("qualification_limit", ""),
        "physics_unchanged": scope.get("physics_formulas_changed") is False,
        "solver_tolerances_unchanged": scope.get("solver_tolerances_changed") is False,
        "mass_tolerance_unchanged": scope.get("mass_tolerance_changed") is False,
    }


def check_fvq02_carry_forward() -> dict[str, bool]:
    evidence = _json(FVQ02_EVIDENCE)
    prov = _json(PROVENANCE)
    carried = prov.get("carried_forward_fvq02", {})
    pins = carried.get("subtree_pins", {})
    return {
        "fvq02_decision_exact": evidence.get("decision") == "QUALIFIED_VERIFIER_CONTRACTS_ONLY",
        "fvq02_tested_postimage_exact": evidence.get("qualified_postimage") == FVQ02_TESTED,
        "fvq02_not_physics": evidence.get("production_physics_qualified") is False,
        "fvq02_reference_still_blocked": evidence.get("canonical_reference_admission") == "BLOCKED_FAIL_CLOSED",
        "fvq02_final_head_pinned": carried.get("final_head") == FVQ02_FINAL,
        "overlay_pins_declared": pins == EXPECTED_OVERLAY_OBJECTS,
        "reusable_verifier_blobs_exact": all(git_blob(path) == sha for path, sha in EXPECTED_VERIFIER_BLOBS.items()),
    }


def check_readiness() -> dict[str, bool]:
    data = _json(READINESS)
    caps = data.get("capabilities", {})
    admission = data.get("admission", {})
    return {
        "status_blocked": data.get("status") == "BLOCKED_REFERENCE_ROUTE_NOT_ADMITTED",
        "source_exact": data.get("source_commit") == FCI13_SOURCE,
        "qualification_exact": data.get("qualification_commit") == FCI13_QUALIFICATION,
        "recoverable_status_true": caps.get("recoverable_solver_failure_status_contract") is True,
        "failed_trial_isolation_true": caps.get("retryable_failed_trial_state_isolation") is True,
        "real_failure_fixture_false": caps.get("real_b1_10_terminal_failure_fixture_qualified") is False,
        "temporal_policy_false": caps.get("scalar_temporal_error_policy") is False,
        "reference_interval_false": caps.get("execute_reference_interval_for_b1_10") is False,
        "end_to_end_false": caps.get("real_b1_10_reference_end_to_end") is False,
        "result_route_false": caps.get("production_canonical_result_route") is False,
        "status_contract_admitted": admission.get("source_bound_status_contract_may_be_declared_qualified") is True,
        "physics_failure_not_admitted": admission.get("real_terminal_failure_physics_may_be_declared_qualified") is False,
        "reference_not_ready": admission.get("production_reference_adapter_may_be_declared_ready") is False,
        "numerical_qualification_not_ready": admission.get("b1_10_to_canonical_reference_numerical_qualification_may_start") is False,
    }


def validate_matrix(data: dict[str, Any]) -> dict[str, bool]:
    claims = data.get("claims", [])
    ids = [item.get("claim_id") for item in claims if isinstance(item, dict)]
    by_id = {
        item.get("claim_id"): item
        for item in claims
        if isinstance(item, dict) and item.get("claim_id")
    }
    blocked = [item for item in claims if isinstance(item, dict) and item.get("blocker")]
    return {
        "work_unit": data.get("work_unit") == "F-VQ03",
        "oracle": data.get("oracle") == "B1.10",
        "basis_source_exact": data.get("basis", {}).get("fci13_source_commit") == FCI13_SOURCE,
        "basis_qualification_exact": data.get("basis", {}).get("fci13_qualification_commit") == FCI13_QUALIFICATION,
        "claims_present": isinstance(claims, list) and len(claims) >= 9,
        "ids_unique": len(ids) == len(set(ids)) == len(claims),
        "blocked_never_qualified": all(item.get("claim_qualified") is False for item in blocked),
        "status_contract_qualified": by_id.get("FVQ03-C02", {}).get("claim_qualified") is True,
        "retryable_semantics_qualified": by_id.get("FVQ03-C03", {}).get("claim_qualified") is True,
        "real_failure_fixture_not_qualified": by_id.get("FVQ03-C04", {}).get("claim_qualified") is False,
        "temporal_policy_blocked": by_id.get("FVQ03-C05", {}).get("claim_qualified") is False,
        "reference_execution_blocked": by_id.get("FVQ03-C06", {}).get("claim_qualified") is False,
        "result_route_blocked": by_id.get("FVQ03-C07", {}).get("claim_qualified") is False,
    }


def check_harness() -> dict[str, bool]:
    report = run_fixture_suite()
    stored = check_stored_evidence(report, HARNESS_EVIDENCE)
    cases = report.get("cases", [])
    return {
        "harness_pass": report.get("harness_status") == "PASS",
        "eleven_cases_pass": len(cases) == 11 and all(item.get("status") == "PASS" for item in cases),
        "stored_evidence_consistent": stored.get("consistent") is True,
        "production_physics_false": report.get("production_physics_executed") is False,
        "production_mass_tolerance_false": report.get("production_mass_tolerance_qualified") is False,
    }


def check_change_scope() -> dict[str, bool]:
    diff = _run(["git", "diff", "--name-only", FCI13_QUALIFICATION, "HEAD"])
    paths = [line.strip() for line in diff.stdout.splitlines() if line.strip()]
    allowed = all(
        any(path == prefix or path.startswith(prefix) for prefix in ALLOWED_CHANGED_PREFIXES)
        for path in paths
    )
    changed_src = _run(["git", "diff", "--name-only", FCI13_QUALIFICATION, "HEAD", "--", "src"])
    return {
        "diff_readable": diff.returncode == 0,
        "qualification_paths_only": allowed,
        "no_production_src_changes": changed_src.returncode == 0 and not changed_src.stdout.strip(),
    }


def assess() -> dict[str, Any]:
    sections = {
        "fci13_status": check_fci13_status(),
        "failure_evidence": check_failure_evidence(),
        "fvq02_carry_forward": check_fvq02_carry_forward(),
        "readiness": check_readiness(),
        "matrix": validate_matrix(_json(MATRIX)),
        "harness": check_harness(),
        "change_scope": check_change_scope(),
    }
    failures = [
        f"{section}.{name}"
        for section, checks in sections.items()
        for name, passed in checks.items()
        if passed is not True
    ]
    return {
        "workstream": "F-VQ",
        "work_unit": "F-VQ03",
        "status": "PASS" if not failures else "FAIL",
        "qualification_scope": "FCI13_SOURCE_BOUND_STATUS_AND_TRANSACTION_SEMANTICS",
        "source_head": FCI13_SOURCE,
        "oracle": "B1.10",
        "recoverable_status_contract_qualified": not failures,
        "real_terminal_failure_physics_qualified": False,
        "canonical_reference_admission": "BLOCKED_FAIL_CLOSED",
        "production_source_changed": False,
        "failed": failures,
        "sections": sections,
    }


def main() -> int:
    result = assess()
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
