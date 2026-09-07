#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--fsi06', required=True)
p.add_argument('--fvq12', required=True)
p.add_argument('--fsi06-gate-source', required=True)
a = p.parse_args()

fsi06 = json.loads(Path(a.fsi06).read_text())
fvq12 = json.loads(Path(a.fvq12).read_text())
gate = Path(a.fsi06_gate_source).read_text()

assert fsi06['work_unit'] == 'F-SI06'
assert fsi06['qualified'] is True
assert fsi06['status'] == 'QUALIFIED_HISTORY_ISOLATION_PARALLEL_BINDING_BLOCKED'
assert fsi06['history_ownership']['headcalc_hidden_save_removed'] is True
assert fsi06['history_ownership']['common_reference_history_owner'] == 'call_local a23bu_solver_history_t'
assert fsi06['qualified_checks']['FSI06_T10_serial_ABA_identity'] == 'PASS_FOCUSED_FIXTURE'
assert fsi06['qualified_checks']['FSI06_T14_common_workspace_1_2_4_8_thread_isolation_O0_O2'] == 'PASS'
assert fsi06['qualified_checks']['FSI06_T17_real_headcalc_parallel_admission'] == 'BLOCKED_SHARED_LEGACY_GLOBAL_TRANSLATION'
assert fsi06['parallel_admission']['full_real_headcalc_reentrancy_qualified'] is False
assert fsi06['parallel_admission']['common_workspace_parallel_isolation_qualified'] is True
assert fsi06['mass_conservation_statement']['full_swap_water_balance_identity_qualified'] is False
assert fsi06['physics_and_policy']['solver_physics_changed'] is False
assert fsi06['physics_and_policy']['numerical_policy_changed'] is False
assert fsi06['deferred_not_claimed']['production_multiswap_admission'] is False

assert fvq12['work_unit'] == 'F-VQ12'
assert fvq12['qualified'] is True
assert fvq12['decision'] == 'QUALIFIED_FKT05_FSI05_SOURCE_BOUND_NONCONFLICT_ONLY'
assert fvq12['fkt05_source_bound_admitted'] is True
assert fvq12['fsi05_source_bound_admitted'] is True
assert fvq12['fkt05_fsi05_contractual_nonconflict_qualified'] is True
assert fvq12['fkt05_fsi05_composed_runtime_qualified'] is False
assert fvq12['full_reference_solver_reentrancy_qualified'] is False
assert fvq12['parallel_real_headcalc_workers_qualified'] is False
assert fvq12['full_unrounded_swap_mass_identity_qualified'] is False
assert fvq12['production_reference_admission'] == 'BLOCKED_FAIL_CLOSED'
assert fvq12['production_multiswap_admission'] is False

for token in (
    "F-SI06_ADAPTER_HISTORY_ISOLATION PASS",
    "F-SI06_SOILWATER_COMPILE_O0_O2 PASS",
    "F-SI06_WORKSPACE_1_2_4_8 PASS",
    "F-SI06_REAL_PARALLEL_ADMISSION BLOCKED_SHARED_LEGACY_GLOBAL_TRANSLATION",
    "F-SI06_GATE PASS",
):
    assert token in gate, token

print('F-MQ21_EXTERNAL_BOUNDARIES PASS')
