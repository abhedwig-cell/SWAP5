import argparse
import json
import pathlib


def require(cond, msg):
    if not cond:
        raise SystemExit(f"FMQ18_FSI04_EXTERNAL_GATE FAIL: {msg}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--qualification", required=True)
    ap.add_argument("--gate-source", required=True)
    ns = ap.parse_args()

    q = json.loads(pathlib.Path(ns.qualification).read_text())
    gate = pathlib.Path(ns.gate_source).read_text()

    require(q["work_unit"] == "F-SI04", "wrong work unit")
    require(q["qualified"] is True, "F-SI04 not qualified")
    require(q["status"] == "QUALIFIED_SOURCE_BOUND_MAIN_WORKSPACE_REPLAY_ONLY", "unexpected status")
    require(q["tested_postimage"] == "0cfbefc271447b4b53eeee50c1dfbb2acaf020df", "tested postimage drift")
    require(q["source_basis"]["canonical_headcalc_blob"] == "225b9f2cc1ecff01414b5691799103b92bc068c5", "HeadCalc blob drift")
    run = q["qualification_run"]
    require(run["workflow_run"] == 34122972659 and run["conclusion"] == "success", "qualification run mismatch")

    checks = q["qualified_checks"]
    required = {
        "FSI04_T03_original_real_HeadCalc_O0_execute": "PASS",
        "FSI04_T04_workspace_real_HeadCalc_O0_execute": "PASS",
        "FSI04_T05_original_vs_workspace_O0_byte_identity": "PASS",
        "FSI04_T06_original_real_HeadCalc_O2_execute": "PASS",
        "FSI04_T07_workspace_real_HeadCalc_O2_execute": "PASS",
        "FSI04_T08_original_vs_workspace_O2_byte_identity": "PASS",
        "FSI04_T09_O0_vs_O2_output_identity": "PASS",
        "FSI04_T10_workspace_scratch_poison_reset": "PASS",
        "FSI04_T11_ABA_repeated_call_identity": "PASS_FOCUSED_FIXTURE",
        "FSI04_T12_solver_route_iteration_identity": "PASS_FOCUSED_FIXTURE",
        "FSI04_T13_unrounded_focused_equation_residual_identity": "PASS_ZERO_WITHIN_MACHINE_PRECISION",
    }
    for key, value in required.items():
        require(checks.get(key) == value, f"missing or changed {key}")

    mass = q["mass_conservation_statement"]
    require(mass["hard_requirement_preserved"] is True, "hard mass requirement not preserved")
    require(mass["focused_unrounded_residual_identity_qualified"] is True, "focused residual not qualified")
    require(mass["full_SWAP_water_balance_identity_qualified"] is False, "unsupported full SWAP mass claim")

    cc = q["change_control"]
    for key in ("headcalc_modified", "soilwater_modified", "solver_physics_changed", "numerical_policy_changed", "production_routing_changed"):
        require(cc[key] is False, f"unexpected source/control change {key}")

    deferred = q["deferred_not_claimed"]
    require(deferred["production_workspace_aware_HeadCalc_seam"] == "NOT_YET_COMMITTED", "production seam unexpectedly admitted")
    require(deferred["parallel_real_HeadCalc_1_2_4_8_workers"] == "NOT_QUALIFIED", "parallel real HeadCalc unexpectedly admitted")
    require(deferred["full_unrounded_SWAP_mass_balance"] == "NOT_QUALIFIED", "full mass unexpectedly admitted")
    require(deferred["production_reference_admission"] is False, "production reference unexpectedly admitted")
    require(deferred["production_MultiSWAP_admission"] is False, "production MultiSWAP unexpectedly admitted")

    fixture = q["focused_fixture"]
    require(fixture["active_nodes"] == 4, "fixture node count changed")
    require(fixture["expected_nonlinear_iterations"] == 1, "fixture iterations changed")

    for token in (
        'PINNED_HEADCALC_BLOB="225b9f2cc1ecff01414b5691799103b92bc068c5"',
        "F-SI04_REAL_HEADCALC_REPLAY PASS",
        'cmp "$original/output.txt" "$candidate/output.txt"',
        "F-SI04_O0_O2_IDENTITY PASS",
        "F-SI04_GATE PASS",
    ):
        require(token in gate, f"gate source missing {token}")

    print("FMQ18_FSI04_EXTERNAL_GATE PASS")


if __name__ == "__main__":
    main()
