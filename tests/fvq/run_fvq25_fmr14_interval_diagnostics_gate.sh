#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq25-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FMR14=3a531e2c7da54ba0d98b87d3b4d660fd9772b398
FMR13=985058c0261d284424432a65bded16b7fc9107cb
KERNEL=af42c7d51ef545e20c76d3000f1ed1493690d68e
RUNTIME=7a60f8b8d18672098fed1c6890a95aac738ed21d

# Qualification artifacts may be added, but production source must be the exact
# owner-qualified F-MR14 postimage.
git diff --quiet "$FMR14" -- src || {
  echo 'FVQ25_CANDIDATE_PRODUCTION_IMMUTABILITY=FAIL' >&2
  git diff --name-only "$FMR14" -- src >&2
  exit 1
}
echo 'FVQ25_CANDIDATE_PRODUCTION_IMMUTABILITY=PASS'

[[ "$(git rev-parse HEAD:src/kernel/mod_kernel_transactions.f90)" == "$KERNEL" ]]
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == "$RUNTIME" ]]
python3 - <<'PY'
import json
from pathlib import Path
s=json.loads(Path('integration/f-mr/F-MR14_STATUS.json').read_text())
assert s['status']=='QUALIFIED_FPE02_INTERVAL_COST_DIAGNOSTICS_IN_FMR13_REAL_PHYSICS_LINEAGE'
assert s['state']['qualified'] is True
assert s['physics_changed'] is False
assert s['numerical_controls_changed'] is False
assert s['acceptance_changed'] is False
assert s['mass_requirement_relaxed'] is False
assert s['transaction_semantics_changed'] is False
assert s['fpe02_b01']=='NOT_RESOLVED_BY_FMR14_DIAGNOSTICS_ONLY'
print('FVQ25_FMR14_OWNER_QUALIFICATION_LOCK=PASS')
PY

expected=$'src/kernel/mod_kernel_transactions.f90\nsrc/runtime/mod_fmr_serialized_multiswap_runtime.f90'
actual="$(git diff --name-only "$FMR13" -- src | sort)"
[[ "$actual" == "$expected" ]]
echo 'FVQ25_EXACT_TWO_PATH_OBSERVER_DELTA_VS_FMR13=PASS'

# Independent source interpretation: deleting only the observer declarations and
# direct kernel_diag assignments must recover the exact F-MR13 runtime source.
python3 - <<'PY'
from pathlib import Path
import subprocess
cur=Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text()
base=subprocess.check_output(['git','show','985058c0261d284424432a65bded16b7fc9107cb:src/runtime/mod_fmr_serialized_multiswap_runtime.f90'],text=True)
fields="""    integer :: accepted_substeps = 0
    integer :: solver_nonlinear_iterations = 0
    integer :: solver_internal_retries = 0
    integer :: solver_headcalc_calls = 0
    integer :: solver_jacobian_builds = 0
    integer :: solver_linear_solves = 0
    integer :: solver_backtracking_attempts = 0
    integer :: solver_alternative_solver_calls = 0
"""
assign="""    output%accepted_substeps = kernel_diag%accepted_substeps
    output%solver_nonlinear_iterations = kernel_diag%nonlinear_iterations
    output%solver_internal_retries = kernel_diag%internal_retries
    output%solver_headcalc_calls = kernel_diag%headcalc_calls
    output%solver_jacobian_builds = kernel_diag%jacobian_builds
    output%solver_linear_solves = kernel_diag%linear_solves
    output%solver_backtracking_attempts = kernel_diag%backtracking_attempts
    output%solver_alternative_solver_calls = kernel_diag%alternative_solver_calls
"""
assert cur.count(fields)==1 and cur.count(assign)==1
assert cur.replace(fields,'',1).replace(assign,'',1)==base
for field in ['accepted_substeps','solver_nonlinear_iterations','solver_internal_retries','solver_headcalc_calls',
              'solver_jacobian_builds','solver_linear_solves','solver_backtracking_attempts','solver_alternative_solver_calls']:
    needle='output%'+field+' = kernel_diag%'
    assert cur.count(needle)==1
print('FVQ25_RUNTIME_OBSERVER_DELTA_INDEPENDENTLY_NORMALIZES_TO_FMR13=PASS')
print('FVQ25_OBSERVER_ASSIGNMENTS_DIRECT_AND_EXACTLY_ONCE=PASS')
PY

# Re-execute the complete owner gate on this independent qualification branch.
bash tests/fmr/run_fmr14_interval_cost_diagnostics_gate.sh | tee "$BUILD/fmr14.txt"
for marker in \
  'FMR14_SOURCE_DELTA_EXACTLY_TWO_OBSERVER_PATHS=PASS' \
  'FMR14_KERNEL_EXACT_FPE02_QUALIFIED_POSTIMAGE=PASS' \
  'FMR14_RUNTIME_NORMALIZES_BITWISE_TO_FMR13_AFTER_OBSERVER_DELTA_REMOVAL=PASS' \
  'FMR14_FMR09_AUTHORITATIVE_MASS_TRANSACTION_REPLAY=PASS' \
  'FMR14_FMR09_HISTORICAL_OUTPUT_HASH_PRESERVED=PASS' \
  'FMR14_FMR12_FMR10_RUNTIME_REGRESSION=PASS' \
  'FMR14_FMR12_HISTORICAL_OUTPUT_HASH_PRESERVED=PASS' \
  'FMR14_DIAGNOSTICS_SURFACE_O0_O2_IDENTITY=PASS' \
  'FMR14_INTERVAL_COST_DIAGNOSTICS_OWNER_COMPOSITION_GATE PASS'; do
  grep -Fq "$marker" "$BUILD/fmr14.txt"
done
grep -Fq 'FMR09_OUTPUT_SHA256=920ec4876c528dc3af9f5de4616f50a1214b3c87e999d9261bf57a348cf2f08d' "$BUILD/fmr14.txt"
grep -Fq 'FMR12_OUTPUT_SHA256=5e70234b073d7d865075ec8d315755426b47d825539e0a0d74df6c122e733e29' "$BUILD/fmr14.txt"
grep -Fq 'FMR14_INTERVAL_COST_DIAGNOSTICS= 1 3 0 3 3 3 3 0' "$BUILD/fmr14.txt"
echo 'FVQ25_OWNER_GATE_REEXECUTION=PASS'
echo 'FVQ25_EXISTING_SCIENTIFIC_RUNTIME_OUTPUTS_PRESERVED=PASS'
echo 'FVQ25_AUTHORITATIVE_MASS_AND_TRANSACTION_SEMANTICS=PASS'
echo 'FVQ25_INTERVAL_DIAGNOSTICS_VECTOR_O0_O2=1,3,0,3,3,3,3,0'

echo "FVQ25_FMR14_GATE_SHA256=$(sha256sum "$BUILD/fmr14.txt" | cut -d' ' -f1)"
echo 'FVQ25_PHYSICS_CHANGED=NO'
echo 'FVQ25_NUMERICAL_CONTROLS_CHANGED=NO'
echo 'FVQ25_ACCEPTANCE_CHANGED=NO'
echo 'FVQ25_MASS_REQUIREMENT_RELAXED=NO'
echo 'FVQ25_FPE02_B01_RESOLVED=NO'
echo 'FVQ25_PERTURBED_FPE_WORKLOAD_ADMISSION=NOT_GRANTED'
echo 'FVQ25_PERFORMANCE_POLICY_ADMISSION=NOT_GRANTED'
echo 'FVQ25_FMR14_INTERVAL_DIAGNOSTICS_SCIENTIFIC_NO_CHANGE_GATE PASS'
