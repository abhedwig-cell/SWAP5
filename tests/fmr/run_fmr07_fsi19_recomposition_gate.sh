#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="99d96d8a0b4d2752d254fd0f4f3fc1a0f4181dc3"
BUILD="${TMPDIR:-/tmp}/swap5-fmr07-fsi19-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

[[ "$(git merge-base "$BASE" HEAD)" == "$BASE" ]] || {
  echo 'FMR07_LINEAGE FAIL not descended from qualified F-MR06 closeout' >&2; exit 1; }

echo 'FMR07_FMR06_CLOSEOUT_LINEAGE=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FMR07_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

# Exact qualified F-SI19 production closure.
check_blob src/solver/mod_soil_water_solver_contract.f90 4271372085d800fd5da969a2ed073b00422d79c6
check_blob src/solver/mod_reference_richards_workspace.f90 59ef9d037c1875610d45ac83387ebab9e917e0fe
check_blob src/solver/mod_reference_richards_state_binding.f90 e68d88382c6502c571713cc97fddd4e18434e271
check_blob src/solver/mod_b110_default_mvg_provider.f90 97d67eb373073b183be6d1bf5b756ecb5125dde2
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac
check_blob src/solver/mod_b110_root_sink_provider.f90 ef2d2fd883d116c314b98e8f0f14330150b4778a
check_blob src/solver/mod_reference_linear_solver.f90 b292d284e5549049eac1c80df4cc30008154eb96
check_blob src/adapter/mod_reference_richards_legacy_binding.f90 18c59ab9c63d206bf2af3678dacadfc3fd6de94c
check_blob src/legacy/b1_10_port/headcalc.f90 55893f1f5ccba2052ad681743aa155b69f351246
check_blob src/legacy/b1_10_port/soilwater.f90 470bc81a380e114d70fecd75426ec2331c1c9fcc
check_blob tests/fsi/test_fsi19_reference_linear_solver.f90 bf8c9d85c98157d128086d2c2fb20f6129b98e63

echo 'FMR07_FSI19_PRODUCTION_CLOSURE_BLOBS=PASS'

# F-MR06 runtime, transaction and SNOW owner source must remain byte-identical.
check_blob src/process/mod_snow_process.f90 54702d71b4c84dce2842813549bd14c57301a383
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 202ab846cbd30d149d0d450249b3d517e333994f
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 1bb0c6d4683db2729d48de31babcea72bc1a6caf
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob src/transaction/mod_transaction_reference.f90 b1878606ae6cb2b04a7b4b15e3e537deacf4477f
check_blob src/runtime/mod_canonical_contracts.f90 0c2b15fc45011c580384cf6a618e7b378fdccf0a
check_blob src/runtime/mod_canonical_interval_runtime.f90 f2cae79d533343db818c11e0b61b605ac5f6739d

echo 'FMR07_FMR06_RUNTIME_OWNER_BLOBS=PASS'

python3 - <<'PY'
from pathlib import Path
import re, subprocess
base='99d96d8a0b4d2752d254fd0f4f3fc1a0f4181dc3'
changed=sorted(subprocess.check_output(['git','diff','--name-only',base,'HEAD','--','src'],text=True).splitlines())
expected=sorted([
 'src/adapter/mod_reference_richards_legacy_binding.f90',
 'src/legacy/b1_10_port/headcalc.f90',
 'src/legacy/b1_10_port/soilwater.f90',
 'src/solver/mod_b110_default_mvg_provider.f90',
 'src/solver/mod_b110_root_sink_provider.f90',
 'src/solver/mod_b110_source_sink_provider.f90',
 'src/solver/mod_reference_linear_solver.f90',
 'src/solver/mod_reference_richards_state_binding.f90',
 'src/solver/mod_reference_richards_workspace.f90',
 'src/solver/mod_soil_water_solver_contract.f90',
])
assert changed == expected, f'FMR07 unexpected production delta: {changed}'

