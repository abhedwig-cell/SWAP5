#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_SOURCE_BLOBS = {
    "src/transaction/mod_transaction_reference.f90": "b1878606ae6cb2b04a7b4b15e3e537deacf4477f",
    "src/runtime/mod_canonical_contracts.f90": "0c2b15fc45011c580384cf6a618e7b378fdccf0a",
    "src/runtime/mod_canonical_interval_runtime.f90": "f2cae79d533343db818c11e0b61b605ac5f6739d",
    "src/kernel/mod_kernel_transactions.f90": "9f7c16e71cfb93b57f796ba759bae73824318a2f",
}


def git_blob(relative: str) -> str:
    path = ROOT / relative
    return subprocess.check_output(["git", "-C", str(ROOT), "hash-object", str(path)], text=True).strip()


checks: dict[str, bool] = {}
actual: dict[str, str] = {}
for relative, expected in EXPECTED_SOURCE_BLOBS.items():
    value = git_blob(relative)
    actual[relative] = value
    checks[f"source_bound:{relative}"] = value == expected

tx = (ROOT / "src/transaction/mod_transaction_reference.f90").read_text(encoding="utf-8")
contracts = (ROOT / "src/runtime/mod_canonical_contracts.f90").read_text(encoding="utf-8")
runtime = (ROOT / "src/runtime/mod_canonical_interval_runtime.f90").read_text(encoding="utf-8")
kernel = (ROOT / "src/kernel/mod_kernel_transactions.f90").read_text(encoding="utf-8")
contract = json.loads((ROOT / "integration/f-kt/F-KT08_MASS_ACCOUNTING_CONTRACT.json").read_text())

checks.update({
    "existing_canonical_mass_type_extended": "type, public :: canonical_mass_accounting_t" in contracts,
    "explicit_interval_provenance": all(x in contracts for x in ("interval_t0", "interval_t1", "origin_lineage_id", "origin_revision")),
    "explicit_storage_terms": all(x in contracts for x in ("storage_start", "storage_end", "storage_change")),
    "explicit_external_totals": "total_in" in contracts and "total_out" in contracts,
    "explicit_unrounded_residual": "real(real64) :: residual" in contracts,
    "compact_missing_mask": "integer(int64) :: missing_contribution_mask" in contracts,
    "trial_completeness_fail_closed": "logical :: mass_accounting_complete = .false." in tx,
    "trial_missing_mask_fail_closed": "missing_mass_contribution_mask = TX_MASS_MISSING_UNSPECIFIED" in tx,
    "storage_completeness_default_fail_closed": "complete = .false." in tx and "missing_mask = TX_MASS_MISSING_UNSPECIFIED" in tx,
    "accepted_route_only_mass": all(x in tx for x in ("half1_outcome%mass_in + half2_outcome%mass_in", "half1_outcome%mass_out + half2_outcome%mass_out")),
    "rejected_full_trial_not_accepted_total": "full_outcome%mass_in +" not in tx and "full_outcome%mass_out +" not in tx,
    "canonical_accumulates_accepted_only": "call accumulate_accepted_mass(result, tx" in runtime and "tx%accepted_total_in" in runtime,
    "canonical_residual_from_terms": "result%mass%storage_change - &" in runtime and "result%mass%total_in - result%mass%total_out" in runtime,
    "canonical_nonfinite_fail_closed": "TX_MASS_MISSING_NONFINITE" in runtime and "ieee_is_finite" in runtime,
    "candidate_carries_mass": "candidate_state%mass = result%mass" in kernel,
    "kernel_stamps_lineage_revision": "result%mass%origin_lineage_id = committed_state%lineage_id" in kernel and "result%mass%origin_revision = committed_state%revision" in kernel,
    "commit_publishes_mass_after_validation": kernel.find("accepted_mass = candidate_state%mass") > kernel.find("origin_revision_value /= committed_state%revision"),
    "candidate_clear_drops_mass": "candidate_state%mass = canonical_mass_accounting_t()" in kernel,
    "no_cumulative_mass_in_committed_state": "type(canonical_mass_accounting_t) :: mass" not in kernel.split("end type kernel_committed_state_t")[0],
    "no_file_io_added": not any(re.search(rf"\b{word}\s*\(", text.lower()) for text in (tx, contracts, runtime, kernel) for word in ("open", "read", "write")),
    "no_solver_internal_leak": not any(token in contracts.lower() for token in ("headcalc", "jacobian", "newton", "workspace")),
    "no_mass_disable_switch": "mass conservation off" not in (tx + contracts + runtime + kernel).lower(),
    "contract_no_second_mass_model": contract["no_second_mass_model"] is True,
    "contract_new_tolerance_false": contract["scientific_policy"]["new_tolerance"] is False,
    "contract_mass_disable_false": contract["scientific_policy"]["mass_conservation_disable_switch"] is False,
})

failed = sorted(name for name, passed in checks.items() if not passed)
print(json.dumps({
    "work_unit": "F-KT08",
    "status": "PASS" if not failed else "FAIL",
    "checks": checks,
    "actual_source_blobs": actual,
    "failed": failed,
}, indent=2, sort_keys=True))
raise SystemExit(0 if not failed else 2)
