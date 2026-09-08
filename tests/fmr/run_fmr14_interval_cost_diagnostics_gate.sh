#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr14-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"; rm -f "$ROOT/tests/fmr/.fmr14_fmr09_gate.sh" "$ROOT/tests/fmr/.fmr14_fmr12_gate.sh"' EXIT
cd "$ROOT"

FMR13=985058c0261d284424432a65bded16b7fc9107cb
FPE02=2c28a4366440885faedbe2fbe3ce56104d82692e
KERNEL_POST=af42c7d51ef545e20c76d3000f1ed1493690d68e
RUNTIME_POST=7a60f8b8d18672098fed1c6890a95aac738ed21d
RUNTIME_PRE=1bb0c6d4683db2729d48de31babcea72bc1a6caf
HEADCALC=1ab0a7dec7a1ca785c01540ebe1c6f3342a1773b
LINEAR_SOLVER=b292d284e5549049eac1c80df4cc30008154eb96
WORKSPACE=178d3289e09583c256b1aa400407d468d9c18e68
FMR12_ADAPTER=9105126c219cbd06fadfa7757ba95d7b7bd0499b

expected_src=$'src/kernel/mod_kernel_transactions.f90\nsrc/runtime/mod_fmr_serialized_multiswap_runtime.f90'
actual_src="$(git diff --name-only "$FMR13" -- src | sort)"
[[ "$actual_src" == "$expected_src" ]] || {
  echo 'FMR14_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf 'expected:\n%s\nactual:\n%s\n' "$expected_src" "$actual_src" >&2
  exit 1
}
[[ "$(git rev-parse HEAD:src/kernel/mod_kernel_transactions.f90)" == "$KERNEL_POST" ]]
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == "$RUNTIME_POST" ]]
[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" == "$HEADCALC" ]]
[[ "$(git rev-parse HEAD:src/solver/mod_reference_linear_solver.f90)" == "$LINEAR_SOLVER" ]]
[[ "$(git rev-parse HEAD:src/solver/mod_reference_richards_workspace.f90)" == "$WORKSPACE" ]]
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90)" == "$FMR12_ADAPTER" ]]
[[ "$(git rev-parse "$FPE02:src/kernel/mod_kernel_transactions.f90")" == "$KERNEL_POST" ]]
echo 'FMR14_SOURCE_DELTA_EXACTLY_TWO_OBSERVER_PATHS=PASS'
echo 'FMR14_KERNEL_EXACT_FPE02_QUALIFIED_POSTIMAGE=PASS'

python3 tools/fmr14_materialize.py verify

# Prove the evolved F-MR13 runtime differs only by the already-qualified
# observer field declarations and straight-through assignments.
python3 - <<'PY'
from pathlib import Path
import subprocess
base = subprocess.check_output(['git','show','985058c0261d284424432a65bded16b7fc9107cb:src/runtime/mod_fmr_serialized_multiswap_runtime.f90'], text=True)
cur = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text()
fields = """    integer :: accepted_substeps = 0
    integer :: solver_nonlinear_iterations = 0
    integer :: solver_internal_retries = 0
    integer :: solver_headcalc_calls = 0
    integer :: solver_jacobian_builds = 0
    integer :: solver_linear_solves = 0
    integer :: solver_backtracking_attempts = 0
    integer :: solver_alternative_solver_calls = 0
"""
assign = """    output%accepted_substeps = kernel_diag%accepted_substeps
    output%solver_nonlinear_iterations = kernel_diag%nonlinear_iterations
    output%solver_internal_retries = kernel_diag%internal_retries
    output%solver_headcalc_calls = kernel_diag%headcalc_calls
    output%solver_jacobian_builds = kernel_diag%jacobian_builds
    output%solver_linear_solves = kernel_diag%linear_solves
    output%solver_backtracking_attempts = kernel_diag%backtracking_attempts
    output%solver_alternative_solver_calls = kernel_diag%alternative_solver_calls
"""
assert cur.count(fields) == 1
assert cur.count(assign) == 1
normalized = cur.replace(fields,'',1).replace(assign,'',1)
assert normalized == base
for field in ['accepted_substeps','solver_nonlinear_iterations','solver_internal_retries','solver_headcalc_calls',
              'solver_jacobian_builds','solver_linear_solves','solver_backtracking_attempts','solver_alternative_solver_calls']:
    assert cur.count('output%'+field+' = kernel_diag%') == 1
print('FMR14_RUNTIME_NORMALIZES_BITWISE_TO_FMR13_AFTER_OBSERVER_DELTA_REMOVAL=PASS')
print('FMR14_OBSERVER_ASSIGNMENTS_EXACTLY_ONCE=PASS')
PY

