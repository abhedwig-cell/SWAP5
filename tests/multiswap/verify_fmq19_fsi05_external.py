import argparse
import json
import pathlib


def require(cond, msg):
    if not cond:
        raise SystemExit(f"FMQ19_FSI05_EXTERNAL_GATE FAIL: {msg}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--qualification", required=True)
    ap.add_argument("--gate-source", required=True)
    ns = ap.parse_args()

    q = json.loads(pathlib.Path(ns.qualification).read_text())
    gate = pathlib.Path(ns.gate_source).read_text()

    require(q["work_unit"] == "F-SI05", "wrong work unit")
    require(q["qualified"] is True, "F-SI05 not qualified")
    require(q["status"] == "QUALIFIED_PRODUCTION_WORKSPACE_SEAM_FOCUSED_ROUTES_ONLY", "unexpected status")

    mat = q["production_materialization"]
    require(mat["commit"] == "1fe1bf4790955594290ba1233d5684542799bf9e", "materialization drift")
    require(mat["headcalc_blob"] == "e22251c8f562839857cdb7a609a8148d1f2d58f8", "HeadCalc blob drift")
    require(mat["workspace_blob"] == "93285b2ca24669494c93c00403e3783fca6758e9", "workspace blob drift")
    require(mat["adapter_blob"] == "e02882bd45f67b42ede118de14a6b5b8b16fdb80", "adapter blob drift")
    require(mat["soilwater_changed"] is False, "legacy caller changed")
    require(mat["transaction_source_changed"] is False, "transaction source changed")

    tested = q["tested_implementation_checkpoint"]
    require(tested["head"] == "56c21448a2a0be716d497ac34db8c5eec60dd246", "tested postimage drift")
    require(tested["workflow_run"] == 34124675751 and tested["conclusion"] == "success", "tested workflow mismatch")
    final = q["documented_postimage_verification"]
    require(final["head"] == "11b3138e05b1a5c59033134e870f6ffb58e6a9f6", "documented postimage drift")
    require(final["workflow_run"] == 34125047417 and final["conclusion"] == "success", "final postimage workflow mismatch")

    checks = q["qualified_checks"]
    required = {
        "FSI05_T03_explicit_workspace_production_seam": "PASS",
        "FSI05_T04_legacy_one_argument_source_compatibility": "PASS",
        "FSI05_T05_main_route_preimage_vs_production_O0_byte_identity": "PASS",
        "FSI05_T06_main_route_preimage_vs_production_O2_byte_identity": "PASS",
        "FSI05_T07_forced_band_fallback_preimage_vs_production_O0_byte_identity": "PASS",
        "FSI05_T08_forced_band_fallback_preimage_vs_production_O2_byte_identity": "PASS",
        "FSI05_T09_explicit_workspace_vs_legacy_compatibility_identity": "PASS",
        "FSI05_T10_O0_O2_identity": "PASS",
        "FSI05_T11_workspace_poison_reset_main_and_band_storage": "PASS",
        "FSI05_T12_ABA_repeat_identity_main_and_band_routes": "PASS_FOCUSED_FIXTURE",
        "FSI05_T13_solver_route_iteration_identity": "PASS_FOCUSED_FIXTURE",
        "FSI05_T14_unrounded_focused_equation_residual_identity": "PASS_ZERO_WITHIN_MACHINE_PRECISION",
        "FSI05_T16_common_workspace_1_2_4_8_thread_isolation_O0_O2": "PASS",
    }
    for key, value in required.items():
        require(checks.get(key) == value, f"missing or changed {key}")

    own = q["workspace_ownership"]
    require(own["main_newton_jacobian_scratch"] == "WORKER_OR_ACTIVE_SOLVE_JOB", "main scratch ownership")
    require(own["band_matrix"] == "WORKER_OR_ACTIVE_SOLVE_JOB", "band matrix ownership")
    require(own["persistent_column_state_contains_solver_scratch"] is False, "solver scratch persisted per column")
    require(own["adapter_passes_existing_richards_workspace"] is True, "adapter workspace pass missing")

    mass = q["mass_conservation_statement"]
    require(mass["hard_requirement_preserved"] is True, "hard mass requirement not preserved")
    require(mass["full_swap_water_balance_identity_qualified"] is False, "unsupported full SWAP mass claim")

    policy = q["physics_and_policy"]
    for key in ("solver_physics_changed", "numerical_policy_changed", "transaction_semantics_changed", "generic_time_semantics_changed", "fallback_policy_changed"):
        require(policy[key] is False, f"unexpected change {key}")

    deferred = q["deferred_not_claimed"]
    require(deferred["full_reference_richards_reentrancy"] == "NOT_QUALIFIED", "full reentrancy unexpectedly admitted")
    require(deferred["parallel_real_headcalc_1_2_4_8_workers"] == "NOT_QUALIFIED", "parallel real HeadCalc unexpectedly admitted")
    require(deferred["legacy_worker_save_removed"] is False, "legacy worker SAVE unexpectedly resolved")
    require(deferred["full_unrounded_swap_mass_balance"] == "NOT_QUALIFIED", "full mass unexpectedly admitted")
    require(deferred["production_multiswap_admission"] is False, "production MultiSWAP unexpectedly admitted")

    for token in (
        "F-SI05_REAL_REPLAY_O0 PASS",
        "F-SI05_REAL_REPLAY_O2 PASS",
        "F-SI05_O0_O2_IDENTITY PASS",
        "F-SI05_WORKSPACE_1_2_4_8 PASS",
        "F-SI05_GATE PASS",
        "call headcalc(ws%legacy_worker, ws%richards)",
    ):
        require(token in gate, f"gate source missing {token}")

    print("FMQ19_FSI05_EXTERNAL_GATE PASS")


if __name__ == "__main__":
    main()
