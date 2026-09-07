#!/usr/bin/env python3
import json
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[2]
source_path = root / "src/kernel/mod_kernel_transactions.f90"
contract_path = root / "integration/f-kt/F-KT01_KERNEL_TRANSACTION_CONTRACT.json"
fsi_path = root / "integration/f-kt/F-KT01_FSI_BOUNDARY.json"

errors = []
source = source_path.read_text(encoding="utf-8")
source_lower = source.lower()
contract = json.loads(contract_path.read_text(encoding="utf-8"))
fsi = json.loads(fsi_path.read_text(encoding="utf-8"))

required_source_fragments = [
    "type, abstract, public :: kernel_parameters_t",
    "type, public :: kernel_candidate_state_t",
    "type, public :: kernel_result_t",
    "type, public :: kernel_diagnostics_t",
    "type, abstract, extends(canonical_physical_model_t), public :: kernel_model_t",
    "procedure, public :: advance_interval => kernel_advance_interval",
    "procedure, public :: commit_candidate => kernel_commit_candidate",
    "procedure, public :: rollback_candidate => kernel_rollback_candidate",
    "class(transaction_state_t), allocatable, intent(in) :: committed_state",
    "class(kernel_parameters_t), intent(in) :: parameters",
    "class(canonical_forcing_t), intent(in) :: forcing",
    "type(canonical_numerical_config_t), intent(in) :: numerical_config",
    "real(real64), intent(in) :: t0, t1",
    "self%model%execution_admitted(parameters, numerical_config)",
    "call committed_state%clone(working)",
    "call move_alloc(working, candidate_state%state)",
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

# Solver names may occur in comments that define the ownership boundary, but
# they may not become public data components in the kernel contract.
for line_no, line in enumerate(source.splitlines(), start=1):
    if "::" in line and re.search(r"\b(headcalc|newton|jacobian)\b", line, flags=re.IGNORECASE):
        errors.append(f"solver-internal declaration leaked into kernel contract at line {line_no}")

api = contract.get("canonical_api", {})
if api.get("production_execution_entrypoint") != "kernel_executor_t%advance_interval":
    errors.append("canonical production execution entrypoint is not unique advance_interval")
if api.get("fci_runtime_substrate", {}).get("architectural_role") != \
        "implementation substrate, not a second canonical production entrypoint":
    errors.append("F-CI runtime substrate role is not explicitly non-competing")

categories = contract.get("data_categories", {})
for category in [
    "parameters",
    "committed_dynamic_state",
    "candidate_state",
    "forcing",
    "numerical_configuration",
    "results",
    "diagnostics",
    "worker_scratch",
]:
    if category not in categories:
        errors.append(f"missing data category {category}")

if categories.get("committed_dynamic_state", {}).get("advance_intent") != "in":
    errors.append("committed state is not declared input-only")
if categories.get("worker_scratch", {}).get("persistent_column_state") is not False:
    errors.append("worker scratch is not excluded from persistent state")
if contract.get("time_semantics", {}).get("calendar_day_fundamental") is not False:
    errors.append("calendar day incorrectly made fundamental")
if any(contract.get("io_semantics", {}).values()):
    errors.append("I/O semantics leaked into kernel contract")
if contract.get("mass_semantics", {}).get("hard_mass_conservation") is not True:
    errors.append("hard mass conservation is not locked")
if contract.get("mass_semantics", {}).get("rounding_allowed_for_acceptance") is not False:
    errors.append("rounded mass acceptance was admitted")

reference = contract.get("reference_admission", {})
if reference.get("mode") != "fail_closed":
    errors.append("reference admission is not fail-closed")
if reference.get("b1_10_temporal_limit_profile_independently_qualified") is not False:
    errors.append("missing B1.10 temporal profile was incorrectly qualified")
if reference.get("kernel_may_invent_temporal_tolerances") is not False:
    errors.append("kernel was allowed to invent temporal tolerances")
if reference.get("production_reference_execution_admitted_without_required_vq_evidence") is not False:
    errors.append("reference execution can bypass missing VQ evidence")

expected_invariants = {"1", "2", "3", "4", "5", "7", "8", "9", "11", "13", "20", "22", "23", "25", "26", "29"}
actual_invariants = set(contract.get("invariant_assessment", {}))
if not expected_invariants.issubset(actual_invariants):
    errors.append(f"missing invariant assessments: {sorted(expected_invariants - actual_invariants)}")

if fsi.get("owner_of_boundary_contract") != "F-KT" or fsi.get("consumer") != "F-SI":
    errors.append("F-KT/F-SI ownership is not explicit")
if fsi.get("integration_rule", {}).get("new_shared_soil_solver_type_required_by_fkt01") is not False:
    errors.append("F-KT01 prematurely defines an F-SI-owned soil solver type")
if fsi.get("persistent_state_contains_solver_scratch") is not False:
    errors.append("F-SI boundary permits persistent solver scratch")
if fsi.get("kernel_contract_contains_solver_internal_arrays") is not False:
    errors.append("F-SI boundary permits solver internal arrays in kernel contract")

if errors:
    for error in errors:
        print(f"FKT01_CONTRACT_GATE FAIL: {error}", file=sys.stderr)
    sys.exit(1)

print("FKT01_CONTRACT_GATE PASS")
