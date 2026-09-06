#!/usr/bin/env python3
"""Validate the semantic contract of a SWAP5/B2 reference-mode seam.

Verification infrastructure only. This validator does not prescribe the internal
SWAP5 object layout and does not execute model physics. It checks whether a
machine-readable seam declaration exposes the minimum properties required by
VQ before B1 -> B2 numerical qualification can begin.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

CONTRACT_ID = "SWAP5-B2-reference-seam-v1"
REQUIRED_DIAGNOSTICS = {
    "accepted",
    "execution_class",
    "retry_count",
    "solver_cost",
    "balance_residual",
}


def _valid_sha(value: object) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None


def _is_nonempty(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def assess_contract(repo_root: Path, contract_path: Path) -> dict[str, Any]:
    try:
        data = json.loads(contract_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {
            "contract": str(contract_path),
            "admissible_reference_seam": False,
            "checks": {"contract_readable": False},
            "failure": "reference_seam_contract_unreadable",
            "detail": str(exc),
        }

    implementation = data.get("implementation", {})
    policy = data.get("policy", {})
    inputs = data.get("inputs", {})
    transaction = data.get("transaction", {})
    outputs = data.get("outputs", {})
    mass = data.get("mass_accounting", {})
    diagnostics = data.get("diagnostics", {})
    forbidden = data.get("forbidden_dependencies", {})

    checks: dict[str, bool] = {}
    checks["schema_version"] = data.get("schema_version") == 1
    checks["contract_id"] = data.get("contract_id") == CONTRACT_ID
    checks["implementation_commit"] = _valid_sha(implementation.get("commit"))
    checks["implementation_integrated"] = implementation.get("integrated") is True
    checks["entrypoint_path_declared"] = _is_nonempty(implementation.get("entrypoint_path"))
    checks["entrypoint_symbol_declared"] = _is_nonempty(implementation.get("entrypoint_symbol"))
    checks["result_contract_path_declared"] = _is_nonempty(implementation.get("result_contract_path"))

    entrypoint_path = implementation.get("entrypoint_path")
    result_contract_path = implementation.get("result_contract_path")
    checks["entrypoint_exists"] = bool(
        checks["entrypoint_path_declared"] and (repo_root / str(entrypoint_path)).is_file()
    )
    checks["result_contract_exists"] = bool(
        checks["result_contract_path_declared"]
        and (repo_root / str(result_contract_path)).is_file()
    )

    checks["reference_policy"] = policy.get("reference_policy_id") == "reference"
    checks["full_accuracy"] = policy.get("full_accuracy") is True
    checks["policy_does_not_change_physics"] = policy.get("changes_physics") is False

    for name in ("parameters", "committed_state", "forcing", "numerical_config"):
        item = inputs.get(name, {})
        checks[f"input_{name}_explicit"] = item.get("explicit") is True
        checks[f"input_{name}_file_path_not_required"] = item.get("file_path_required") is False

    interval = inputs.get("interval", {})
    checks["generic_interval"] = interval.get("generic_t0_t1") is True
    checks["calendar_boundary_not_required"] = interval.get("calendar_boundary_required") is False

    checks["transaction_protocol"] = transaction.get("checkpoint_trial_commit_rollback") is True
    checks["rejected_trial_preserves_committed_state"] = (
        transaction.get("rejected_trial_mutates_committed_state") is False
    )
    checks["trial_endpoint_explicit"] = transaction.get("trial_endpoint_returned_explicitly") is True

    checks["endpoint_state_output"] = outputs.get("endpoint_state") is True
    checks["canonical_result_output"] = outputs.get("canonical_results") is True
    checks["unrounded_mass_output"] = outputs.get("unrounded_mass_accounting") is True
    checks["transaction_diagnostics_output"] = outputs.get("transaction_diagnostics") is True

    checks["mass_hard_acceptance"] = mass.get("hard_acceptance") is True
    checks["mass_identity"] = mass.get("identity") == "delta_storage_minus_net_external"
    checks["mass_rounding_forbidden"] = mass.get("rounded_acceptance_allowed") is False

    required_fields = diagnostics.get("required_fields")
    checks["diagnostics_required_fields"] = (
        isinstance(required_fields, list)
        and REQUIRED_DIAGNOSTICS.issubset(set(required_fields))
    )

    for name in (
        "kernel_file_io",
        "kernel_path_dependency",
        "kernel_modflow_tile_fraction",
        "hidden_calendar_day_assumption",
    ):
        checks[f"forbidden_{name}"] = forbidden.get(name) is False

    admissible = all(checks.values())
    result: dict[str, Any] = {
        "contract": str(contract_path),
        "contract_id": data.get("contract_id"),
        "implementation_commit": implementation.get("commit"),
        "entrypoint_path": entrypoint_path,
        "entrypoint_symbol": implementation.get("entrypoint_symbol"),
        "result_contract_path": result_contract_path,
        "reference_policy": policy.get("reference_policy_id"),
        "admissible_reference_seam": admissible,
        "checks": checks,
    }
    if not admissible:
        failed = [name for name, passed in checks.items() if not passed]
        result["failure"] = "reference_seam_contract_invalid"
        result["failed_checks"] = failed
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a SWAP5/B2 reference-seam contract.")
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--contract", type=Path, required=True)
    args = parser.parse_args()
    result = assess_contract(args.repo_root, args.contract)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["admissible_reference_seam"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
