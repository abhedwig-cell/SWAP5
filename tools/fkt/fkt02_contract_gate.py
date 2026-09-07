#!/usr/bin/env python3
import json
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[2]
source_path = root / "src/kernel/mod_kernel_transactions.f90"
contract_path = root / "integration/f-kt/F-KT02_CANDIDATE_LINEAGE_CONTRACT.json"
fsi_path = root / "integration/f-kt/F-KT01_FSI_BOUNDARY.json"

source = source_path.read_text(encoding="utf-8")
source_lower = source.lower()
contract = json.loads(contract_path.read_text(encoding="utf-8"))
fsi = json.loads(fsi_path.read_text(encoding="utf-8"))
errors = []

required_source_fragments = [
    "type, extends(transaction_state_t), public :: kernel_committed_state_t",
    "class(transaction_state_t), allocatable :: physical_state",
    "integer(int64) :: lineage_id",
    "integer(int64) :: revision",
    "integer(int64) :: origin_lineage_id",
    "integer(int64) :: origin_revision",
    "procedure, public :: advance_interval => kernel_advance_interval",
    "procedure, public :: commit_candidate => kernel_commit_candidate",
    "procedure, public :: rollback_candidate => kernel_rollback_candidate",
    "class(transaction_state_t), allocatable, intent(in) :: committed_state",
    "result%status = kernel_status_unguarded_state",
    "candidate_state%origin_lineage_id = origin_lineage_id",
    "candidate_state%origin_revision = origin_revision",
    "candidate_state%origin_lineage_id /= committed%lineage_id",
    "candidate_state%origin_revision /= committed%revision",
    "committed%revision = committed%revision + 1_int64",
    "call committed%physical_state%clone(working)",
    "call move_alloc(candidate_state%state, committed%physical_state)",
]
for fragment in required_source_fragments:
    if fragment.lower() not in source_lower:
        errors.append(f"missing source contract fragment: {fragment}")

for pattern, label in [
    (r"\bsave\b", "SAVE state"),
    (r"\bopen\s*\(", "file OPEN"),
    (r"\bread\s*\(", "file READ"),
    (r"\bwrite\s*\(", "file/output WRITE"),
]:
    if re.search(pattern, source, flags=re.IGNORECASE):
        errors.append(f"kernel source contains forbidden {label}")

for line_no, line in enumerate(source.splitlines(), start=1):
    if "::" in line and re.search(r"\b(headcalc|newton|jacobian)\b", line, flags=re.IGNORECASE):
        errors.append(f"solver-internal declaration leaked into kernel contract at line {line_no}")

api = contract.get("canonical_api", {})
if api.get("production_execution_entrypoint") != "kernel_executor_t%advance_interval":
    errors.append("canonical production execution entrypoint changed")
if api.get("no_second_execution_entrypoint") is not True:
    errors.append("contract does not forbid a second execution entrypoint")
if api.get("committed_state_carrier") != "kernel_committed_state_t":
    errors.append("guarded committed-state carrier not canonical")

lineage = contract.get("lineage_contract", {})
if lineage.get("kernel_generates_global_lineage_ids") is not False:
    errors.append("kernel is allowed to generate hidden global lineage ids")
if lineage.get("revision_owner") != "F-KT kernel transaction layer":
    errors.append("revision ownership is not F-KT")
if lineage.get("initial_revision") != 0:
    errors.append("initial committed revision is not zero")
if lineage.get("advance_changes_revision") is not False:
    errors.append("advance is allowed to mutate committed revision")
if lineage.get("rollback_changes_revision") is not False:
    errors.append("rollback is allowed to mutate committed revision")

candidate = contract.get("candidate_provenance", {})
for key in [
    "records_origin_lineage_id",
    "records_origin_revision",
    "successful_commit_requires_lineage_match",
    "successful_commit_requires_revision_match",
    "successful_commit_consumes_candidate",
]:
    if candidate.get(key) is not True:
        errors.append(f"candidate provenance requirement missing: {key}")
if candidate.get("rejected_commit_consumes_candidate") is not False:
    errors.append("rejected commit may consume candidate")

unguarded = contract.get("unguarded_state_policy", {})
if unguarded.get("behavior") != "fail_closed":
    errors.append("raw unguarded state does not fail closed")

if contract.get("time_and_mass", {}).get("generic_t0_t1_unchanged") is not True:
    errors.append("generic t0/t1 is not preserved")
if contract.get("time_and_mass", {}).get("hard_unrounded_mass_gate_unchanged") is not True:
    errors.append("hard unrounded mass gate is not preserved")
if contract.get("time_and_mass", {}).get("new_temporal_tolerances_introduced") is not False:
    errors.append("F-KT02 introduced temporal tolerances")

reference = contract.get("reference_admission", {})
if reference.get("b1_10_reference_execution_newly_admitted") is not False:
    errors.append("F-KT02 incorrectly admits B1.10 reference execution")
if reference.get("missing_vq_temporal_profile_still_fail_closed") is not True:
    errors.append("missing VQ temporal profile no longer fails closed")
if reference.get("kernel_invents_temporal_limits") is not False:
    errors.append("kernel may invent temporal limits")

fsi_contract = contract.get("fsi_boundary", {})
if fsi_contract.get("changed") is not False:
    errors.append("F-KT02 unexpectedly changes F-SI boundary")
if fsi_contract.get("solver_internal_arrays_added_to_kernel_state") is not False:
    errors.append("solver internal arrays admitted into kernel state")
if fsi.get("owner_of_boundary_contract") != "F-KT" or fsi.get("consumer") != "F-SI":
    errors.append("persisted F-KT/F-SI boundary ownership changed")

expected_invariants = {
    "1", "2", "3", "4", "5", "7", "8", "9", "11", "13", "16", "20", "22", "23", "25", "26", "28", "29"
}
actual_invariants = set(contract.get("invariant_assessment", {}))
if not expected_invariants.issubset(actual_invariants):
    errors.append(f"missing invariant assessments: {sorted(expected_invariants - actual_invariants)}")

if errors:
    for error in errors:
        print(f"FKT02_CONTRACT_GATE FAIL: {error}", file=sys.stderr)
    sys.exit(1)

print("FKT02_CONTRACT_GATE PASS")
