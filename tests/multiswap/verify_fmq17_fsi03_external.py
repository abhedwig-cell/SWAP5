import argparse
import json
import pathlib

EXPECTED_QUAL_HEAD = "c14ad3e032dd0285825051d8cf0e7d11ade01cd6"
EXPECTED_TESTED = "79e3e9052a4f68306b8c826b063497247fd339d6"


def fail(message):
    raise SystemExit(message)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--qualification", required=True)
    parser.add_argument("--adapter", required=True)
    parser.add_argument("--test-source", required=True)
    parser.add_argument("--fvq09-status", required=True)
    args = parser.parse_args()

    q = json.loads(pathlib.Path(args.qualification).read_text())
    adapter = pathlib.Path(args.adapter).read_text()
    test_source = pathlib.Path(args.test_source).read_text()
    fvq = json.loads(pathlib.Path(args.fvq09_status).read_text())

    if q.get("work_unit") != "F-SI03" or not q.get("qualified"):
        fail("F-SI03 qualification not admitted")
    if q.get("status") != "QUALIFIED_SOURCE_BOUND_ADAPTER_CONTRACT_ONLY":
        fail("unexpected F-SI03 qualification scope")
    if q.get("tested_postimage") != EXPECTED_TESTED:
        fail("unexpected F-SI03 tested postimage")
    if q.get("qualification_run", {}).get("conclusion") != "success":
        fail("F-SI03 qualification run is not green")

    checks = q.get("qualified_checks", {})
    required = {
        "source_bound_external_signature": "PASS",
        "common_solver_layer_remains_legacy_global_free": "PASS",
        "protected_B1_10_and_FKT_sources_unchanged": "PASS",
        "adapter_O0": "PASS_TEST_DOUBLE",
        "adapter_O2": "PASS_TEST_DOUBLE",
        "request_base_state_translation": "PASS_TEST_DOUBLE",
        "candidate_state_translation": "PASS_TEST_DOUBLE",
        "top_bottom_flux_translation": "PASS_TEST_DOUBLE",
        "covered_legacy_state_restoration": "PASS_TEST_DOUBLE",
        "retry_advice_without_transaction_authority": "PASS_TEST_DOUBLE",
        "repeat_same_request": "PASS_TEST_DOUBLE",
        "ABA_order": "PASS_TEST_DOUBLE",
        "workspace_poison_independence": "PASS_TEST_DOUBLE",
        "unsupported_physics_and_policy_fail_closed": "PASS",
        "FSI02_common_contract_regression_O0_O2": "PASS",
        "FSI02_workspace_regression_1_2_4_8_threads": "PASS",
    }
    for key, expected in required.items():
        if checks.get(key) != expected:
            fail(f"missing qualified F-SI03 check: {key}")

    mass = q.get("mass_conservation_statement", {})
    if mass.get("hard_requirement_preserved") is not True:
        fail("hard mass requirement not preserved")
    if mass.get("adapter_mass_accounting_qualified") is not False:
        fail("adapter mass accounting must remain unqualified")
    if mass.get("returned_unrounded_mass_balance_residual") != "NaN":
        fail("F-SI03 must remain fail-closed on physical mass residual")

    deferred = q.get("deferred_not_claimed", {})
    if deferred.get("real_HeadCalc_executed_by_qualification_harness") is not False:
        fail("real HeadCalc execution must remain unclaimed")
    if deferred.get("real_HeadCalc_numerical_identity") != "NOT_QUALIFIED":
        fail("real HeadCalc numerical identity must remain unqualified")
    if deferred.get("full_reference_Richards_reentrancy") != "NOT_QUALIFIED":
        fail("reference reentrancy must remain unqualified")
    if deferred.get("parallel_reference_solver_execution") != "NOT_QUALIFIED":
        fail("parallel reference execution must remain unqualified")
    if deferred.get("production_reference_admission") is not False:
        fail("production reference admission must remain false")
    if deferred.get("production_MultiSWAP_admission") is not False:
        fail("production MultiSWAP admission must remain false")

    adapter_tokens = (
        "type, extends(soil_water_solver_t), public :: reference_richards_legacy_solver_t",
        "call headcalc(ws%legacy_worker)",
        "result%candidate_state%pressure_head = h(1:numnod)",
        "result%unrounded_mass_balance_residual = ieee_value",
        "legacy-macropore-deferred",
        "legacy-implicit-k-deferred",
        "legacy-workspace-type-error",
    )
    for token in adapter_tokens:
        if token not in adapter:
            fail(f"adapter token missing: {token}")

    test_tokens = (
        "near_vector",
        "near_scalar",
        "poison_reference_workspace",
        "call expect_same_candidate(result_a1, result_a2, failures)",
        "legacy-macropore-deferred",
        "legacy-implicit-k-deferred",
    )
    for token in test_tokens:
        if token not in test_source:
            fail(f"warning-clean F-SI03 test token missing: {token}")

    if fvq.get("work_unit") != "F-VQ09" or not fvq.get("qualified"):
        fail("F-VQ09 contract evidence missing")
    if fvq.get("decision") != "QUALIFIED_REAL_TEMPORAL_HARNESS_CONTRACT_ONLY":
        fail("unexpected F-VQ09 scope")
    if fvq.get("real_b1_10_temporal_characterization_qualified") is not False:
        fail("F-VQ09 must not be promoted to real temporal evidence")
    if fvq.get("canonical_reference_admission") != "BLOCKED_FAIL_CLOSED":
        fail("canonical reference admission must remain blocked")

    print("FMQ17_FSI03_EXTERNAL_GATE PASS")


if __name__ == "__main__":
    main()
