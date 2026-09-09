#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt10-fmr06-compat-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

python3 - <<'PY'
from pathlib import Path
core=Path('src/runtime/mod_fmr_runtime_core.f90').read_text().lower()
test=Path('tests/fmr/test_fmr06_snow_multiswap.f90').read_text().lower()
assert 'integer(int64) :: optional_state_layout_id' in core
assert 'integer(int64) :: numerical_continuation_layout_id' in core
assert 'optional_state_layout_id = 60605' in test
print('FKT10_FMR06_SEPARATE_LAYOUT_AXES_SOURCE_GUARD=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
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
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

run_one() {
  local opt="$1" tag="$2" out="$BUILD/$2"
  mkdir -p "$out"
  local objects=()
  for src in "${MODULE_SRC[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fmr/test_fmr06_snow_multiswap.f90 -o "$out/test.o"
  gfortran "$opt" "${objects[@]}" "$out/test.o" -o "$out/fmr06_snow_multiswap"
  timeout 180s "$out/fmr06_snow_multiswap" > "$out/output.txt" 2>&1 || { cat "$out/output.txt" >&2; exit 1; }
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
    'FMR06_SNOW_MULTISWAP_TEST PASS'; do
    grep -Fq "$marker" "$out/output.txt"
  done
  echo "FKT10_FMR06_COMPAT_${tag}=PASS"
}

run_one -O0 o0
run_one -O2 o2
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FKT10_FMR06_COMPAT_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo 'FKT10_FMR06_OPTIONAL_STATE_COMPAT_REGRESSION PASS'
