#!/usr/bin/env python3
"""Fail-closed VQ admission gate for binding the TX/TIME harness to production B2.

VQ-1e2 does not execute production physics. It proves only that a non-synthetic
verification bridge is exactly bound to an already-admitted B2 reference seam.
Only a later VQ slice may execute TX/TIME cases through that bridge.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

try:
    from tools.vq.b2_reference_gate import assess_candidate as assess_b2_candidate
    from tools.vq.production_adapter_binding import assess_binding
except ModuleNotFoundError:  # direct script execution from tools/vq
    from b2_reference_gate import assess_candidate as assess_b2_candidate
    from production_adapter_binding import assess_binding

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CANDIDATE = REPO_ROOT / "tools" / "vq" / "cases" / "b2-production-adapter-candidate.json"
DEFAULT_EVIDENCE = REPO_ROOT / "tools" / "vq" / "cases" / "vq-1e2-production-adapter-gate-2026-09-06.json"

READY = "READY_FOR_PRODUCTION_TX_TIME_QUALIFICATION"
BLOCKED_NO_B2 = "BLOCKED_NO_ADMITTED_B2_SEAM"
BLOCKED_NO_BINDING = "BLOCKED_NO_PRODUCTION_ADAPTER_BINDING"


def _declared_path(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def assess_candidate(repo_root: Path, candidate_path: Path = DEFAULT_CANDIDATE) -> dict[str, Any]:
    try:
        candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {
            "candidate": str(candidate_path),
            "ready_for_production_tx_time": False,
            "checks": {"candidate_readable": False},
            "failure": "production_adapter_candidate_unreadable",
            "detail": str(exc),
        }

    b2_candidate_value = candidate.get("b2_candidate_path")
    binding_value = candidate.get("binding_contract_path")
    checks: dict[str, bool] = {}
    checks["schema_version"] = candidate.get("schema_version") == 1
    checks["b2_candidate_declared"] = _declared_path(b2_candidate_value)
    b2_candidate_path = repo_root / str(b2_candidate_value) if checks["b2_candidate_declared"] else None
    checks["b2_candidate_exists"] = bool(b2_candidate_path and b2_candidate_path.is_file())

    b2_result: dict[str, Any] | None = None
    b2_data: dict[str, Any] | None = None
    if checks["b2_candidate_exists"] and b2_candidate_path is not None:
        b2_result = assess_b2_candidate(repo_root, b2_candidate_path)
        b2_data = json.loads(b2_candidate_path.read_text(encoding="utf-8"))
    checks["b2_target_admitted"] = bool(
        b2_result is not None and b2_result.get("admissible_adapter_target") is True
    )

    checks["ready_status"] = candidate.get("status") == READY
    checks["binding_contract_declared"] = _declared_path(binding_value)
    binding_path = repo_root / str(binding_value) if checks["binding_contract_declared"] else None
    checks["binding_contract_exists"] = bool(binding_path and binding_path.is_file())

    binding_result: dict[str, Any] | None = None
    if checks["binding_contract_exists"] and binding_path is not None:
        binding_result = assess_binding(repo_root, binding_path)
    checks["binding_contract_valid"] = bool(
        binding_result is not None
        and binding_result.get("admissible_production_adapter_binding") is True
    )

    b2_integration = ((b2_data or {}).get("b2") or {}).get("integration", {})
    b2_commit = (b2_result or {}).get("b2_commit")
    checks["binding_commit_matches_b2"] = bool(
        binding_result is not None
        and binding_result.get("implementation_commit") == b2_commit
    )
    checks["binding_entrypoint_matches_b2"] = bool(
        binding_result is not None
        and binding_result.get("entrypoint_path") == b2_integration.get("entrypoint_path")
    )
    checks["binding_seam_matches_b2"] = bool(
        binding_result is not None
        and binding_result.get("seam_contract_path") == b2_integration.get("seam_contract_path")
    )
    checks["binding_result_contract_matches_b2"] = bool(
        binding_result is not None
        and binding_result.get("result_contract_path") == b2_integration.get("result_contract_path")
    )
    checks["binding_reference_policy_matches_b2"] = bool(
        binding_result is not None
        and binding_result.get("reference_policy") == b2_integration.get("reference_policy") == "reference"
    )

    ready = all(checks.values())
    result: dict[str, Any] = {
        "candidate": str(candidate_path),
        "candidate_status": candidate.get("status"),
        "b2_candidate_path": b2_candidate_value,
        "binding_contract_path": binding_value,
        "b1_snapshot": (b2_result or {}).get("b1_snapshot"),
        "b2_commit": b2_commit,
        "b2_admissible_target": checks["b2_target_admitted"],
        "production_adapter_binding_admissible": checks["binding_contract_valid"],
        "ready_for_production_tx_time": ready,
        "checks": checks,
        "b2_gate": b2_result,
        "binding": binding_result,
    }

    if not ready:
        if not checks["b2_candidate_exists"]:
            result["failure"] = "b2_reference_candidate_missing"
        elif not checks["b2_target_admitted"]:
            result["failure"] = "b2_reference_target_not_admitted"
        elif not checks["ready_status"]:
            result["failure"] = "production_adapter_binding_not_ready"
        elif not checks["binding_contract_exists"]:
            result["failure"] = "production_adapter_binding_missing"
        elif not checks["binding_contract_valid"]:
            result["failure"] = "production_adapter_binding_invalid"
        elif not all(
            checks[name]
            for name in (
                "binding_commit_matches_b2",
                "binding_entrypoint_matches_b2",
                "binding_seam_matches_b2",
                "binding_result_contract_matches_b2",
                "binding_reference_policy_matches_b2",
            )
        ):
            result["failure"] = "production_adapter_binding_candidate_mismatch"
        else:
            result["failure"] = "production_adapter_admission_failed"
    return result


def evidence_projection(result: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "workstream": "VQ",
        "slice": "VQ-1e2",
        "candidate_status": result.get("candidate_status"),
        "b2_candidate_path": result.get("b2_candidate_path"),
        "binding_contract_path": result.get("binding_contract_path"),
        "b1_snapshot": result.get("b1_snapshot"),
        "b2_commit": result.get("b2_commit"),
        "b2_admissible_target": result.get("b2_admissible_target"),
        "production_adapter_binding_admissible": result.get("production_adapter_binding_admissible"),
        "ready_for_production_tx_time": result.get("ready_for_production_tx_time"),
        "failure": result.get("failure"),
        "checks": result.get("checks"),
    }


def check_stored_evidence(result: dict[str, Any], evidence_path: Path) -> dict[str, Any]:
    stored = json.loads(evidence_path.read_text(encoding="utf-8"))
    expected = evidence_projection(result)
    mismatches = {
        key: {"expected": expected.get(key), "stored": stored.get(key)}
        for key in expected
        if stored.get(key) != expected.get(key)
    }
    return {"consistent": not mismatches, "mismatches": mismatches, "expected_projection": expected}


def main() -> int:
    parser = argparse.ArgumentParser(description="Assess VQ-1e2 production-adapter admission.")
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    parser.add_argument("--candidate", type=Path, default=DEFAULT_CANDIDATE)
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--allow-expected-blocked", action="store_true")
    args = parser.parse_args()

    result = assess_candidate(args.repo_root, args.candidate)
    evidence_check: dict[str, Any] | None = None
    if args.evidence is not None:
        evidence_check = check_stored_evidence(result, args.evidence)
        result["stored_evidence"] = {"path": str(args.evidence), **evidence_check}

    print(json.dumps(result, indent=2, sort_keys=True))

    if evidence_check is not None and not evidence_check["consistent"]:
        return 3
    if result.get("ready_for_production_tx_time"):
        return 0
    if args.allow_expected_blocked:
        expected = (
            result.get("candidate_status") == BLOCKED_NO_B2
            and result.get("failure") == "b2_reference_target_not_admitted"
        ) or (
            result.get("candidate_status") == BLOCKED_NO_BINDING
            and result.get("failure") == "production_adapter_binding_not_ready"
        )
        if expected:
            return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
