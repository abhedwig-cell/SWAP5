#!/usr/bin/env python3
"""Validate a VQ binding from the qualified harness to a real B2 production seam.

Verification infrastructure only. A valid binding proves that one repository
artifact maps the VQ QualificationAdapter protocol to the already-admitted B2
reference seam without changing physics, forcing, time, numerical policy or
mass terms. It does not execute SWAP5 and therefore cannot qualify B2 physics.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

CONTRACT_ID = "SWAP5-VQ-production-adapter-binding-v1"
PROTOCOL_ID = "VQ-QualificationAdapter-v1"

REQUIRED_SEMANTICS = (
    "generic_interval_forwarded_exactly",
    "committed_state_forwarded_as_physical_start",
    "forcing_replayed_exactly_on_retry",
    "numerical_warm_start_separate",
    "accepted_result_normalized_to_vq_record",
    "transaction_trace_exposed",
    "rejected_trials_excluded_from_committed_totals",
    "commit_exactly_once",
)

REQUIRED_NON_INTERFERENCE_FALSE = (
    "changes_physics",
    "changes_numerical_policy",
    "changes_forcing",
    "changes_interval",
    "changes_mass_terms",
    "introduces_kernel_file_io",
    "introduces_hidden_calendar_boundary",
)


def _valid_sha(value: object) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None


def _nonempty(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def assess_binding(repo_root: Path, binding_path: Path) -> dict[str, Any]:
    try:
        data = json.loads(binding_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {
            "binding": str(binding_path),
            "admissible_production_adapter_binding": False,
            "checks": {"binding_readable": False},
            "failure": "production_adapter_binding_unreadable",
            "detail": str(exc),
        }

    implementation = data.get("implementation", {})
    adapter = data.get("adapter", {})
    b2_binding = data.get("b2_binding", {})
    semantics = data.get("semantics", {})
    non_interference = data.get("non_interference", {})

    checks: dict[str, bool] = {}
    checks["schema_version"] = data.get("schema_version") == 1
    checks["contract_id"] = data.get("contract_id") == CONTRACT_ID
    checks["implementation_commit"] = _valid_sha(implementation.get("commit"))
    checks["production_target"] = implementation.get("production_target") is True

    adapter_path = adapter.get("path")
    checks["adapter_path_declared"] = _nonempty(adapter_path)
    checks["adapter_path_exists"] = bool(
        checks["adapter_path_declared"] and (repo_root / str(adapter_path)).is_file()
    )
    checks["factory_symbol_declared"] = _nonempty(adapter.get("factory_symbol"))
    checks["qualification_adapter_protocol"] = (
        adapter.get("qualification_adapter_protocol") == PROTOCOL_ID
    )
    checks["not_synthetic_fixture"] = adapter.get("synthetic_fixture") is False

    entrypoint_path = b2_binding.get("entrypoint_path")
    seam_contract_path = b2_binding.get("seam_contract_path")
    result_contract_path = b2_binding.get("result_contract_path")
    checks["entrypoint_path_declared"] = _nonempty(entrypoint_path)
    checks["seam_contract_path_declared"] = _nonempty(seam_contract_path)
    checks["result_contract_path_declared"] = _nonempty(result_contract_path)
    checks["reference_policy"] = b2_binding.get("reference_policy") == "reference"
    checks["entrypoint_exists"] = bool(
        checks["entrypoint_path_declared"] and (repo_root / str(entrypoint_path)).is_file()
    )
    checks["seam_contract_exists"] = bool(
        checks["seam_contract_path_declared"] and (repo_root / str(seam_contract_path)).is_file()
    )
    checks["result_contract_exists"] = bool(
        checks["result_contract_path_declared"] and (repo_root / str(result_contract_path)).is_file()
    )

    for name in REQUIRED_SEMANTICS:
        checks[f"semantics_{name}"] = semantics.get(name) is True
    for name in REQUIRED_NON_INTERFERENCE_FALSE:
        checks[f"non_interference_{name}"] = non_interference.get(name) is False

    admissible = all(checks.values())
    result: dict[str, Any] = {
        "binding": str(binding_path),
        "contract_id": data.get("contract_id"),
        "implementation_commit": implementation.get("commit"),
        "adapter_path": adapter_path,
        "factory_symbol": adapter.get("factory_symbol"),
        "qualification_adapter_protocol": adapter.get("qualification_adapter_protocol"),
        "entrypoint_path": entrypoint_path,
        "seam_contract_path": seam_contract_path,
        "result_contract_path": result_contract_path,
        "reference_policy": b2_binding.get("reference_policy"),
        "admissible_production_adapter_binding": admissible,
        "checks": checks,
        "failed_checks": [name for name, passed in checks.items() if not passed],
    }
    if not admissible:
        result["failure"] = "production_adapter_binding_invalid"
    return result


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate a SWAP5 VQ production-adapter binding declaration."
    )
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--binding", type=Path, required=True)
    args = parser.parse_args()
    result = assess_binding(args.repo_root, args.binding)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result.get("admissible_production_adapter_binding") else 2


if __name__ == "__main__":
    raise SystemExit(main())
