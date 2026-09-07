#!/usr/bin/env python3
import json
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[2]
source_path = root / "src/kernel/mod_kernel_transactions.f90"
test_path = root / "tests/fkt/test_fkt04_temporal_provenance.f90"
contract_path = root / "integration/f-kt/F-KT04_TEMPORAL_PROVENANCE_CONTRACT.json"

source = source_path.read_text(encoding="utf-8")
test = test_path.read_text(encoding="utf-8")
contract = json.loads(contract_path.read_text(encoding="utf-8"))
errors = []

required_source = [
    "real(real64) :: committed_time_value = 0.0_real64",
    "logical :: time_bound = .false.",
    "procedure, public :: current_time => kernel_current_time",
    "procedure, public :: time_is_bound => kernel_time_is_bound",
    "integer, parameter, public :: KERNEL_STATUS_TIME_MISMATCH = 103",
    "integer, parameter, public :: KERNEL_COMMIT_STATUS_TIME_MISMATCH = 5",
    "if (committed_state%time_bound .and. .not. same_time_value(t0, committed_state%committed_time_value)) then",
    "committed_state%committed_time_value = candidate_state%origin_t1",
    "committed_state%time_bound = .true.",
    "diagnostics%time_origin_rejections = 1",
    "logical function same_time_value(a, b) result(matches)",
    "ieee_is_finite(t0)",
    "ieee_is_finite(t1)",
]
for fragment in required_source:
    if fragment.lower() not in source.lower():
        errors.append(f"missing source fragment: {fragment}")

for forbidden in [
    "use mod_soil_water_solver_contract",
    "use mod_reference_richards_workspace",
    "use mod_reference_richards_legacy_binding",
    "86400",
    "midnight",
    "calendar",
]:
    if forbidden.lower() in source.lower():
        errors.append(f"forbidden coupling/time assumption in kernel source: {forbidden}")

for pattern, label in [
    (r"\bsave\b", "SAVE state"),
    (r"\bopen\s*\(", "file OPEN"),
    (r"\bread\s*\(", "file READ"),
    (r"\bwrite\s*\(", "file/output WRITE"),
]:
    if re.search(pattern, source, flags=re.IGNORECASE):
        errors.append(f"kernel source contains forbidden {label}")

for path, text in [(source_path, source), (test_path, test)]:
    for line_no, line in enumerate(text.splitlines(), start=1):
        if len(line) > 132:
            errors.append(f"Fortran line exceeds 132 chars: {path.name}:{line_no}:{len(line)}")

carrier = contract.get("committed_carrier", {})
for key in [
    "explicit_initial_time_must_be_finite",
    "unbound_initial_state_allowed",
    "first_successful_commit_binds_time",
    "successful_commit_sets_time_to_candidate_t1",
    "successful_commit_increments_revision_once",
]:
    if carrier.get(key) is not True:
        errors.append(f"committed carrier rule not locked true: {key}")
if carrier.get("time_field_visibility") != "private":
    errors.append("committed time field is not private")

rules = contract.get("continuation_rules", {})
for key in [
    "bound_state_requires_next_t0_equal_committed_time",
    "overlap_rejected",
    "gap_rejected",
    "backward_continuation_rejected",
    "nonfinite_interval_rejected",
    "time_origin_rejection_happens_before_model_execution",
    "machine_roundoff_equivalent_time_is_accepted",
    "comparison_is_representation_level_not_solver_policy",
]:
    if rules.get(key) is not True:
        errors.append(f"continuation rule not locked true: {key}")
for key in ["calendar_boundary_required", "midnight_required", "day_length_assumed"]:
    if rules.get(key) is not False:
        errors.append(f"generic time rule not locked false: {key}")

compat = contract.get("compatibility", {})
for key in ["raw_transaction_state_entrypoint_reintroduced", "fsi_solver_types_imported", "numerical_acceptance_policy_changed", "physical_model_changed"]:
    if compat.get(key) is not False:
        errors.append(f"compatibility boundary not locked false: {key}")

holds = contract.get("preserved_holds", [])
if not any("temporal-limit profile" in hold and "fail-closed" in hold for hold in holds):
    errors.append("B1.10 fail-closed temporal hold is missing")
if not any("checkpoint" in hold.lower() for hold in holds):
    errors.append("future explicit checkpoint slice is not recorded")

expected_invariants = {"1", "2", "3", "4", "5", "7", "8", "9", "10", "11", "13", "16", "20", "22", "23", "25", "26", "28", "29"}
actual = set(contract.get("invariant_assessment", {}))
if not expected_invariants.issubset(actual):
    errors.append(f"missing invariant assessments: {sorted(expected_invariants - actual)}")

if errors:
    for error in errors:
        print(f"FKT04_CONTRACT_GATE FAIL: {error}", file=sys.stderr)
    sys.exit(1)

print("FKT04_CONTRACT_GATE PASS")
