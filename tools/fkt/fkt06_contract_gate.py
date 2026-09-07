#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = "f50b8cd20221fac27a2059b6c6192ed0b7384be8"
CONTRACT = ROOT / "integration/f-kt/F-KT06_OPTIONAL_CONTINUATION_CONTRACT.json"
KERNEL = ROOT / "src/kernel/mod_kernel_transactions.f90"

errors = []
contract = json.loads(CONTRACT.read_text())

if contract.get("work_unit") != "F-KT06":
    errors.append("wrong work unit")
if contract.get("production_source_changed") is not False:
    errors.append("F-KT06 unexpectedly claims production source change")
if contract.get("decision") != "EXISTING_OPAQUE_TRANSACTION_STATE_LIFECYCLE_IS_THE_CANONICAL_CARRIER":
    errors.append("opaque lifecycle decision not pinned")

basis = contract.get("external_basis", {})
if basis.get("fsi06_status") != "PERSISTED_CONTRACT_BEFORE_SOURCE_CHANGE":
    errors.append("F-SI06 status not pinned to persisted contract scope")
if basis.get("fsi06_consumed_as_qualification_evidence") is not False:
    errors.append("unqualified F-SI06 consumed as qualification evidence")
if basis.get("fsi06_nstep_classification") != "column_dependent_solver_process_continuation":
    errors.append("F-SI06 nstep ownership classification drifted")
if basis.get("fmq19_tested") is not False or basis.get("fmq19_qualified") is not False:
    errors.append("F-MQ19 was promoted beyond observed persisted state")
if basis.get("fvq11_consumed_as_qualification_evidence") is not False:
    errors.append("F-VQ11 consumed as F-KT06 qualification evidence")

classification = contract.get("classification_contract", {})
if classification.get("fsi06_nstep") != "must_be_in_adapter_specific_transaction_state_before_macropore_admission":
    errors.append("nstep continuation requirement missing")
if classification.get("fkt_hardcodes_nstep") is not False:
    errors.append("F-KT hard-codes nstep")
if classification.get("fkt_imports_fsi_types") is not False:
    errors.append("F-KT imports F-SI types")

lifecycle = contract.get("existing_lifecycle_contract", {})
for key in [
    "checkpoint_deep_clones_committed_continuation",
    "trial_from_checkpoint_deep_clones_checkpoint_continuation",
    "trial_without_checkpoint_deep_clones_committed_continuation",
    "accepted_runtime_state_becomes_candidate_only",
    "candidate_commit_publishes_continuation_exactly_once",
    "candidate_rollback_discards_trial_continuation",
    "failed_trial_cannot_mutate_committed_continuation",
    "stale_checkpoint_cannot_restore_old_continuation",
    "stale_candidate_cannot_publish_old_continuation",
]:
    if lifecycle.get(key) is not True:
        errors.append(f"lifecycle claim not asserted: {key}")

optional = contract.get("optional_state_scaling", {})
if optional.get("kernel_allocates_optional_process_state_for_inactive_columns") is not False:
    errors.append("kernel allocates optional process state for inactive columns")
if optional.get("inactive_route_must_not_allocate_process_continuation_during_trial_or_commit") is not True:
    errors.append("inactive optional-state scaling contract missing")

admission = contract.get("admission_boundaries", {})
for key in [
    "macropore_production_admitted_by_fkt06",
    "reference_execution_admitted_by_fkt06",
    "multiswap_production_runtime_admitted_by_fkt06",
    "full_reference_solver_reentrancy_qualified_by_fkt06",
    "full_swap_mass_identity_qualified_by_fkt06",
]:
    if admission.get(key) is not False:
        errors.append(f"admission boundary incorrectly promoted: {key}")
if admission.get("canonical_reference_admission") != "BLOCKED_FAIL_CLOSED":
    errors.append("canonical reference admission not fail-closed")

baseline_blob = subprocess.check_output(
    ["git", "rev-parse", f"{BASE}:src/kernel/mod_kernel_transactions.f90"],
    cwd=ROOT,
    text=True,
).strip()
head_blob = subprocess.check_output(
    ["git", "rev-parse", "HEAD:src/kernel/mod_kernel_transactions.f90"],
    cwd=ROOT,
    text=True,
).strip()
if baseline_blob != head_blob:
    errors.append("production kernel source changed in F-KT06")

source = KERNEL.read_text().lower()
required_snippets = [
    "call self%physical_state%clone(checkpoint%physical_state)",
    "call checkpoint%physical_state%clone(working)",
    "call committed_state%physical_state%clone(working)",
    "call move_alloc(working, candidate_state%state)",
    "call move_alloc(candidate_state%state, committed_state%physical_state)",
    "call clear_candidate(candidate_state)",
]
for snippet in required_snippets:
    if snippet not in source:
        errors.append(f"required opaque lifecycle operation missing: {snippet}")

for forbidden in ["nstep", "flwarn", "iwarn"]:
    if forbidden in source:
        errors.append(f"F-SI-owned field leaked into F-KT kernel: {forbidden}")

expected_invariants = {"1", "3", "4", "5", "7", "8", "11", "13", "16", "20", "22", "23", "25", "26", "27", "29"}
actual = set(contract.get("invariant_assessment", {}))
if not expected_invariants.issubset(actual):
    errors.append(f"missing invariant assessments: {sorted(expected_invariants-actual)}")

if errors:
    for error in errors:
        print(f"FKT06_CONTRACT_GATE FAIL: {error}", file=sys.stderr)
    sys.exit(1)

print("FKT06_CONTRACT_GATE PASS")
