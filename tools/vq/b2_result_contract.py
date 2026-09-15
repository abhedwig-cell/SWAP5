#!/usr/bin/env python3
"""Validate the semantic contract for canonical SWAP5/B2 reference results.

Verification infrastructure only. The contract describes what a production
reference result must expose to VQ. It does not prescribe the internal SWAP5
object layout or serialization used by production code.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

CONTRACT_ID = "SWAP5-B2-reference-result-v1"
CANONICAL_RECORD_SCHEMA = "tools/vq/contracts/b2-reference-result-record.schema.json"
MASS_RECORD_SCHEMA = "tools/vq/contracts/mass-accounting-record.schema.json"
RESULT_CONTRACT_VERSION = "v1"

REQUIRED_TRANSACTION_FIELDS = {
    "accepted",
    "accepted_trial_id",
    "trial_count",
    "retry_count",
    "commit_count",
    "rollback_count",
}
REQUIRED_DIAGNOSTICS = {
    "accepted",
    "execution_class",
    "retry_count",
    "solver_iterations",
    "solver_cost",
    "fallback_used",
    "balance_residual",
}
REQUIRED_PROVENANCE = {
    "implementation_commit",
    "numerical_policy",
    "result_contract_version",
    "case_id",
}


def _valid_sha(value: object) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None


def _is_nonempty(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _contains_required(value: object, required: set[str]) -> bool:
    return isinstance(value, list) and required.issubset(set(value))


def assess_contract(repo_root: Path, contract_path: Path) -> dict[str, Any]:
    try:
        data = json.loads(contract_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {
            "contract": str(contract_path),
            "admissible_result_contract": False,
            "checks": {"contract_readable": False},
            "failure": "reference_result_contract_unreadable",
            "detail": str(exc),
        }

    implementation = data.get("implementation", {})
    interval = data.get("interval", {})
    endpoint = data.get("endpoint_state", {})
    values = data.get("result_values", {})
    mass = data.get("mass_accounting", {})
    transaction = data.get("transaction", {})
    diagnostics = data.get("diagnostics", {})
    provenance = data.get("provenance", {})
    execution = data.get("execution_class_semantics", {})

    checks: dict[str, bool] = {}
    checks["schema_version"] = data.get("schema_version") == 1
    checks["contract_id"] = data.get("contract_id") == CONTRACT_ID
    checks["implementation_commit"] = _valid_sha(implementation.get("commit"))

    record_schema = implementation.get("canonical_record_schema")
    mass_schema = mass.get("record_schema")
    checks["canonical_record_schema_declared"] = record_schema == CANONICAL_RECORD_SCHEMA
    checks["canonical_record_schema_exists"] = bool(
        checks["canonical_record_schema_declared"] and (repo_root / str(record_schema)).is_file()
    )
    checks["mass_record_schema_declared"] = mass_schema == MASS_RECORD_SCHEMA
    checks["mass_record_schema_exists"] = bool(
        checks["mass_record_schema_declared"] and (repo_root / str(mass_schema)).is_file()
    )

    checks["interval_t0_explicit"] = interval.get("t0_explicit") is True
    checks["interval_t1_explicit"] = interval.get("t1_explicit") is True
    checks["generic_interval"] = interval.get("generic_t0_t1") is True
    checks["calendar_boundary_not_required"] = interval.get("calendar_boundary_required") is False
    checks["returned_interval_matches_request"] = interval.get("returned_interval_matches_request") is True

    checks["endpoint_state_explicit"] = endpoint.get("explicit") is True
    checks["endpoint_state_committed_only"] = endpoint.get("committed_only") is True
    checks["rejected_endpoint_cannot_replace_committed"] = (
        endpoint.get("rejected_trial_endpoint_can_replace_committed") is False
    )
    checks["endpoint_state_stable_variable_ids"] = endpoint.get("stable_variable_ids") is True

    checks["result_values_stable_ids"] = values.get("stable_result_ids") is True
    checks["result_values_units_explicit"] = values.get("units_explicit") is True
    checks["result_values_unrounded"] = values.get("unrounded") is True
    checks["rejected_trial_results_excluded"] = values.get("rejected_trials_excluded") is True
    checks["retry_accounting_exactly_once"] = values.get("retry_totals_exactly_once") is True

    checks["mass_start_end_unrounded"] = mass.get("start_end_storage_unrounded") is True
    checks["mass_external_terms_unrounded"] = mass.get("signed_external_terms_unrounded") is True
    checks["mass_residual_recomputed_by_vq"] = mass.get("residual_recomputed_by_vq") is True
    checks["reported_mass_residual_diagnostic_only"] = mass.get("reported_residual_diagnostic_only") is True
    checks["rounded_mass_acceptance_forbidden"] = mass.get("rounded_acceptance_allowed") is False
    checks["mass_identity"] = mass.get("identity") == "delta_storage_minus_net_external"

    checks["transaction_fields"] = _contains_required(
        transaction.get("required_fields"), REQUIRED_TRANSACTION_FIELDS
    )
    checks["exactly_one_commit_for_accepted"] = transaction.get("exactly_one_commit_for_accepted") is True
    checks["rejected_trials_excluded_from_committed_totals"] = (
        transaction.get("rejected_trials_excluded_from_committed_totals") is True
    )
    checks["retry_history_diagnostic_only"] = transaction.get("retry_history_diagnostic_only") is True

    checks["diagnostics_fields"] = _contains_required(
        diagnostics.get("required_fields"), REQUIRED_DIAGNOSTICS
    )
    checks["diagnostics_do_not_define_physics"] = diagnostics.get("defines_physical_result") is False

    checks["provenance_fields"] = _contains_required(
        provenance.get("required_fields"), REQUIRED_PROVENANCE
    )
    checks["provenance_commit_bound"] = provenance.get("implementation_commit_bound_to_result") is True
    checks["provenance_policy_bound"] = provenance.get("numerical_policy_bound_to_result") is True
    checks["result_contract_version"] = provenance.get("result_contract_version") == RESULT_CONTRACT_VERSION

    checks["execution_classes_same_schema"] = execution.get("same_physical_result_schema") is True
    checks["execution_classes_same_mass_identity"] = execution.get("same_mass_identity") is True
    checks["execution_policy_does_not_change_physics"] = execution.get("policy_changes_physics") is False

    admissible = all(checks.values())
    result: dict[str, Any] = {
        "contract": str(contract_path),
        "contract_id": data.get("contract_id"),
        "implementation_commit": implementation.get("commit"),
        "canonical_record_schema": record_schema,
        "mass_record_schema": mass_schema,
        "result_contract_version": provenance.get("result_contract_version"),
        "admissible_result_contract": admissible,
        "checks": checks,
    }
    if not admissible:
        result["failure"] = "reference_result_contract_invalid"
        result["failed_checks"] = [name for name, passed in checks.items() if not passed]
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a SWAP5/B2 reference-result contract.")
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--contract", type=Path, required=True)
    args = parser.parse_args()
    result = assess_contract(args.repo_root, args.contract)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["admissible_result_contract"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