head=Path('src/legacy/b1_10_port/headcalc.f90').read_text().lower()
workspace=Path('src/solver/mod_reference_richards_workspace.f90').read_text().lower()
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
dispatch=Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text().lower()

assert 'use mod_reference_linear_solver, only: reference_tridag, reference_band_solve' in head
assert 'call reference_tridag(' in head
assert 'call reference_band_solve(' in head
assert not re.search(r'\bcall\s+(tridag|bandec|banbks)\s*\(', head), 'external legacy linear solver call remains in HeadCalc'
for token in ['tridag_gamma', 'allocate(workspace%residual(active_nodes), workspace%delta_head(active_nodes), workspace%tridag_gamma(active_nodes))',
              'workspace%tridag_gamma = 0.0_real64', 'deallocate(workspace%tridag_gamma)',
              'size(workspace%tridag_gamma, kind=int64)']:
    assert token in workspace, f'missing worker-local scratch lifecycle token: {token}'
for forbidden in ['call headcalc(', 'use variables', 'use mod_grid', '!$omp', 'omp_lib', 'parallel do']:
    assert forbidden not in backend, f'F-MR06 backend ownership leak after recomposition: {forbidden}'
for required in ['prepare_snow_outer_event','evaluate_snow_reference_call','snow_event_applied_this_call',
                 'snowfall_external_in','sublimation_external_out','base_top_flux','snow_melt_rate']:
    assert required in backend, f'missing F-MR06 runtime token: {required}'
