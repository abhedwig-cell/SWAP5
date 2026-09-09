#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=394d064a0dad0a7f7852b129bae99713b9aeb4c0
fail() { echo "FSI23_GATE_A_FAIL $*" >&2; exit 1; }

# Gate A is owner-contract evidence only. Production Richards/runtime source must remain exact.
git diff --quiet "$BASE" -- \
  src/solver \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  || fail 'production Richards/runtime source drift from F-VQ29 closeout'

declare -A EXPECTED_BLOBS=(
  [src/solver/mod_soil_water_solver_contract.f90]=4271372085d800fd5da969a2ed073b00422d79c6
  [src/solver/mod_reference_richards_state_binding.f90]=e68d88382c6502c571713cc97fddd4e18434e271
  [src/adapter/mod_reference_richards_legacy_binding.f90]=db432cac3f1156a179c636435a25f52cdececffc
  [src/runtime/mod_a23bu_worker_execution_context.f90]=2a190d206200ad201c37c9a82d3e32e651d37a37
  [src/legacy/b1_10_port/headcalc.f90]=55893f1f5ccba2052ad681743aa155b69f351246
)
for path in "${!EXPECTED_BLOBS[@]}"; do
  got="$(git rev-parse "HEAD:$path")"
  [[ "$got" == "${EXPECTED_BLOBS[$path]}" ]] || fail "source blob drift $path $got"
done
echo 'FSI23_GATE_A_SOURCE_LOCK=PASS'

python3 - <<'PY'
import json
from pathlib import Path

contract=json.loads(Path('integration/f-si/F-SI23_WORK_UNIT_CONTRACT.json').read_text())
mapping=json.loads(Path('integration/f-si/F-SI23_GATE_A_OWNER_MAPPING.json').read_text())
status=json.loads(Path('integration/f-si/F-SI23_STATUS.json').read_text())

assert contract['work_unit']=='F-SI23'
assert contract['scope']['production_implementation'] is False
assert contract['scope']['scientific_temporal_tolerance_selection'] is False
assert mapping['candidate']['name']=='decision_only_backward_euler_pressure_head_LTE_observer'
assert mapping['candidate']['principal_state_advance']=='existing_reference_Richards_backward_Euler_candidate_unchanged'
assert mapping['candidate']['corrected_Thomas_Gladwell_state_used_as_candidate'] is False
assert mapping['ownership_decision']['hdot_prev_is_physical_state'] is False
assert mapping['ownership_decision']['history_update_point']=='only after the corresponding candidate interval/subinterval is accepted into canonical working state'
assert mapping['continuity_and_bootstrap']['startup_after_initialization_resolved'] is False
assert mapping['continuity_and_bootstrap']['silent_default_hdot_prev_zero_allowed'] is False
assert mapping['continuity_and_bootstrap']['silent_left_derivative_reuse_after_discontinuity_allowed'] is False
assert mapping['transaction_mapping']['hard_mass_gate_independent'] is True
assert mapping['cost_assessment']['steady_state_attempt_nonlinear_solves']==1
assert mapping['gate_A_decision']=='OWNER_SHAPE_FEASIBLE_BOOTSTRAP_AND_DISCONTINUITY_SEMANTICS_BLOCK_PROTOTYPE'
assert status['status']=='GATE_A_OWNER_SHAPE_FEASIBLE_BOOTSTRAP_BLOCKS_PROTOTYPE'
assert status['current_candidate']['prototype_allowed_now'] is False
assert status['hard_holds']['production_source_modified'] is False
assert status['hard_holds']['scientific_temporal_tolerance_selected'] is False
assert status['hard_holds']['F_VQ30_started'] is False
print('FSI23_GATE_A_JSON_CONTRACT=PASS')
PY

echo 'FSI23_GATE_A_PROTOTYPE_HOLD=PASS'
echo 'FSI23_GATE_A PASS'