# Re-run F-MR09's authoritative mass/rollback/scientific regression against the
# current source postimage. Historical gate source remains immutable; only its
# source locks/compile order are adapted in a temporary copy.
export FMR14_KERNEL_POST="$KERNEL_POST"
export FMR14_RUNTIME_POST="$RUNTIME_POST"
export FMR14_HEADCALC="$HEADCALC"
python3 - <<'PY'
from pathlib import Path
import os
src=Path('tests/fmr/run_fmr09_root_sink_runtime_gate.sh').read_text()
replacements={
 'check_blob src/legacy/b1_10_port/headcalc.f90 420fe2996199e6d3f162b7669957e1a95919f353':
   'check_blob src/legacy/b1_10_port/headcalc.f90 '+os.environ['FMR14_HEADCALC'],
 'check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 1bb0c6d4683db2729d48de31babcea72bc1a6caf':
   'check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 '+os.environ['FMR14_RUNTIME_POST'],
 'check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f':
   'check_blob src/kernel/mod_kernel_transactions.f90 '+os.environ['FMR14_KERNEL_POST'],
}
for old,new in replacements.items():
    assert src.count(old)==1, old
    src=src.replace(old,new,1)
marker='  src/solver/mod_reference_richards_workspace.f90\n'
assert src.count(marker)==1
src=src.replace(marker,'  src/solver/mod_reference_linear_solver.f90\n'+marker,1)
Path('tests/fmr/.fmr14_fmr09_gate.sh').write_text(src)
PY
bash tests/fmr/.fmr14_fmr09_gate.sh | tee "$BUILD/fmr09.txt"
grep -Fq 'FMR09_HARD_MASS_BALANCE=PASS' "$BUILD/fmr09.txt"
grep -Fq 'FMR09_ROOT_SINK_EXACTLY_ONCE=PASS' "$BUILD/fmr09.txt"
grep -Fq 'FMR09_SNOW_REGRESSION=PASS' "$BUILD/fmr09.txt"
grep -Fq 'FMR09_FVQ20_SCHEDULED_IRRIGATION_ORACLE_REPLAY=PASS' "$BUILD/fmr09.txt"
grep -Fq 'FMR09_FVQ18_FIXED_IRRIGATION_ORACLE_REPLAY=PASS' "$BUILD/fmr09.txt"
grep -Fq 'FMR09_FULL_O0_O2_OUTPUT_IDENTITY=PASS' "$BUILD/fmr09.txt"
grep -Fq 'FMR09_OUTPUT_SHA256=920ec4876c528dc3af9f5de4616f50a1214b3c87e999d9261bf57a348cf2f08d' "$BUILD/fmr09.txt"
echo 'FMR14_FMR09_AUTHORITATIVE_MASS_TRANSACTION_REPLAY=PASS'
echo 'FMR14_FMR09_HISTORICAL_OUTPUT_HASH_PRESERVED=PASS'

# Re-run F-MR12/F-MR10 wrapper equivalence. The only production delta from the
# F-MR13 base is now the two observer paths.
python3 - <<'PY'
from pathlib import Path
import os
src=Path('tests/fmr/run_fmr12_crop_root_uptake_input_adapter_gate.sh').read_text()
assert src.count('BASE=b6a667035d5e900a7e2209e76491c1817ffd2043')==1
assert src.count('NEW_SRC=src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90')==1
src=src.replace('BASE=b6a667035d5e900a7e2209e76491c1817ffd2043','BASE=985058c0261d284424432a65bded16b7fc9107cb',1)
src=src.replace('NEW_SRC=src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90',
                "NEW_SRC=$'src/kernel/mod_kernel_transactions.f90\\nsrc/runtime/mod_fmr_serialized_multiswap_runtime.f90'",1)
replacements={
 'check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 1bb0c6d4683db2729d48de31babcea72bc1a6caf':
   'check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 '+os.environ['FMR14_RUNTIME_POST'],
 'check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f':
   'check_blob src/kernel/mod_kernel_transactions.f90 '+os.environ['FMR14_KERNEL_POST'],
}
for old,new in replacements.items():
    assert src.count(old)==1, old
    src=src.replace(old,new,1)
