#!/usr/bin/env python3
"""Validate a canonical SWAP5/B2 reference result record.

The validator checks structural/transactional consistency and independently
recomputes the unrounded mass residual. It does not apply a universal mass
acceptance tolerance; tolerance qualification remains a separate VQ decision.
"""
from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path
from typing import Any, Iterable

CONTRACT_ID = "SWAP5-B2-reference-result-record-v1"
RESULT_CONTRACT_VERSION = "v1"

REQUIRED_DIAGNOSTICS = {
    "accepted",
    "execution_class",
    "retry_count",
    "solver_iterations",
    "solver_cost",
    "fallback_used",
    "balance_residual",
}


def _valid_sha(value: object) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None


def _finite_number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value))


def _finite_value(value: object) -> bool:
    if _finite_number(value):
        return True
    return isinstance(value, list) and all(_finite_number(item) for item in value)


def _unique_nonempty(items: Iterable[object]) -> bool:
    values = list(items)
    return all(isinstance(item, str) and bool(item.strip()) for item in values) and len(values) == len(set(values))


def _same_interval(a: object, b: object) -> bool:
    return isinstance(a, dict) and isinstance(b, dict) and a.get("t0") == b.get("t0") and a.get("t1") == b.get("t1")


def assess_record(record_path: Path) -> dict[str, Any]:
    try:
        data = json.loads(record_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {
            "record": str(record_path),
            "valid_reference_result": False,
            "checks": {"record_readable": False},
            "failure": "reference_result_record_unreadable",
            "detail": str(exc),
        }

    interval = data.get("interval", {})
    endpoint = data.get("endpoint_state", {})
    results = data.get("results", [])
    mass = data.get("mass_accounting", {})
    transaction = data.get("transaction", {})
    diagnostics = data.get("diagnostics", {})
    provenance = data.get("provenance", {})

    checks: dict[str, bool] = {}
    checks["schema_version"] = data.get("schema_version") == 1
    checks["contract_id"] = data.get("contract_id") == CONTRACT_ID
    checks["interval_t0_present"] = isinstance(interval, dict) and "t0" in interval
    checks["interval_t1_present"] = isinstance(interval, dict) and "t1" in interval

    variables = endpoint.get("variables") if isinstance(endpoint, dict) else None
    checks["endpoint_committed"] = endpoint.get("scope") == "committed" if isinstance(endpoint, dict) else False
    checks["endpoint_state_id"] = isinstance(endpoint.get("state_id"), (str, int)) if isinstance(endpoint, dict) else False
    checks["endpoint_variables_array"] = isinstance(variables, list)
    if isinstance(variables, list):
        checks["endpoint_variable_ids_unique"] = _unique_nonempty(
            item.get("variable_id") if isinstance(item, dict) else None for item in variables
        )
        checks["endpoint_values_finite"] = all(
            isinstance(item, dict)
            and _finite_value(item.get("value"))
            and isinstance(item.get("unit"), str)
            and bool(item.get("unit", "").strip())
            for item in variables
        )
    else:
        checks["endpoint_variable_ids_unique"] = False
        checks["endpoint_values_finite"] = False

    checks["results_array"] = isinstance(results, list)
    if isinstance(results, list):
        checks["result_ids_unique"] = _unique_nonempty(
            item.get("result_id") if isinstance(item, dict) else None for item in results
        )
        checks["result_values_finite"] = all(
            isinstance(item, dict)
            and _finite_value(item.get("value"))
            and isinstance(item.get("unit"), str)
            and bool(item.get("unit", "").strip())
            and isinstance(item.get("basis"), str)
            and bool(item.get("basis", "").strip())
            for item in results
        )
    else:
        checks["result_ids_unique"] = False
        checks["result_values_finite"] = False

    checks["transaction_accepted"] = transaction.get("accepted") is True if isinstance(transaction, dict) else False
    accepted_trial_id = transaction.get("accepted_trial_id") if isinstance(transaction, dict) else None
    checks["accepted_trial_id_present"] = isinstance(accepted_trial_id, (str, int))
    trial_count = transaction.get("trial_count") if isinstance(transaction, dict) else None
    retry_count = transaction.get("retry_count") if isinstance(transaction, dict) else None
    commit_count = transaction.get("commit_count") if isinstance(transaction, dict) else None
    rollback_count = transaction.get("rollback_count") if isinstance(transaction, dict) else None
    checks["trial_count"] = isinstance(trial_count, int) and not isinstance(trial_count, bool) and trial_count >= 1
    checks["retry_count"] = isinstance(retry_count, int) and not isinstance(retry_count, bool) and retry_count >= 0
    checks["commit_count_exactly_one"] = commit_count == 1
    checks["rollback_count"] = isinstance(rollback_count, int) and not isinstance(rollback_count, bool) and rollback_count >= 0
    checks["retry_count_matches_trials"] = bool(
        checks["trial_count"] and checks["retry_count"] and retry_count == trial_count - 1
    )
    checks["rollback_count_matches_retries"] = bool(
        checks["rollback_count"] and checks["retry_count"] and rollback_count == retry_count
    )
    checks["rejected_trials_excluded"] = (
        transaction.get("rejected_trials_excluded_from_committed_totals") is True
        if isinstance(transaction, dict)
        else False
    )

    storage = mass.get("storage", {}) if isinstance(mass, dict) else {}
    boundary_terms = mass.get("boundary_terms", []) if isinstance(mass, dict) else []
    start_total = storage.get("start_total") if isinstance(storage, dict) else None
    end_total = storage.get("end_total") if isinstance(storage, dict) else None
    checks["mass_scope_committed"] = mass.get("accounting_scope") == "committed" if isinstance(mass, dict) else False
    checks["mass_interval_matches_result"] = _same_interval(interval, mass.get("interval") if isinstance(mass, dict) else None)
    checks["mass_storage_finite"] = _finite_number(start_total) and _finite_number(end_total)
    checks["mass_boundary_terms_array"] = isinstance(boundary_terms, list)
    if isinstance(boundary_terms, list):
        checks["mass_term_ids_unique"] = _unique_nonempty(
            item.get("term_id") if isinstance(item, dict) else None for item in boundary_terms
        )
        checks["mass_boundary_terms_finite"] = all(
            isinstance(item, dict)
            and isinstance(item.get("interface_id"), str)
            and bool(item.get("interface_id", "").strip())
            and item.get("classification") in {"external", "internal_diagnostic"}
            and _finite_number(item.get("signed_amount"))
            for item in boundary_terms
        )
    else:
        checks["mass_term_ids_unique"] = False
        checks["mass_boundary_terms_finite"] = False

    checks["mass_accepted_trial_matches"] = (
        mass.get("accepted_trial_id") == accepted_trial_id if isinstance(mass, dict) else False
    )

    recomputed_residual: float | None = None
    if checks["mass_storage_finite"] and checks["mass_boundary_terms_finite"]:
        delta_storage = float(end_total) - float(start_total)
        net_external = sum(
            float(item["signed_amount"])
            for item in boundary_terms
            if item.get("classification") == "external"
        )
        recomputed_residual = delta_storage - net_external
    checks["mass_residual_recomputable"] = recomputed_residual is not None and math.isfinite(recomputed_residual)

    required_diag_present = isinstance(diagnostics, dict) and REQUIRED_DIAGNOSTICS.issubset(diagnostics)
    checks["diagnostics_fields"] = required_diag_present
    checks["diagnostics_accepted_matches"] = diagnostics.get("accepted") is True if isinstance(diagnostics, dict) else False
    checks["diagnostics_retry_matches"] = diagnostics.get("retry_count") == retry_count if isinstance(diagnostics, dict) else False
    checks["diagnostics_execution_matches_mass"] = (
        diagnostics.get("execution_class") == mass.get("execution_class")
        if isinstance(diagnostics, dict) and isinstance(mass, dict)
        else False
    )
    checks["diagnostics_numeric_finite"] = bool(
        isinstance(diagnostics, dict)
        and isinstance(diagnostics.get("solver_iterations"), int)
        and not isinstance(diagnostics.get("solver_iterations"), bool)
        and diagnostics.get("solver_iterations", -1) >= 0
        and _finite_number(diagnostics.get("solver_cost"))
        and float(diagnostics.get("solver_cost", -1)) >= 0.0
        and isinstance(diagnostics.get("fallback_used"), bool)
        and _finite_number(diagnostics.get("balance_residual"))
    )
    if recomputed_residual is not None and _finite_number(diagnostics.get("balance_residual") if isinstance(diagnostics, dict) else None):
        checks["diagnostic_residual_matches_recomputed"] = math.isclose(
            float(diagnostics["balance_residual"]),
            recomputed_residual,
            rel_tol=1.0e-12,
            abs_tol=1.0e-12,
        )
    else:
        checks["diagnostic_residual_matches_recomputed"] = False

    checks["provenance_commit"] = _valid_sha(provenance.get("implementation_commit")) if isinstance(provenance, dict) else False
    checks["provenance_policy"] = isinstance(provenance.get("numerical_policy"), str) and bool(provenance.get("numerical_policy", "").strip()) if isinstance(provenance, dict) else False
    checks["provenance_contract_version"] = provenance.get("result_contract_version") == RESULT_CONTRACT_VERSION if isinstance(provenance, dict) else False
    checks["provenance_case_id"] = isinstance(provenance.get("case_id"), (str, int)) if isinstance(provenance, dict) else False

    valid = all(checks.values())
    result: dict[str, Any] = {
        "record": str(record_path),
        "valid_reference_result": valid,
        "checks": checks,
        "recomputed_mass_residual": recomputed_residual,
        "mass_tolerance_applied": False,
    }
    if not valid:
        result["failure"] = "reference_result_record_invalid"
        result["failed_checks"] = [name for name, passed in checks.items() if not passed]
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a canonical SWAP5/B2 reference result record.")
    parser.add_argument("--record", type=Path, required=True)
    args = parser.parse_args()
    result = assess_record(args.record)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["valid_reference_result"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
