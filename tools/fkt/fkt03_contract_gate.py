#!/usr/bin/env python3
import json
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[2]
source_path = root / "src/kernel/mod_kernel_transactions.f90"
test_path = root / "tests/fkt/test_fkt03_opaque_transaction_carriers.f90"
contract_path = root / "integration/f-kt/F-KT03_OPAQUE_TRANSACTION_CARRIER_CONTRACT.json"

source = source_path.read_text(encoding="utf-8")
test = test_path.read_text(encoding="utf-8")
contract = json.loads(contract_path.read_text(encoding="utf-8"))
errors = []

required = [
    "type, extends(transaction_state_t), public :: kernel_committed_state_t",
    "type, public :: kernel_candidate_state_t\n    private",
    "type(kernel_committed_state_t), intent(in) :: committed_state",
    "type(kernel_committed_state_t), intent(inout) :: committed_state",
    "procedure, public :: snapshot => kernel_snapshot_candidate",
    "procedure, public :: current_lineage_id => kernel_candidate_lineage_id",
    "procedure, public :: origin_revision => kernel_candidate_origin_revision",
    "procedure, public :: origin_interval => kernel_candidate_origin_interval",
    "call committed_state%physical_state%clone(working)",
    "candidate_state%origin_lineage_id_value = committed_state%lineage_id",
    "candidate_state%origin_revision_value = committed_state%revision",
]
for fragment in required:
    if fragment.lower() not in source.lower():
        errors.append(f"missing source fragment: {fragment}")

for forbidden in [
    "class(transaction_state_t), allocatable, intent(in) :: committed_state",
    "class(transaction_state_t), allocatable, intent(inout) :: committed_state",
    "use mod_soil_water_solver_contract",
    "use mod_reference_richards_workspace",
    "select type (committed => committed_state)",
]:
    if forbidden.lower() in source.lower():
        errors.append(f"forbidden broad/solver coupling remains: {forbidden}")

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
        errors.append(f"solver-internal declaration leaked at source line {line_no}")

for path, text in [(source_path, source), (test_path, test)]:
    for line_no, line in enumerate(text.splitlines(), start=1):
        if len(line) > 132:
            errors.append(f"Fortran line exceeds 132 chars: {path.name}:{line_no}:{len(line)}")

api = contract.get("canonical_api", {})
if api.get("advance_committed_argument") != "type(kernel_committed_state_t), intent(in)":
    errors.append("advance argument is not explicitly typed committed carrier")
if api.get("commit_committed_argument") != "type(kernel_committed_state_t), intent(inout)":
    errors.append("commit argument is not explicitly typed committed carrier")
if api.get("raw_transaction_state_accepted_by_canonical_entrypoint") is not False:
    errors.append("raw transaction state remains admitted")
if api.get("second_production_entrypoint_created") is not False:
    errors.append("contract allows second production entrypoint")

visibility = contract.get("carrier_visibility", {})
if any(value != "private" for value in visibility.values()):
    errors.append("transaction carrier field is not contractually private")

rules = contract.get("transaction_rules", {})
for key in [
    "candidate_provenance_written_only_by_fkt",
    "stale_commit_rejected",
    "cross_lineage_commit_rejected",
    "successful_commit_increments_revision_once",
    "physical_trial_origin_is_committed_snapshot",
]:
    if rules.get(key) is not True:
        errors.append(f"transaction rule not locked true: {key}")
for key in ["caller_can_forge_candidate_lineage_or_revision", "rejected_commit_consumes_candidate", "rollback_changes_committed_revision"]:
    if rules.get(key) is not False:
        errors.append(f"transaction rule not locked false: {key}")

fsi = contract.get("fsi_boundary", {})
if fsi.get("fkt_imports_fsi_solver_types") is not False:
    errors.append("F-KT is allowed to import F-SI solver types")
if fsi.get("mapping_owner") != "F-SI adapter or model implementation":
    errors.append("F-SI state mapping ownership is not explicit")
if fsi.get("solver_may_commit_or_rollback") is not False:
    errors.append("solver is allowed transaction authority")

holds = contract.get("preserved_holds", [])
if not any("temporal-limit profile" in hold and "fail-closed" in hold for hold in holds):
    errors.append("B1.10 fail-closed temporal hold is missing")

expected_invariants = {"1", "2", "3", "4", "5", "7", "8", "9", "11", "13", "20", "22", "23", "25", "26", "29"}
actual = set(contract.get("invariant_assessment", {}))
if not expected_invariants.issubset(actual):
    errors.append(f"missing invariant assessments: {sorted(expected_invariants - actual)}")

if errors:
    for error in errors:
        print(f"FKT03_CONTRACT_GATE FAIL: {error}", file=sys.stderr)
    sys.exit(1)

print("FKT03_CONTRACT_GATE PASS")
