import argparse
import json
import pathlib
import sys

EXPECTED_HEAD = "da1d5da0d909c5ce55efa17507b805bffd6b82f9"
EXPECTED_TESTED = "9715465216edb400cbcd125a8572a1498a6b0211"


def fail(message):
    raise SystemExit(message)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--qualification", required=True)
    parser.add_argument("--contract-source", required=True)
    parser.add_argument("--workspace-source", required=True)
    args = parser.parse_args()

    q = json.loads(pathlib.Path(args.qualification).read_text())
    contract = pathlib.Path(args.contract_source).read_text()
    workspace = pathlib.Path(args.workspace_source).read_text()

    if q.get("work_unit") != "F-SI02" or not q.get("qualified"):
        fail("F-SI02 qualification is not admitted")
    if q.get("status") != "QUALIFIED_CONTRACT_AND_WORKSPACE_ONLY":
        fail("unexpected F-SI02 qualification scope")
    if q.get("tested_postimage") != EXPECTED_TESTED:
        fail("unexpected F-SI02 tested postimage")
    if q.get("qualification_run", {}).get("conclusion") != "success":
        fail("F-SI02 qualification run is not green")

    checks = q.get("qualified_checks", {})
    required = {
        "FSI02-T01_common_contract_O0_compile": "PASS",
        "FSI02-T02_common_contract_O2_compile": "PASS",
        "FSI02-T04_base_state_clone_independence": "PASS",
        "FSI02-T05_workspace_reset_and_scratch_poisoning": "PASS",
        "FSI02-T06_workspace_isolation_1_2_4_8_threads": "PASS",
        "FSI02-T07_warm_start_reset_not_physical_state": "PASS",
        "FSI02-T08_protected_legacy_runtime_transaction_blobs_unchanged": "PASS",
        "FSI02-T09_no_SAVE_IO_or_legacy_global_use_in_common_solver_layer": "PASS",
        "FSI02-T10_FSI01_boundary_regression": "PASS",
    }
    for key, expected in required.items():
        if checks.get(key) != expected:
            fail(f"missing required F-SI02 check: {key}")

    deferred = q.get("deferred_not_claimed", {})
    if deferred.get("reference_Richards_solver_reentrancy") != "NOT_YET_BOUND":
        fail("reference Richards reentrancy must remain not yet bound")
    if deferred.get("unrounded_physical_water_balance_identity") != "DEFERRED_TO_REFERENCE_BINDING":
        fail("physical mass identity must remain deferred")
    if deferred.get("parallel_MultiSWAP_backend") != "NOT_QUALIFIED":
        fail("parallel MultiSWAP backend must remain unqualified")
    if deferred.get("interface_tangent_algorithm") != "NOT_IMPLEMENTED":
        fail("interface tangent algorithm must remain unimplemented")

    control = q.get("change_control", {})
    for key in (
        "existing_headcalc_modified",
        "existing_soilwater_modified",
        "existing_worker_context_modified",
        "transaction_source_modified",
        "solver_physics_changed",
        "numerical_policy_selection_changed",
        "shared_FKT_kernel_type_changed",
    ):
        if control.get(key) is not False:
            fail(f"change-control violation: {key}")

    contract_tokens = (
        "type, public :: soil_water_solve_request_t",
        "type, public :: soil_water_solve_result_t",
        "type, abstract, public :: soil_water_solver_t",
        "type, abstract, public :: soil_water_solver_workspace_base_t",
        "unrounded_mass_balance_residual",
        "soil_water_interface_sensitivity_t",
        "procedure(soil_water_solve_ifc), deferred :: solve",
    )
    for token in contract_tokens:
        if token not in contract:
            fail(f"common solver contract token missing: {token}")

    workspace_tokens = (
        "type, extends(soil_water_solver_workspace_base_t), public :: reference_richards_workspace_t",
        "subroutine reset_reference_workspace",
        "subroutine poison_reference_workspace",
        "function reference_workspace_payload_bytes",
        "warm_start_head",
        "jacobian",
    )
    # The implementation uses Jacobian band names rather than the word jacobian.
    workspace_required = workspace_tokens[:-1] + ("dfdh_main", "residual", "delta_head")
    for token in workspace_required:
        if token not in workspace:
            fail(f"reference workspace token missing: {token}")

    if "class(transaction_state_t)" in workspace or "commit_candidate" in workspace:
        fail("transaction authority leaked into solver workspace")

    print("FMQ14_FSI02_EXTERNAL_GATE PASS")


if __name__ == "__main__":
    main()
