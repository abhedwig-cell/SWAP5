#!/usr/bin/env python3
"""Fail-closed VQ-1e3 admission gate for production TX/TIME execution.

This gate does not execute SWAP5 physics. It proves that the already-qualified
VQ TX/TIME suite may be bound to a real, non-synthetic production adapter.
Only after this gate passes may a production runner load the adapter and execute
TX/TIME cases. A blocked result keeps production physics NOT_EVALUATED.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

try:
    from tools.vq.production_adapter_gate import assess_candidate as assess_adapter_candidate
    from tools.vq.tx_time_harness import CASE_IDS
except ModuleNotFoundError:  # direct script execution from tools/vq
    from production_adapter_gate import assess_candidate as assess_adapter_candidate
    from tx_time_harness import CASE_IDS

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CANDIDATE = REPO_ROOT / "tools" / "vq" / "cases" / "b2-production-execution-candidate.json"
DEFAULT_EVIDENCE = REPO_ROOT / "tools" / "vq" / "cases" / "vq-1e3-production-execution-gate-2026-09-06.json"

READY = "READY_FOR_PRODUCTION_TX_TIME_EXECUTION"
BLOCKED_NO_BINDING = "BLOCKED_NO_PRODUCTION_ADAPTER_BINDING"
SUITE_PROTOCOL = "VQ-TX-TIME-SUITE-v1"
ADAPTER_PROTOCOL = "VQ-QualificationAdapter-v1"


def _declared_path(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _declared_symbol(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def assess_candidate(repo_root: Path, candidate_path: Path = DEFAULT_CANDIDATE) -> dict[str, Any]:
    try:
        candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {
            "candidate": str(candidate_path),
            "production_execution_admissible": False,
            "production_physics_executed": False,
            "b2_physics_status": "NOT_EVALUATED",
            "production_mass_tolerance_qualified": False,
            "checks": {"candidate_readable": False},
            "failure": "production_execution_candidate_unreadable",
            "detail": str(exc),
        }

    adapter_candidate_value = candidate.get("production_adapter_candidate_path")
    loader = candidate.get("adapter_loader", {})
    suite = candidate.get("suite", {})
    claims = candidate.get("pre_execution_claims", {})

    checks: dict[str, bool] = {}
    checks["schema_version"] = candidate.get("schema_version") == 1
    checks["adapter_candidate_declared"] = _declared_path(adapter_candidate_value)
    adapter_candidate_path = (
        repo_root / str(adapter_candidate_value)
        if checks["adapter_candidate_declared"]
        else None
    )
    checks["adapter_candidate_exists"] = bool(
        adapter_candidate_path and adapter_candidate_path.is_file()
    )

    adapter_result: dict[str, Any] | None = None
    if checks["adapter_candidate_exists"] and adapter_candidate_path is not None:
        adapter_result = assess_adapter_candidate(repo_root, adapter_candidate_path)
    checks["production_adapter_binding_admitted"] = bool(
        adapter_result is not None
        and adapter_result.get("ready_for_production_tx_time") is True
    )

    checks["ready_status"] = candidate.get("status") == READY
    module_path = loader.get("module_path")
    factory_symbol = loader.get("factory_symbol")
    checks["adapter_loader_declared"] = _declared_path(module_path)
    checks["adapter_loader_exists"] = bool(
        checks["adapter_loader_declared"] and (repo_root / str(module_path)).is_file()
    )
    checks["adapter_factory_declared"] = _declared_symbol(factory_symbol)
    checks["adapter_protocol"] = loader.get("adapter_protocol") == ADAPTER_PROTOCOL

    case_ids = suite.get("required_case_ids")
    checks["suite_protocol"] = suite.get("protocol") == SUITE_PROTOCOL
    checks["suite_case_ids_exact"] = (
        isinstance(case_ids, list)
        and len(case_ids) == len(CASE_IDS)
        and len(set(case_ids)) == len(CASE_IDS)
        and set(case_ids) == set(CASE_IDS)
    )

    checks["no_premature_execution_claim"] = (
        claims.get("production_execution_claimed") is False
    )
    checks["pre_execution_physics_not_evaluated"] = (
        claims.get("b2_physics_status") == "NOT_EVALUATED"
    )
    checks["pre_execution_mass_not_qualified"] = (
        claims.get("production_mass_tolerance_qualified") is False
    )

    admissible = all(checks.values())
    result: dict[str, Any] = {
        "candidate": str(candidate_path),
        "candidate_status": candidate.get("status"),
        "production_adapter_candidate_path": adapter_candidate_value,
        "adapter_loader_module_path": module_path,
        "adapter_factory_symbol": factory_symbol,
        "suite_protocol": suite.get("protocol"),
        "required_case_ids": case_ids,
        "b1_snapshot": (adapter_result or {}).get("b1_snapshot"),
        "b2_commit": (adapter_result or {}).get("b2_commit"),
        "production_adapter_binding_admitted": checks["production_adapter_binding_admitted"],
        "production_execution_admissible": admissible,
        "production_physics_executed": False,
        "b2_physics_status": "NOT_EVALUATED",
        "production_mass_tolerance_qualified": False,
        "checks": checks,
        "production_adapter_gate": adapter_result,
    }

    if not admissible:
        if not checks["adapter_candidate_exists"]:
            result["failure"] = "production_adapter_candidate_missing"
        elif not checks["production_adapter_binding_admitted"]:
            result["failure"] = "production_adapter_binding_not_admitted"
        elif not checks["ready_status"]:
            result["failure"] = "production_execution_not_ready"
        elif not checks["adapter_loader_exists"]:
            result["failure"] = "production_adapter_loader_missing"
        elif not checks["adapter_factory_declared"]:
            result["failure"] = "production_adapter_factory_missing"
        elif not checks["adapter_protocol"]:
            result["failure"] = "production_adapter_protocol_mismatch"
        elif not checks["suite_protocol"] or not checks["suite_case_ids_exact"]:
            result["failure"] = "production_tx_time_suite_mismatch"
        elif not all(
            checks[name]
            for name in (
                "no_premature_execution_claim",
                "pre_execution_physics_not_evaluated",
                "pre_execution_mass_not_qualified",
            )
        ):
            result["failure"] = "premature_production_execution_claim"
        else:
            result["failure"] = "production_execution_admission_failed"
    return result


def evidence_projection(result: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "workstream": "VQ",
        "slice": "VQ-1e3",
        "candidate_status": result.get("candidate_status"),
        "production_adapter_candidate_path": result.get("production_adapter_candidate_path"),
        "adapter_loader_module_path": result.get("adapter_loader_module_path"),
        "adapter_factory_symbol": result.get("adapter_factory_symbol"),
        "suite_protocol": result.get("suite_protocol"),
        "required_case_ids": result.get("required_case_ids"),
        "b1_snapshot": result.get("b1_snapshot"),
        "b2_commit": result.get("b2_commit"),
        "production_adapter_binding_admitted": result.get("production_adapter_binding_admitted"),
        "production_execution_admissible": result.get("production_execution_admissible"),
        "production_physics_executed": result.get("production_physics_executed"),
        "b2_physics_status": result.get("b2_physics_status"),
        "production_mass_tolerance_qualified": result.get("production_mass_tolerance_qualified"),
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
    return {
        "consistent": not mismatches,
        "mismatches": mismatches,
        "expected_projection": expected,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Assess VQ-1e3 production TX/TIME execution admission.")
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
    if result.get("production_execution_admissible"):
        return 0
    if (
        args.allow_expected_blocked
        and result.get("candidate_status") == BLOCKED_NO_BINDING
        and result.get("failure") == "production_adapter_binding_not_admitted"
        and result.get("production_physics_executed") is False
        and result.get("b2_physics_status") == "NOT_EVALUATED"
    ):
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