assert 'call fmr_build_execution_order(columns, order)' in dispatch
assert 'call build_aggregate(columns, diagnostics, batches, aggregate, order)' in dispatch
assert 'call finalize_runtime_diagnostics(results, local_runtime, order)' in dispatch
print('FMR07_MINIMAL_PRODUCTION_SCOPE_AND_ARCHITECTURE=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

# Re-run the exact F-SI19 direct legacy algorithm oracle in the composed tree.
for opt in 0 2; do
  OUT="$BUILD/oracle-o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$OUT" -I "$OUT" \
    src/solver/mod_reference_linear_solver.f90 tests/fsi/test_fsi19_reference_linear_solver.f90 \
    -o "$OUT/test"
  "$OUT/test" > "$OUT/output-a.txt"
  "$OUT/test" > "$OUT/output-b.txt"
  cmp "$OUT/output-a.txt" "$OUT/output-b.txt"
  grep -Fq 'FSI19_DIRECT_REFERENCE_LINEAR_SOLVER_ORACLE PASS' "$OUT/output-a.txt"
  echo "FMR07_FSI19_DIRECT_ORACLE_O${opt}=PASS"
done
cmp "$BUILD/oracle-o0/output-a.txt" "$BUILD/oracle-o2/output-a.txt"
echo 'FMR07_FSI19_DIRECT_ORACLE_O0_O2_IDENTITY=PASS'

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
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

compile_modules() {
  local opt="$1" out="$2" src obj
  mkdir -p "$out"
  : > "$out/objects.list"
  for src in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    printf '%s\n' "$obj" >> "$out/objects.list"
  done
}

run_driver() {
  local opt="$1" out="$2" driver="$3" exe="$4" output="$5"
  local objects=()
  mapfile -t objects < "$out/objects.list"
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$driver" -o "$out/${exe}.o"
  gfortran -O"$opt" "${objects[@]}" "$out/${exe}.o" -o "$out/$exe"
  "$out/$exe" > "$out/$output" 2>&1 || { cat "$out/$output" >&2; exit 1; }
}

for opt in 0 2; do
  OUT="$BUILD/runtime-o$opt"
  compile_modules "$opt" "$OUT"

  run_driver "$opt" "$OUT" tests/fmr/test_fmr06_snow_smoke.f90 snow_smoke snow.txt
  for marker in \
    'FMR06_SNOW_ONE_CALL_DAILY_TRIAL=PASS' \
    'FMR06_SNOW_ROLLBACK=PASS' \
    'FMR06_SNOW_REPLAY_BITWISE=PASS' \
    'FMR06_SNOW_COMMIT=PASS' \
    'FMR06_SNOW_AUTHORITATIVE_MASS_COMPLETE=PASS' \
    'FMR06_SNOW_SUBDAILY_FAIL_CLOSED=PASS' \
    'FMR06_SNOW_MULTIDAY_FAIL_CLOSED=PASS' \
    'FMR06_SNOW_SMOKE_TEST PASS'; do grep -Fq "$marker" "$OUT/snow.txt"; done

  run_driver "$opt" "$OUT" tests/fmr/test_fmr05_single_fmr04_identity.f90 inactive_identity inactive.txt
  for marker in \
    'FMR05_SINGLE_COLUMN_FMR04_ROUTE_IDENTITY=PASS' \
    'FMR05_SINGLE_COLUMN_FMR04_MASS_BITWISE_IDENTITY=PASS' \
    'FMR05_SINGLE_COLUMN_FMR04_COMMITTED_STATE_IDENTITY=PASS'; do grep -Fq "$marker" "$OUT/inactive.txt"; done

  run_driver "$opt" "$OUT" tests/fmr/test_fmr06_snow_multiswap.f90 snow_multiswap multiswap.txt
  for marker in \
    'FMR06_SNOW_BATCH_1=PASS' \
    'FMR06_SNOW_BATCH_2=PASS' \
    'FMR06_SNOW_BATCH_17=PASS' \
    'FMR06_SNOW_BATCH_31=PASS' \
    'FMR06_SNOW_MIXED_ACTIVE_INACTIVE=PASS' \
    'FMR06_SNOW_WARM_MELT_INTERNAL_TRANSFER=PASS' \
    'FMR06_SNOW_RICHARDS_RESTRICTED_EQUILIBRIUM=PASS' \
    'FMR06_SNOW_REVERSE_ORDER_COLUMN_IDENTITY=PASS' \
    'FMR06_SNOW_A_B_A_REPEATABILITY=PASS' \
    'FMR06_SNOW_OPTIONAL_STATE_SCALING=PASS' \
    'FMR06_SNOW_AGGREGATE_MASS=PASS' \
    'FMR06_SNOW_MAX_SIMULTANEOUS_REAL_PHYSICAL_SOLVES=1' \
    'FMR06_SNOW_MULTISWAP_TEST PASS'; do grep -Fq "$marker" "$OUT/multiswap.txt"; done

  cat "$OUT/snow.txt" "$OUT/inactive.txt" "$OUT/multiswap.txt" > "$OUT/all.txt"
  sha256sum "$OUT/all.txt" > "$OUT/all.sha256"
  echo "FMR07_RECOMPOSED_RUNTIME_O${opt}=PASS"
done

cmp "$BUILD/runtime-o0/snow.txt" "$BUILD/runtime-o2/snow.txt"
cmp "$BUILD/runtime-o0/inactive.txt" "$BUILD/runtime-o2/inactive.txt"
cmp "$BUILD/runtime-o0/multiswap.txt" "$BUILD/runtime-o2/multiswap.txt"
echo 'FMR07_RECOMPOSED_RUNTIME_O0_O2_OUTPUT_IDENTITY=PASS'

cat "$BUILD/runtime-o0/snow.txt"
cat "$BUILD/runtime-o0/inactive.txt"
cat "$BUILD/runtime-o0/multiswap.txt"
echo "FMR07_RUNTIME_OUTPUT_SHA256=$(cut -d' ' -f1 "$BUILD/runtime-o0/all.sha256")"
echo 'FMR07_FSI19_RECOMPOSITION_GATE=PASS_ENGINEERING_RUNTIME_RECOMPOSITION'
