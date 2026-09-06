#!/usr/bin/env python3
"""Fail-closed admission gate for the SWAP5/B2 reference adapter target.

Verification infrastructure only. This module does not execute SWAP5 physics.
It determines whether an integrated, exactly pinned B2 reference-mode entrypoint
exists with the minimum contracts required before VQ may perform B1 -> B2 runs.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CANDIDATE = REPO_ROOT / "tools" / "vq" / "cases" / "b2-reference-candidate.json"
QUALIFIED_B1_SNAPSHOT = "B1.7"
QUALIFIED_B1_STATUS = "QUALIFIED_NUMERICAL_BEHAVIOURAL"

REQUIRED_CAPABILITIES = (
    "callable_reference_entrypoint",
    "generic_interval_t0_t1",
    "committed_state_input",
    "forcing_input",
    "numerical_config_separate",
    "canonical_result_output",
    "unrounded_mass_accounting",
    "transaction_diagnostics",
)

READY = "READY_FOR_VQ_B1_TO_B2"


def _valid_sha(value: object) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None


def assess_candidate(repo_root: Path, candidate_path: Path = DEFAULT_CANDIDATE) -> dict[str, Any]:
    candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
    result: dict[str, Any] = {
        "candidate": str(candidate_path),
        "b1_snapshot": candidate.get("b1_oracle", {}).get("snapshot"),
        "b2_commit": candidate.get("b2", {}).get("commit"),
        "candidate_status": candidate.get("b2", {}).get("status"),
        "admissible_adapter_target": False,
        "checks": {},
        "missing_capabilities": [],
    }

    b1 = candidate.get("b1_oracle", {})
    b2 = candidate.get("b2", {})
    integration = b2.get("integration", {})
    capabilities = b2.get("capabilities", {})

    checks = result["checks"]
    checks["b1_oracle_qualified"] = (
        b1.get("snapshot") == QUALIFIED_B1_SNAPSHOT
        and b1.get("qualification") == QUALIFIED_B1_STATUS
    )
    checks["exact_b2_commit"] = _valid_sha(b2.get("commit"))
    checks["ready_status"] = b2.get("status") == READY

    entrypoint = integration.get("entrypoint_path")
    result_contract = integration.get("result_contract_path")
    checks["entrypoint_declared"] = isinstance(entrypoint, str) and bool(entrypoint.strip())
    checks["result_contract_declared"] = isinstance(result_contract, str) and bool(result_contract.strip())
    checks["reference_policy_explicit"] = bool(integration.get("reference_policy"))

    checks["entrypoint_exists"] = bool(
        checks["entrypoint_declared"] and (repo_root / str(entrypoint)).is_file()
    )
    checks["result_contract_exists"] = bool(
        checks["result_contract_declared"] and (repo_root / str(result_contract)).is_file()
    )

    missing = [name for name in REQUIRED_CAPABILITIES if capabilities.get(name) is not True]
    result["missing_capabilities"] = missing
    checks["required_capabilities"] = not missing

    result["admissible_adapter_target"] = all(checks.values())
    if not result["admissible_adapter_target"]:
        if not checks["b1_oracle_qualified"]:
            result["failure"] = "b1_oracle_not_current_or_not_qualified"
        elif not checks["ready_status"]:
            result["failure"] = "b2_reference_entrypoint_not_ready"
        elif not checks["exact_b2_commit"]:
            result["failure"] = "invalid_or_missing_b2_commit"
        elif not checks["entrypoint_exists"]:
            result["failure"] = "integrated_entrypoint_missing"
        elif not checks["result_contract_exists"]:
            result["failure"] = "result_contract_missing"
        elif missing:
            result["failure"] = "required_b2_capability_missing"
        else:
            result["failure"] = "b2_adapter_admission_failed"
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Assess whether an integrated B2 reference adapter target is admissible.")
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    parser.add_argument("--candidate", type=Path, default=DEFAULT_CANDIDATE)
    args = parser.parse_args()
    result = assess_candidate(args.repo_root, args.candidate)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["admissible_adapter_target"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
