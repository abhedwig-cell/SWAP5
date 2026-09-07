import argparse
import json
import pathlib


def require(cond, msg):
    if not cond:
        raise SystemExit(f"FMQ20_FKT05_EXTERNAL_GATE FAIL: {msg}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--qualification", required=True)
    ap.add_argument("--gate-source", required=True)
    ns = ap.parse_args()

    q = json.loads(pathlib.Path(ns.qualification).read_text())
    gate = pathlib.Path(ns.gate_source).read_text()

    require(q["work_unit"] == "F-KT05", "wrong work unit")
    require(q["qualified"] is True and q["status"] == "QUALIFIED", "F-KT05 not qualified")
    require(q["basis"]["tested_postimage"] == "f7d2ee5e81f1d6686c96114984239e97ba6a8a8a", "tested postimage drift")
    run = q["qualification_run"]
    require(run["run_id"] == 34125537033 and run["conclusion"] == "success", "qualification run mismatch")

    checks = q["qualified_checks"]
    for key in (
        "FKT03_CONTRACT_GATE",
        "FKT03_FSI_BOUNDARY_GATE",
        "FKT03_OPAQUE_TRANSACTION_O0",
        "FKT03_OPAQUE_TRANSACTION_O2",
        "FKT04_CONTRACT_GATE",
        "FKT04_TEMPORAL_PROVENANCE_O0",
        "FKT04_TEMPORAL_PROVENANCE_O2",
        "FKT05_CONTRACT_GATE",
        "FKT05_REUSABLE_CHECKPOINT_O0",
        "FKT05_REUSABLE_CHECKPOINT_O2",
    ):
        require(checks.get(key) == "PASS", f"missing or changed {key}")

    cp = q["checkpoint_contract"]
    required_true = (
        "checkpoint_contains_physical_state_clone",
        "checkpoint_contains_lineage_revision_time_provenance",
        "stale_revision_fails_closed",
        "cross_lineage_fails_closed",
        "time_mismatch_fails_closed",
        "rejection_precedes_physical_execution",
        "same_current_checkpoint_reusable",
    )
    for key in required_true:
        require(cp[key] is True, f"checkpoint contract missing {key}")
    for key in (
        "checkpoint_is_persistent_column_state",
        "checkpoint_contains_solver_scratch",
        "checkpoint_contains_warm_start",
        "capture_mutates_committed_state",
        "checkpoint_can_restore_committed_state",
        "checkpoint_can_publish_committed_state",
    ):
        require(cp[key] is False, f"checkpoint authority/scratch drift {key}")

    replay = q["time_and_replay"]
    require(replay["generic_t0_t1_preserved"] is True, "generic time not preserved")
    require(replay["same_committed_state_replay_qualified"] is True, "same-state replay not qualified")
    require(replay["warm_start_may_change_physical_origin"] is False, "warm start may change physical origin")

    mass = q["mass_conservation"]
    require(mass["hard_requirement_preserved"] is True, "hard mass requirement not preserved")
    require(mass["unrounded_trial_mass_gate_preserved"] is True, "unrounded trial mass gate lost")
    require(mass["full_reference_swap_water_balance_newly_qualified_by_fkt05"] is False, "unsupported full mass claim")

    ref = q["reference_policy"]
    require(ref["production_reference_admission"] == "BLOCKED_FAIL_CLOSED", "reference route unexpectedly open")
    require(ref["production_temporal_profile_qualified"] is False, "temporal profile unexpectedly qualified")

    require('bash "$ROOT/tests/fkt/run_fkt04_gate.sh"' in gate, "F-KT04 boundary not replayed")
    require('python3 "$ROOT/tools/fkt/fkt05_contract_gate.py"' in gate, "F-KT05 contract gate missing")
    require('echo \'FKT05_FOCUSED_O0_O2_GATE PASS\'' in gate, "focused O0/O2 PASS token missing")
    require('for OPT in o0 o2' in gate, "O0/O2 loop missing")

    print("FMQ20_FKT05_EXTERNAL_GATE PASS")


if __name__ == "__main__":
    main()
