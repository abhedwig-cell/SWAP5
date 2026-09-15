#!/usr/bin/env python3
"""F-VQ01 fail-closed admission gate for the exact F-CI11 qualification baseline.

Verification infrastructure only. This gate must not execute or modify production
source. It verifies provenance, oracle admission, matrix semantics, selected
existing qualification evidence and the expected blocked canonical-reference
admission state.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCE_HEAD = "4e8894fc741d7abd711367f712e7aad29d1361eb"
EVIDENCE_COMMIT = "b18150cb4f5313f01fc1c775917c617b421c9ba0"
WORKFLOW_RUN = 34100440481
B1_MANIFEST = "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"

MATRIX = REPO_ROOT / "integration" / "f-vq" / "F-VQ01_ADMISSION_MATRIX.json"
INVENTORY = REPO_ROOT / "integration" / "f-vq" / "F-VQ01_ASSET_INVENTORY.json"
B1_SNAPSHOT = REPO_ROOT / "reference" / "swap-4.3.1" / "snapshots" / "B1.10.yml"
FCI11_EVIDENCE = REPO_ROOT / "integration" / "f-ci" / "evidence" / "F-CI11_CANONICAL_GATE.json"
FCI11_LOCAL = REPO_ROOT / "integration" / "f-ci" / "evidence" / "F-CI11_LOCAL_GENERIC_INTERVAL_GATE.json"

ALLOWED_CLASSIFICATIONS = {
    "DIRECTLY_REUSABLE",
    "REBASE_REQUIRED",
    "BLOCKED_BY_FCI12",
    "BLOCKED_BY_TEMPORAL_ERROR",
    "BLOCKED_BY_RESULT_CONTRACT",
    "SUPERSEDED",
    "HISTORICAL_ONLY",
}
BLOCKING_CLASSIFICATIONS = {
    "BLOCKED_BY_FCI12",
    "BLOCKED_BY_TEMPORAL_ERROR",
    "BLOCKED_BY_RESULT_CONTRACT",
}
REQUIRED_CLAIM_FIELDS = {
    "claim_id",
    "architecture_invariants",
    "source_commit",
    "oracle",
    "test_harness",
    "expected_outcome",
    "classification",
    "current_status",
    "blocker",
    "qualification_evidence",
    "hard_mass_gate",
    "contract_exists",
    "implementation_exists",
    "test_executable",
    "test_pass",
    "claim_qualified",
}


def _run(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=REPO_ROOT, text=True, capture_output=True, check=False)


def _json(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"expected JSON object: {path}")
    return data


def validate_matrix(data: dict[str, Any]) -> dict[str, bool]:
    claims = data.get("claims")
    checks: dict[str, bool] = {
        "matrix_work_unit": data.get("work_unit") == "F-VQ01",
        "matrix_source_pin": data.get("qualified_source_head") == SOURCE_HEAD,
        "matrix_evidence_pin": data.get("qualification_evidence_commit") == EVIDENCE_COMMIT,
        "matrix_workflow_pin": data.get("canonical_workflow_run") == WORKFLOW_RUN,
        "matrix_oracle_pin": data.get("oracle", {}).get("snapshot") == "B1.10"
        and data.get("oracle", {}).get("source_manifest_sha256") == B1_MANIFEST,
        "claims_present": isinstance(claims, list) and bool(claims),
    }
    if not isinstance(claims, list):
        return checks

    ids = [item.get("claim_id") for item in claims if isinstance(item, dict)]
    checks["claim_ids_unique"] = len(ids) == len(set(ids)) == len(claims)
    checks["claim_fields_complete"] = all(
        isinstance(item, dict) and REQUIRED_CLAIM_FIELDS.issubset(item) for item in claims
    )
    checks["classifications_allowed"] = all(
        isinstance(item, dict) and item.get("classification") in ALLOWED_CLASSIFICATIONS for item in claims
    )
    checks["source_exact_per_claim"] = all(
        not isinstance(item, dict) or item.get("source_commit") == SOURCE_HEAD for item in claims
    )
    checks["blocked_never_qualified"] = all(
        not isinstance(item, dict)
        or item.get("classification") not in BLOCKING_CLASSIFICATIONS
        or item.get("claim_qualified") is False
        for item in claims
    )
    checks["no_missing_blocker_on_blocked_status"] = all(
        not isinstance(item, dict)
        or item.get("current_status") != "BLOCKED"
        or bool(item.get("blocker"))
        for item in claims
    )
    checks["qualified_requires_execution_evidence"] = all(
        not isinstance(item, dict)
        or item.get("claim_qualified") is not True
        or (
            item.get("implementation_exists") is True
            and item.get("test_executable") is True
            and str(item.get("test_pass", "")).startswith("PASS")
            and bool(item.get("qualification_evidence"))
        )
        for item in claims
    )
    warm = next((item for item in claims if item.get("claim_id") == "FVQ-C09"), {})
    checks["testdouble_not_physics"] = (
        warm.get("claim_qualified") is False
        and warm.get("implementation_exists") is False
        and warm.get("test_pass") == "NOT_RUN_ON_PRODUCTION"
    )
    return checks


def validate_inventory(data: dict[str, Any]) -> dict[str, bool]:
    assets = data.get("assets")
    checks = {
        "inventory_source_pin": data.get("qualified_source_head") == SOURCE_HEAD,
        "assets_present": isinstance(assets, list) and bool(assets),
    }
    if not isinstance(assets, list):
        return checks
    ids = [item.get("asset_id") for item in assets if isinstance(item, dict)]
    checks["asset_ids_unique"] = len(ids) == len(set(ids)) == len(assets)
    checks["asset_classifications_allowed"] = all(
        isinstance(item, dict) and item.get("classification") in ALLOWED_CLASSIFICATIONS for item in assets
    )
    synthetic = next((item for item in assets if item.get("asset_id") == "FVQ-A16"), {})
    checks["historical_testdouble_not_reused_as_physics"] = synthetic.get("classification") == "HISTORICAL_ONLY"
    stale_candidate = next((item for item in assets if item.get("asset_id") == "FVQ-A06"), {})
    checks["stale_b2_candidate_requires_rebase"] = stale_candidate.get("classification") == "REBASE_REQUIRED"
    return checks


def check_source_provenance() -> dict[str, bool]:
    parent = _run(["git", "rev-parse", f"{EVIDENCE_COMMIT}^"])
    source_object = _run(["git", "cat-file", "-e", f"{SOURCE_HEAD}^{{commit}}"])
    evidence_object = _run(["git", "cat-file", "-e", f"{EVIDENCE_COMMIT}^{{commit}}"])
    changed_src = _run(["git", "diff", "--name-only", SOURCE_HEAD, "HEAD", "--", "src"])
    evidence = _json(FCI11_EVIDENCE)

    return {
        "source_commit_present": source_object.returncode == 0,
        "evidence_commit_present": evidence_object.returncode == 0,
        "evidence_direct_parent_is_source": parent.returncode == 0 and parent.stdout.strip() == SOURCE_HEAD,
        "fci11_evidence_source_pin": evidence.get("qualified_source_head") == SOURCE_HEAD,
        "fci11_evidence_workflow_pin": evidence.get("workflow_run") == WORKFLOW_RUN,
        "fci03_to_fci11_chain_green": all(
            value == "PASS" for value in evidence.get("full_dependency_chain", {}).values()
        ) and set(evidence.get("full_dependency_chain", {})) == {
            "F-CI03", "F-CI04", "F-CI05", "F-CI06", "F-CI07",
            "F-CI08", "F-CI09", "F-CI10", "F-CI11",
        },
        "fvq_changes_no_production_src": changed_src.returncode == 0 and not changed_src.stdout.strip(),
    }


def check_b1_snapshot() -> dict[str, bool]:
    text = B1_SNAPSHOT.read_text(encoding="utf-8")
    return {
        "b1_10_snapshot_named": 'snapshot: "B1.10"' in text,
        "b1_10_manifest_exact": B1_MANIFEST in text,
        "b1_10_reconstructor_declared": 'reconstruction: "tools/vq/b1_10_reconstruct.py"' in text,
        "b0_archive_pin_present": "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151" in text,
    }


def run_existing_gates() -> dict[str, bool]:
    b1 = _run([sys.executable, "tools/vq/b1_10_admission_gate.py"])
    b2 = _run([sys.executable, "tools/vq/b2_reference_gate.py"])
    b2_json: dict[str, Any] = {}
    try:
        b2_json = json.loads(b2.stdout)
    except json.JSONDecodeError:
        pass
    return {
        "b1_10_admission_pass": b1.returncode == 0,
        "b2_gate_executes_fail_closed": b2.returncode == 2 and b2_json.get("admissible_adapter_target") is False,
        "b2_not_ready_is_explicit": b2_json.get("failure") in {
            "b2_reference_entrypoint_not_ready",
            "integrated_entrypoint_missing",
            "result_contract_missing",
            "required_b2_capability_missing",
        },
    }


def check_fci11_scope() -> dict[str, bool]:
    evidence = _json(FCI11_EVIDENCE)
    local = _json(FCI11_LOCAL)
    focused = evidence.get("focused_checks", {})
    hard_limit = local.get("hard_mass_limit_cm")
    max_resid = local.get("max_abs_residual_cm")
    return {
        "generic_non_midnight_evidence": local.get("generic_interval", {}).get("includes_non_midnight") is True,
        "generic_cross_day_evidence": local.get("generic_interval", {}).get("includes_cross_calendar_day") is True,
        "hard_mass_bound_numeric": isinstance(hard_limit, (int, float))
        and isinstance(max_resid, (int, float))
        and max_resid <= hard_limit,
        "o0_o2_identity": local.get("o0_o2_identity") is True,
        "unrounded_mass_wiring": focused.get("integral_records_unrounded_step") is True
        and focused.get("trial_mass_wired_timestep") is True,
        "temporal_error_remains_unqualified": local.get("temporal_error_metric_qualified") is False
        and focused.get("temporal_error_not_claimed") is True,
        "snow_and_macropore_not_silently_admitted": evidence.get("result", "").endswith(
            "REFERENCE_TEMPORAL_POLICY_BLOCKED"
        ),
    }


def assess() -> dict[str, Any]:
    sections = {
        "source_provenance": check_source_provenance(),
        "b1_snapshot": check_b1_snapshot(),
        "matrix": validate_matrix(_json(MATRIX)),
        "inventory": validate_inventory(_json(INVENTORY)),
        "existing_gates": run_existing_gates(),
        "fci11_scope": check_fci11_scope(),
    }
    failed = [
        f"{section}.{name}"
        for section, checks in sections.items()
        for name, passed in checks.items()
        if passed is not True
    ]
    return {
        "workstream": "F-VQ",
        "work_unit": "F-VQ01",
        "source_head": SOURCE_HEAD,
        "oracle": "B1.10",
        "status": "PASS" if not failed else "FAIL",
        "sections": sections,
        "failed": failed,
        "production_source_changed": False if sections["source_provenance"].get("fvq_changes_no_production_src") else None,
        "canonical_reference_admission": "BLOCKED_FAIL_CLOSED",
    }


def main() -> int:
    result = assess()
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
