#!/usr/bin/env python3
import json
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[2]
source_path = root / "src/kernel/mod_kernel_transactions.f90"
test_path = root / "tests/fkt/test_fkt05_reusable_checkpoint.f90"
contract_path = root / "integration/f-kt/F-KT05_REUSABLE_CHECKPOINT_CONTRACT.json"
source = source_path.read_text(encoding="utf-8")
test = test_path.read_text(encoding="utf-8")
contract = json.loads(contract_path.read_text(encoding="utf-8"))
errors = []

required = [
    "type, public :: kernel_checkpoint_t\n    private",
    "procedure, public :: capture_checkpoint => kernel_capture_checkpoint",
    "type(kernel_checkpoint_t), intent(in), optional :: checkpoint",
    "if (present(checkpoint)) then",
    "call checkpoint%physical_state%clone(working)",
    "logical function validate_checkpoint",
    "checkpoint%lineage_id /= committed_state%lineage_id",
    "checkpoint%revision /= committed_state%revision",
    "checkpoint%time_bound .neqv. committed_state%time_bound",
    "KERNEL_STATUS_CHECKPOINT_MISMATCH",
    "checkpoint_revision_rejections",
    "checkpoint_time_rejections",
]
for fragment in required:
    if fragment.lower() not in source.lower():
        errors.append(f"missing source fragment: {fragment}")

for forbidden in [
    "advance_from_checkpoint",
    "restore_checkpoint",
    "restore_committed",
    "use mod_soil_water_solver_contract",
    "use mod_reference_richards_workspace",
]:
    if forbidden.lower() in source.lower():
        errors.append(f"forbidden competing/solver coupling: {forbidden}")

if source.lower().count("procedure, public :: advance_interval") != 1:
    errors.append("canonical production advance_interval binding is not unique")

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
if api.get("production_entrypoint") != "kernel_executor_t%advance_interval":
    errors.append("canonical production entrypoint changed")
if api.get("second_production_entrypoint_created") is not False:
    errors.append("contract permits a second production entrypoint")
if api.get("checkpoint_argument") != "type(kernel_checkpoint_t), intent(in), optional":
    errors.append("checkpoint is not optional read-only input")

carrier = contract.get("checkpoint_carrier", {})
for key in ["persistent_column_state", "contains_solver_scratch", "contains_warm_start", "restore_committed_operation_exists", "publish_operation_exists"]:
    if carrier.get(key) is not False:
        errors.append(f"checkpoint carrier forbidden property true: {key}")
if carrier.get("fields_private") is not True:
    errors.append("checkpoint fields are not private")

rules = contract.get("transaction_rules", {})
for key in [
    "capture_never_mutates_committed",
    "checkpoint_snapshot_is_clone",
    "checkpoint_reusable_while_committed_revision_is_current",
    "checkpoint_must_match_lineage",
    "checkpoint_must_match_revision",
    "checkpoint_must_match_time_binding_and_value",
    "stale_checkpoint_fails_closed",
    "cross_lineage_checkpoint_fails_closed",
    "checkpoint_time_mismatch_fails_closed",
    "checkpoint_rejection_precedes_physical_model_execution",
    "checkpoint_cannot_restore_old_revision",
]:
    if rules.get(key) is not True:
        errors.append(f"transaction rule not locked true: {key}")

replay = contract.get("replay_rules", {})
if replay.get("same_checkpoint_and_same_committed_revision_can_be_reused") is not True:
    errors.append("same-revision checkpoint replay not guaranteed")
if replay.get("warm_start_may_change_physical_origin") is not False:
    errors.append("warm start is allowed to change physical origin")

time = contract.get("time_semantics", {})
if time.get("generic_t0_t1") is not True or time.get("day_is_fundamental_unit") is not False:
    errors.append("generic time contract regressed")
if time.get("checkpoint_adds_user_configurable_time_tolerance") is not False:
    errors.append("checkpoint introduced a numerical time tolerance")

fsi = contract.get("fsi_boundary", {})
if fsi.get("fkt_imports_fsi_solver_types") is not False:
    errors.append("F-KT imports F-SI solver types")
if fsi.get("fsi_may_commit_or_rollback") is not False:
    errors.append("F-SI gained transaction authority")
if fsi.get("fsi03_qualified_scope") != "QUALIFIED_SOURCE_BOUND_ADAPTER_CONTRACT_ONLY":
    errors.append("F-SI03 scope is not pinned exactly")
if fsi.get("fsi04_qualified_scope") != "QUALIFIED_SOURCE_BOUND_MAIN_WORKSPACE_REPLAY_ONLY":
    errors.append("F-SI04 scope is not pinned exactly")
if fsi.get("fsi04_changes_production_route") is not False:
    errors.append("F-SI04 was incorrectly treated as production route")
if fsi.get("fsi04_full_reference_solver_reentrancy_qualified") is not False:
    errors.append("F-SI04 was incorrectly treated as full reentrancy qualification")

reference = contract.get("reference_policy", {})
if reference.get("fvq10_decision") != "QUALIFIED_TEMPORAL_PROFILE_PROMOTION_CONTRACT_ONLY":
    errors.append("F-VQ10 decision not pinned exactly")
if reference.get("promotion_method_qualified") is not True:
    errors.append("qualified F-VQ10 promotion method not recognized")
for key in [
    "real_b1_10_temporal_characterization_qualified",
    "production_temporal_profile_qualified",
    "numeric_limits_introduced_by_fvq10",
    "b1_10_production_reference_admission",
]:
    if reference.get(key) is not False:
        errors.append(f"reference hold incorrectly promoted: {key}")
if reference.get("canonical_reference_admission") != "BLOCKED_FAIL_CLOSED":
    errors.append("canonical reference is not fail-closed")
if reference.get("fail_closed_hold_preserved") is not True:
    errors.append("reference fail-closed hold missing")

expected = {"1", "2", "3", "4", "5", "7", "8", "9", "11", "13", "20", "22", "23", "25", "26", "29"}
actual = set(contract.get("invariant_assessment", {}))
if not expected.issubset(actual):
    errors.append(f"missing invariant assessments: {sorted(expected-actual)}")

if errors:
    for error in errors:
        print(f"FKT05_CONTRACT_GATE FAIL: {error}", file=sys.stderr)
    sys.exit(1)
print("FKT05_CONTRACT_GATE PASS")
