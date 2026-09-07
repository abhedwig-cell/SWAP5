import argparse
import json


def load(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fsi-qualification", required=True)
    parser.add_argument("--fsi-contract", required=True)
    parser.add_argument("--fvq-status", required=True)
    parser.add_argument("--fvq-matrix", required=True)
    args = parser.parse_args()

    fsiq = load(args.fsi_qualification)
    fsic = load(args.fsi_contract)
    vqs = load(args.fvq_status)
    vqm = load(args.fvq_matrix)

    require(fsiq["work_unit"] == "F-SI01", "wrong F-SI work unit")
    require(fsiq["qualified"] is True, "F-SI01 not qualified")
    require(fsiq["status"] == "QUALIFIED_BOUNDARY_BASELINE_ONLY", "unexpected F-SI01 status")
    require(fsiq["production_source_changed_by_fsi01"] is False, "F-SI01 changed production source")
    require(fsiq["qualified_checks"]["FSI01-T02_worker_context_isolation_O0_O2_OpenMP_8_workers"] == "PASS", "F-SI01 T02 not PASS")
    require(len(fsiq["deferred_not_claimed"]) == 9, "unexpected F-SI01 deferred-test count")
    require(all(value == "BLOCKED_BY_COMMON_SOLVER_INTERFACE" for value in fsiq["deferred_not_claimed"].values()), "F-SI01 deferred solver test unexpectedly admitted")

    require(fsic["contract"] == "soil_water_solver_v1_boundary", "wrong F-SI solver contract")
    require(fsic["implemented_in_fsi01"] is False, "F-SI01 solver interface unexpectedly implemented")
    require(fsic["workspace"]["ownership"] == "worker_or_active_solve_job", "wrong solver workspace ownership")
    require(fsic["workspace"]["persistent_per_logical_column"] is False, "solver workspace persisted per column")
    require(fsic["workspace"]["poisoning_required"] is True, "scratch poisoning not required")
    require(fsic["transaction_boundary"]["solver_may_mutate_committed_input"] is False, "solver may mutate committed input")
    require(fsic["transaction_boundary"]["solver_may_commit"] is False, "solver may commit")
    require(fsic["transaction_boundary"]["solver_may_rollback"] is False, "solver may rollback")

    require(vqs["work_unit"] == "F-VQ08", "wrong F-VQ work unit")
    require(vqs["qualified"] is True, "F-VQ08 readiness boundary not qualified")
    require(vqs["decision"] == "QUALIFIED_TEMPORAL_CHARACTERIZATION_READINESS_ONLY", "unexpected F-VQ08 decision")
    require(vqs["real_b1_10_temporal_characterization_qualified"] is False, "real temporal characterization unexpectedly qualified")
    require(vqs["production_temporal_profile_qualified"] is False, "production temporal profile unexpectedly qualified")
    require(vqs["canonical_reference_admission"] == "BLOCKED_FAIL_CLOSED", "reference admission not fail-closed")
    require(vqs["complete_optional_process_scope_qualified"] is False, "optional process scope unexpectedly qualified")

    claims = {item["claim_id"]: item for item in vqm["claims"]}
    for claim_id in ("FVQ08-C05", "FVQ08-C06", "FVQ08-C07", "FVQ08-C08"):
        require(claims[claim_id]["target"] == "BLOCKED_FAIL_CLOSED", f"{claim_id} not blocked fail-closed")
        require(claims[claim_id]["claim_qualified"] is False, f"{claim_id} unexpectedly qualified")
    require(claims["FVQ08-C09"]["target"] == "PROHIBITED", "hard-mass relaxation not prohibited")
    require(claims["FVQ08-C09"]["claim_qualified"] is False, "prohibited hard-mass relaxation unexpectedly qualified")

    print("FMQ13_EXTERNAL_BOUNDARY_GATE PASS")


if __name__ == "__main__":
    main()
