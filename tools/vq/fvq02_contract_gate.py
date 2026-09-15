#!/usr/bin/env python3
"""F-VQ02 fail-closed verifier-contract rebase gate.

Qualification infrastructure only. This gate qualifies reusable verifier logic on
the exact F-CI12 repository basis. It never upgrades deterministic testdouble
results to production-physics qualification and keeps canonical reference
execution blocked while F-CI12 says that route is not admitted.
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any

from tools.vq.tx_time_harness import run_fixture_suite, check_stored_evidence

REPO_ROOT = Path(__file__).resolve().parents[2]
FCI12_SOURCE = "7098aeaa4ca38dc375a965340a35c9870a33de28"
FCI12_EVIDENCE_COMMIT = "729574de00fbb1540affe2af74a7202b38d29754"
FCI12_RUN = 34102787767
HISTORICAL_HEAD = "29e05be97493926ba451dfd53d5ed3170db47ad5"
BASELINE_COMMIT = FCI12_EVIDENCE_COMMIT

PROVENANCE = REPO_ROOT / "integration/f-vq/F-VQ02_PROVENANCE.json"
READINESS = REPO_ROOT / "integration/f-vq/F-VQ02_REFERENCE_READINESS.json"
MATRIX = REPO_ROOT / "integration/f-vq/F-VQ02_CONTRACT_MATRIX.json"
FCI12_EVIDENCE = REPO_ROOT / "integration/f-ci/evidence/F-CI12_GATE_RESULT.json"
HARNESS_EVIDENCE = REPO_ROOT / "tools/vq/cases/vq-1e1-tx-time-harness-2026-09-06.json"

ALLOWED_CHANGED_PREFIXES = (
    ".github/workflows/vq-reference.yml",
    "docs/verification/",
    "integration/f-vq/",
    "tools/vq/",
)

EXPECTED_BLOBS = {
    "tools/vq/b2_seam_contract.py": "210847d9eb906fb1ddbf4ba4f65ca26156cad4af",
    "tools/vq/b2_result_contract.py": "75632937fcd7f99a75a99e227821afd3c4748999",
    "tools/vq/b2_result_record.py": "6e01be04258799f0f4d42040f0b5ffe4fe2b6be8",
    "tools/vq/tx_time_harness.py": "7b82912499bafcfe510a5e4219b50bbea7837f8c",
    "tools/vq/test_b2_seam_contract.py": "614b889e1bc30de3281c68446ce341a52b0bedef",
    "tools/vq/test_b2_result_contract.py": "a2af14f4ce31c956a5a125c096aa07ffb78ec93f",
    "tools/vq/test_b2_result_record.py": "8f9872c72cb2af9e50fd90ef4b3d26734e1f007d",
    "tools/vq/test_tx_time_harness.py": "eeb738bdf16d618f70cc1085e8c93646ff9bb9a4",
    "tools/vq/contracts/b2-reference-seam.schema.json": "0769b8e167b29b3400d7a87b647c1d6d4dbc63ee",
    "tools/vq/contracts/b2-reference-result-contract.schema.json": "0498f5e3c43859f4bcb8886c7698d5834851e79e",
    "tools/vq/contracts/b2-reference-result-record.schema.json": "053dc2d05a98f7ac444fc78cdb882af6434c6df9",
    "tools/vq/cases/vq-1e1-tx-time-harness-2026-09-06.json": "ab4b0b3a09cce58f482a5484a9eee88f721aca6e",
}


def _json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def _run(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=REPO_ROOT, text=True, capture_output=True, check=False)


def git_blob_sha(path: str) -> str | None:
    proc = _run(["git", "hash-object", path])
    return proc.stdout.strip() if proc.returncode == 0 else None


def check_provenance() -> dict[str, bool]:
    data = _json(PROVENANCE)
    items = data.get("directly_reused_verifier_assets", [])
    declared = {
        item.get("path"): item.get("blob_sha")
        for item in items
        if isinstance(item, dict)
    }
    return {
        "historical_head_pinned": data.get("historical_source", {}).get("head") == HISTORICAL_HEAD,
        "historical_scope_verifier_only": data.get("historical_source", {}).get("scope") == "VERIFIER_HARNESS_ONLY",
        "fci12_source_pinned": data.get("rebased_qualification_basis", {}).get("fci12_source") == FCI12_SOURCE,
        "fci12_evidence_pinned": data.get("rebased_qualification_basis", {}).get("fci12_evidence") == FCI12_EVIDENCE_COMMIT,
        "asset_set_exact": declared == EXPECTED_BLOBS,
        "live_blobs_exact": all(git_blob_sha(path) == sha for path, sha in EXPECTED_BLOBS.items()),
        "stale_candidate_excluded": any(
            item.get("path") == "tools/vq/cases/b2-reference-candidate.json"
            for item in data.get("excluded_historical_assets", [])
            if isinstance(item, dict)
        ),
    }


def check_fci12() -> dict[str, bool]:
    evidence = _json(FCI12_EVIDENCE)
    admitted = evidence.get("admitted", {})
    blocked = evidence.get("not_admitted", {})
    parent = _run(["git", "rev-parse", f"{FCI12_EVIDENCE_COMMIT}^"])
    return {
        "source_head_exact": evidence.get("qualified_source_head") == FCI12_SOURCE,
        "evidence_parent_is_source": parent.returncode == 0 and parent.stdout.strip() == FCI12_SOURCE,
        "workflow_exact": evidence.get("canonical_ci", {}).get("run_id") == FCI12_RUN,
        "dependency_chain_pass": evidence.get("canonical_ci", {}).get("full_dependency_chain") == "PASS_FCI03_THROUGH_FCI12",
        "generic_binding_admitted": admitted.get("generic_physical_interval_executor_binding") is True,
        "unrounded_mass_admitted": admitted.get("unrounded_trial_mass_projection") is True,
        "storage_profile_admitted": admitted.get("qualified_profile_storage_projection") is True,
        "worker_diagnostics_admitted": admitted.get("worker_diagnostics_projection") is True,
        "testdouble_isolation_admitted": admitted.get("failed_testdouble_trial_state_isolation") is True,
        "recoverable_solver_status_blocked": blocked.get("recoverable_legacy_solver_failure_status") is True,
        "temporal_metric_blocked": blocked.get("scalar_temporal_error_metric") is True,
        "temporal_policy_blocked": blocked.get("scalar_temporal_tolerance_policy") is True,
        "reference_interval_blocked": blocked.get("execute_reference_interval_for_b1_10") is True,
        "end_to_end_blocked": blocked.get("real_b1_10_reference_model_end_to_end") is True,
        "optional_storage_blocked": blocked.get("snow_macropore_complete_storage") is True,
        "parallel_backend_blocked": blocked.get("reentrant_parallel_legacy_backend") is True,
        "evidence_scope_testdouble_explicit": "deterministic legacy testdouble" in evidence.get("evidence_scope", ""),
    }


def check_readiness() -> dict[str, bool]:
    data = _json(READINESS)
    caps = data.get("capabilities", {})
    admission = data.get("admission", {})
    return {
        "status_blocked": data.get("status") == "BLOCKED_REFERENCE_ROUTE_NOT_ADMITTED",
        "source_exact": data.get("source_commit") == FCI12_SOURCE,
        "oracle_b1_10": data.get("oracle") == "B1.10",
        "generic_binding_true": caps.get("generic_physical_interval_executor_binding") is True,
        "reference_interval_false": caps.get("execute_reference_interval_for_b1_10") is False,
        "production_result_false": caps.get("production_canonical_result_route") is False,
        "end_to_end_false": caps.get("real_b1_10_reference_end_to_end") is False,
        "ready_for_reference_false": admission.get("production_reference_adapter_may_be_declared_ready") is False,
        "numerical_qualification_false": admission.get("b1_10_to_canonical_reference_numerical_qualification_may_start") is False,
        "warm_start_false": admission.get("production_warm_start_claim_may_be_qualified") is False,
        "temporal_equivalence_false": admission.get("production_temporal_equivalence_claim_may_be_qualified") is False,
    }


def validate_matrix(data: dict[str, Any]) -> dict[str, bool]:
    claims = data.get("claims", [])
    verifier_scopes = {"VERIFIER_ONLY", "VERIFIER_TESTDOUBLE_ONLY"}
    ids = [item.get("claim_id") for item in claims if isinstance(item, dict)]
    blocked = [
        item for item in claims
        if isinstance(item, dict) and item.get("blocker")
    ]
    return {
        "work_unit": data.get("work_unit") == "F-VQ02",
        "oracle": data.get("oracle") == "B1.10",
        "source_exact": data.get("fci12_source_commit") == FCI12_SOURCE,
        "evidence_exact": data.get("fci12_evidence_commit") == FCI12_EVIDENCE_COMMIT,
        "historical_head_exact": data.get("historical_verifier_head") == HISTORICAL_HEAD,
        "claims_present": isinstance(claims, list) and len(claims) >= 10,
        "claim_ids_unique": len(ids) == len(set(ids)) == len(claims),
        "blocked_never_qualified": all(item.get("claim_qualified") is False for item in blocked),
        "testdouble_never_physics_qualified": all(
            item.get("claim_qualified") is False
            for item in claims
            if isinstance(item, dict) and item.get("scope") == "VERIFIER_TESTDOUBLE_ONLY"
        ),
        "verifier_claims_not_production": all(
            item.get("production_implementation_exists") is False
            for item in claims
            if isinstance(item, dict) and item.get("scope") in verifier_scopes
        ),
        "production_claims_require_real_implementation": all(
            item.get("claim_qualified") is not True or item.get("production_implementation_exists") is True
            for item in claims
            if isinstance(item, dict) and str(item.get("scope", "")).startswith("PRODUCTION")
        ),
        "fci12_binding_scope_narrow": any(
            item.get("claim_id") == "FVQ02-C05"
            and item.get("scope") == "FCI12_BINDING_AND_TRANSACTION_SEMANTICS"
            and item.get("claim_qualified") is True
            for item in claims if isinstance(item, dict)
        ),
        "reference_execution_blocked": any(
            item.get("claim_id") == "FVQ02-C07"
            and item.get("claim_qualified") is False
            and bool(item.get("blocker"))
            for item in claims if isinstance(item, dict)
        ),
    }


def check_harness() -> dict[str, bool]:
    historical = _json(HARNESS_EVIDENCE)
    report = run_fixture_suite()
    stored = check_stored_evidence(report, HARNESS_EVIDENCE)
    cases = report.get("cases", [])
    return {
        "historical_harness_pass": historical.get("harness_status") == "PASS",
        "historical_physics_not_evaluated": historical.get("b2_physics_status") == "NOT_EVALUATED",
        "historical_production_physics_false": historical.get("production_physics_executed") is False,
        "historical_mass_tolerance_false": historical.get("production_mass_tolerance_qualified") is False,
        "live_harness_pass": report.get("harness_status") == "PASS",
        "live_physics_not_evaluated": report.get("b2_physics_status") == "NOT_EVALUATED",
        "live_production_physics_false": report.get("production_physics_executed") is False,
        "eleven_cases_pass": len(cases) == 11 and all(item.get("status") == "PASS" for item in cases),
        "stored_evidence_consistent": stored.get("consistent") is True,
    }


def check_no_production_changes() -> dict[str, bool]:
    diff = _run(["git", "diff", "--name-only", BASELINE_COMMIT, "HEAD"])
    paths = [line.strip() for line in diff.stdout.splitlines() if line.strip()]
    allowed = all(any(path == prefix or path.startswith(prefix) for prefix in ALLOWED_CHANGED_PREFIXES) for path in paths)
    return {
        "diff_readable": diff.returncode == 0,
        "qualification_paths_only": allowed,
        "production_source_changed": not allowed,
    }


def assess() -> dict[str, Any]:
    sections = {
        "provenance": check_provenance(),
        "fci12": check_fci12(),
        "readiness": check_readiness(),
        "matrix": validate_matrix(_json(MATRIX)),
        "harness": check_harness(),
        "change_scope": check_no_production_changes(),
    }
    failures = []
    for section, checks in sections.items():
        for name, value in checks.items():
            expected = False if (section == "change_scope" and name == "production_source_changed") else True
            if value is not expected:
                failures.append(f"{section}.{name}")
    return {
        "workstream": "F-VQ",
        "work_unit": "F-VQ02",
        "status": "PASS" if not failures else "FAIL",
        "qualification_scope": "VERIFIER_CONTRACTS_AND_HARNESS_ONLY",
        "source_head": FCI12_SOURCE,
        "oracle": "B1.10",
        "canonical_reference_admission": "BLOCKED_FAIL_CLOSED",
        "production_physics_qualified": False,
        "production_source_changed": sections["change_scope"]["production_source_changed"],
        "sections": sections,
        "failed": failures,
    }


def main() -> int:
    result = assess()
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
