#!/usr/bin/env python3
import argparse
import json
import pathlib

p = argparse.ArgumentParser()
p.add_argument("--qualification", required=True)
p.add_argument("--contract", required=True)
p.add_argument("--gate-source", required=True)
p.add_argument("--test-source", required=True)
args = p.parse_args()

q = json.loads(pathlib.Path(args.qualification).read_text())
c = json.loads(pathlib.Path(args.contract).read_text())
gate = pathlib.Path(args.gate_source).read_text()
test = pathlib.Path(args.test_source).read_text()

assert q["work_unit"] == "F-KT06"
assert q["decision"] == "QUALIFIED_OPTIONAL_PROCESS_CONTINUATION_LIFECYCLE_ON_OPAQUE_TRANSACTION_STATE"
assert q["tested_postimage"] == "80a68dea3bfa45d7e8d533ec5a67fc89bdb786db"
assert q["production_source_changed"] is False
assert q["qualification"]["focused_conclusion"] == "success"
assert q["qualification"]["fkt06_optional_continuation_O0"] == "PASS"
assert q["qualification"]["fkt06_optional_continuation_O2"] == "PASS"
claims = q["qualified_claims"]
assert claims["inactive_optional_process_can_remain_unallocated_through_checkpoint_trial_candidate_and_commit"] is True
assert claims["same_checkpoint_replay_reproduces_optional_continuation"] is True
assert claims["hard_mass_rejection_preserves_committed_and_checkpoint_optional_continuation"] is True
assert claims["stale_checkpoint_rejected_before_physical_model_execution"] is True
for key in (
    "macropore_production_admission",
    "reference_production_admission",
    "full_reference_solver_reentrancy",
    "parallel_real_headcalc_workers",
    "full_unrounded_swap_mass_identity",
    "production_multiswap_runtime",
):
    assert q["nonclaims"][key] is False

assert c["work_unit"] == "F-KT06"
assert c["decision"] == "EXISTING_OPAQUE_TRANSACTION_STATE_LIFECYCLE_IS_THE_CANONICAL_CARRIER"
scaling = c["optional_state_scaling"]
assert scaling["kernel_allocates_optional_process_state_for_inactive_columns"] is False
assert scaling["adapter_state_may_keep_optional_component_unallocated_when_inactive"] is True
assert scaling["inactive_route_must_not_allocate_process_continuation_during_trial_or_commit"] is True
assert scaling["persistent_cost_scales_with_active_option"] is True
assert c["classification_contract"]["solver_newton_jacobian_linear_solve_temporaries"] == "worker_or_active_job_scratch"

assert "bash \"$ROOT/tests/fkt/run_fkt05_gate.sh\"" in gate
assert "FKT06_FOCUSED_O0_O2_GATE PASS" in gate
for token in (
    "call test_active_continuation_commit_and_replay(failures)",
    "call test_mass_failure_preserves_continuation(failures)",
    "call test_inactive_option_stays_unallocated(failures)",
    "inactive committed state has no optional allocation",
    "inactive checkpoint has no optional allocation",
    "inactive trial does not allocate optional continuation",
    "inactive commit remains allocation-free",
):
    assert token in test

print("F-MQ22_EXTERNAL_FKT06_VERIFIER PASS")
