#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
B1_10_MANIFEST = "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"


def main() -> int:
    checks: dict[str, bool] = {}

    contracts_path = ROOT / "src/runtime/mod_canonical_contracts.f90"
    runtime_path = ROOT / "src/runtime/mod_canonical_interval_runtime.f90"
    seam_path = ROOT / "integration/f-ci/F-CI04_PHYSICAL_SEAM_CONTRACT.json"
    snapshot_path = ROOT / "reference/swap-4.3.1/snapshots/B1.10.yml"
    forbidden_adapter = ROOT / "src/adapter/mod_a23bu_hupsel_worker_component.f90"

    for path in (contracts_path, runtime_path, seam_path, snapshot_path):
        checks[f"exists:{path.relative_to(ROOT)}"] = path.is_file()

    if not all(checks.values()):
        failed = sorted(name for name, ok in checks.items() if not ok)
        print(json.dumps({"work_unit": "F-CI04", "status": "FAIL", "checks": checks, "failed": failed}, indent=2))
        return 2

    contracts = contracts_path.read_text(encoding="utf-8")
    runtime = runtime_path.read_text(encoding="utf-8")
    seam = json.loads(seam_path.read_text(encoding="utf-8"))
    snapshot = snapshot_path.read_text(encoding="utf-8")

    checks["explicit_persistent_state_type"] = "canonical_state_t" in contracts
    checks["explicit_forcing_type"] = "canonical_forcing_t" in contracts
    checks["explicit_numerical_config_type"] = "canonical_numerical_config_t" in contracts
    checks["explicit_result_type"] = "canonical_result_t" in contracts
    checks["explicit_mass_contract_type"] = "canonical_mass_accounting_t" in contracts
    checks["physical_model_prepare_contract"] = "prepare_interval" in contracts

    checks["runtime_private_working_state"] = "allocatable :: working" in runtime
    checks["runtime_clones_external_committed_state"] = "committed%clone(working)" in runtime
    checks["runtime_external_commit_only_at_completion"] = "move_alloc(working, committed)" in runtime
    checks["runtime_continues_to_requested_t1"] = "cursor, interval%t1" in runtime
    checks["runtime_has_bounded_substeps"] = "max_committed_substeps" in runtime
    checks["runtime_does_not_fabricate_mass_complete"] = "result%mass%complete = .false." in runtime
    checks["runtime_no_file_io"] = not any(token in runtime.lower() for token in ("open(", "read(", "write("))

    checks["b1_10_manifest_pinned"] = B1_10_MANIFEST in snapshot
    checks["seam_oracle_is_b1_10"] = seam.get("oracle", {}).get("snapshot") == "B1.10"
    checks["seam_manifest_matches"] = seam.get("oracle", {}).get("source_manifest_sha256") == B1_10_MANIFEST
    checks["seam_generic_time_required"] = seam.get("runtime_semantics", {}).get("requested_interval_is_generic_t0_t1") is True
    checks["seam_atomic_interval_required"] = seam.get("runtime_semantics", {}).get("full_requested_interval_is_externally_atomic") is True
    checks["seam_full_mass_still_blocked"] = seam.get("mass_contract", {}).get("full_unrounded_interval_accounting_currently_available") is False
    checks["wholesale_a23bu_adapter_absent"] = not forbidden_adapter.exists()
    checks["integer_day_projection_forbidden"] = seam.get("physical_model_contract", {}).get("integer_day_projection_allowed_in_canonical_seam") is False

    failed = sorted(name for name, ok in checks.items() if not ok)
    result = {
        "work_unit": "F-CI04",
        "status": "PASS" if not failed else "FAIL",
        "b1_oracle": "B1.10",
        "b1_manifest_sha256": B1_10_MANIFEST,
        "checks": checks,
        "failed": failed,
        "holds": seam.get("holds", []),
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failed else 2


if __name__ == "__main__":
    raise SystemExit(main())