marker='  src/solver/mod_reference_richards_workspace.f90\n'
assert src.count(marker)==1
src=src.replace(marker,'  src/solver/mod_reference_linear_solver.f90\n'+marker,1)
Path('tests/fmr/.fmr14_fmr12_gate.sh').write_text(src)
PY
bash tests/fmr/.fmr14_fmr12_gate.sh | tee "$BUILD/fmr12.txt"
grep -Fq 'FMR12_WRAPPER_BITWISE_EQUIVALENT_TO_DIRECT_FMR10=PASS' "$BUILD/fmr12.txt"
grep -Fq 'FMR12_A_B_A_DETERMINISM=PASS' "$BUILD/fmr12.txt"
grep -Fq 'FMR12_O0_O2_OUTPUT_IDENTITY=PASS' "$BUILD/fmr12.txt"
grep -Fq 'FMR12_CROP_ROOT_UPTAKE_INPUT_ADAPTER_GATE PASS' "$BUILD/fmr12.txt"
grep -Fq 'FMR12_OUTPUT_SHA256=5e70234b073d7d865075ec8d315755426b47d825539e0a0d74df6c122e733e29' "$BUILD/fmr12.txt"
echo 'FMR14_FMR12_FMR10_RUNTIME_REGRESSION=PASS'
echo 'FMR14_FMR12_HISTORICAL_OUTPUT_HASH_PRESERVED=PASS'

# Current observer surface must be populated on the accepted F-MR09 route.
# Use a temporary source copy solely to print/assert the newly public counters.
python3 - <<'PY'
from pathlib import Path
src=Path('tests/fmr/test_fmr09_root_sink_runtime.f90').read_text()
anchor="""  write(*,'(A,1X,ES24.16,1X,ES24.16)') 'FMR09_BALANCED_MASS=', result_balanced(1)%mass%residual, &
       result_balanced(1)%mass%total_out
"""
insert=anchor+"""  call require(result_control(1)%accepted_substeps == 1, 'observer accepted substeps')
  call require(result_control(1)%solver_nonlinear_iterations >= result_control(1)%solver_iterations, &
       'aggregate nonlinear iterations dominate latest solver observation')
  call require(result_control(1)%solver_nonlinear_iterations > 0, 'observer nonlinear iterations populated')
  call require(result_control(1)%solver_headcalc_calls > 0, 'observer HeadCalc calls populated')
  call require(result_control(1)%solver_jacobian_builds > 0, 'observer Jacobian builds populated')
  call require(result_control(1)%solver_linear_solves > 0, 'observer linear solves populated')
  call require(result_control(1)%solver_backtracking_attempts > 0, 'observer backtracking populated')
  write(*,'(A,8(1X,I0))') 'FMR14_INTERVAL_COST_DIAGNOSTICS=', result_control(1)%accepted_substeps, &
       result_control(1)%solver_nonlinear_iterations, result_control(1)%solver_internal_retries, &
       result_control(1)%solver_headcalc_calls, result_control(1)%solver_jacobian_builds, &
       result_control(1)%solver_linear_solves, result_control(1)%solver_backtracking_attempts, &
       result_control(1)%solver_alternative_solver_calls
  write(*,'(A)') 'FMR14_INTERVAL_COST_DIAGNOSTICS_RUNTIME_SURFACE=PASS'
"""
assert src.count(anchor)==1
Path('/tmp/fmr14_diag_test.f90').write_text(src.replace(anchor,insert,1))
PY
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/process/mod_irrigation_process.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)
for opt in 0 2; do
  OUT="$BUILD/diag-o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"; gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"; objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c /tmp/fmr14_diag_test.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  grep -Fq 'FMR14_INTERVAL_COST_DIAGNOSTICS_RUNTIME_SURFACE=PASS' "$OUT/output.txt"
  echo "FMR14_DIAGNOSTICS_SURFACE_O${opt}=PASS"
done
cmp "$BUILD/diag-o0/output.txt" "$BUILD/diag-o2/output.txt"
grep -F 'FMR14_INTERVAL_COST_DIAGNOSTICS=' "$BUILD/diag-o0/output.txt"
echo 'FMR14_DIAGNOSTICS_SURFACE_O0_O2_IDENTITY=PASS'

# Historical gate sources themselves must remain untouched.
git diff --exit-code -- tests/fmr/run_fmr09_root_sink_runtime_gate.sh tests/fmr/run_fmr12_crop_root_uptake_input_adapter_gate.sh

echo 'FMR14_PHYSICS_CHANGED=NO'
echo 'FMR14_NUMERICAL_CONTROLS_CHANGED=NO'
echo 'FMR14_ACCEPTANCE_OR_TRANSACTION_DECISION_CHANGED=NO'
echo 'FMR14_MASS_REQUIREMENT_RELAXED=NO'
echo 'FMR14_FPE02_B01_RESOLVED=NO'
echo 'FMR14_INTERVAL_COST_DIAGNOSTICS_OWNER_COMPOSITION_GATE PASS'
