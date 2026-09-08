#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr07-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=ffab7d705928170db3e76a5d346caafeb560e605

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FMR07_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

# Exact F-MR06 production postimage remains immutable.
check_blob src/process/mod_snow_process.f90 54702d71b4c84dce2842813549bd14c57301a383
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 202ab846cbd30d149d0d450249b3d517e333994f
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 1bb0c6d4683db2729d48de31babcea72bc1a6caf
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob src/transaction/mod_transaction_reference.f90 b1878606ae6cb2b04a7b4b15e3e537deacf4477f
check_blob src/runtime/mod_canonical_contracts.f90 0c2b15fc45011c580384cf6a618e7b378fdccf0a
check_blob src/runtime/mod_canonical_interval_runtime.f90 f2cae79d533343db818c11e0b61b605ac5f6739d
check_blob src/solver/mod_soil_water_solver_contract.f90 57b51997d28807fbe2da1b2e5bf654fc4167adb9
check_blob src/solver/mod_reference_richards_workspace.f90 93285b2ca24669494c93c00403e3783fca6758e9
check_blob src/solver/mod_reference_richards_state_binding.f90 e68d88382c6502c571713cc97fddd4e18434e271
check_blob src/solver/mod_b110_default_mvg_provider.f90 97d67eb373073b183be6d1bf5b756ecb5125dde2
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac
check_blob src/adapter/mod_reference_richards_legacy_binding.f90 eb4b74ee422bc331ed3d6abaa40dd9f85b2551c0
check_blob src/legacy/b1_10_port/headcalc.f90 be5978827095445b15de7baf607728792de6a366
check_blob tests/fmr/test_fmr06_snow_multiswap.f90 ed4b742b76e97ff0ad27b386850c1d093e4f03d1

# Exact qualified F-SI17 module is materialized, not reimplemented.
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
check_blob src/runtime/mod_fmr_process_hydraulic_view_binding.f90 37f5968ffe00b1ff56f824f77ab94d3825171acf

python3 - <<'PY'
import subprocess
changed = set(subprocess.check_output([
    'git','diff','--name-only','ffab7d705928170db3e76a5d346caafeb560e605','HEAD','--','src'
], text=True).splitlines())
expected = {
    'src/solver/mod_process_hydraulic_view.f90',
    'src/runtime/mod_fmr_process_hydraulic_view_binding.f90',
}
assert changed == expected, f'unexpected F-MR07 production source delta: {sorted(changed)}'
print('FMR07_EXACT_SOURCE_SCOPE PASS')
PY

python3 tools/fmr/fmr07_committed_process_hydraulic_view_gate.py

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
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fmr/test_fmr07_committed_process_hydraulic_view.f90 -o "$OUT/test_fmr07.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_fmr07.o" -o "$OUT/fmr07"
  "$OUT/fmr07" > "$OUT/fmr07.txt" 2>&1 || { cat "$OUT/fmr07.txt" >&2; exit 1; }
  grep -Fq 'FMR07_COMMITTED_PROCESS_HYDRAULIC_VIEW PASS' "$OUT/fmr07.txt"

  # Replay the exact F-MR06 full snow MultiSWAP fixture on the unchanged F-MR06 production blobs.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fmr/test_fmr06_snow_multiswap.f90 -o "$OUT/test_fmr06.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test_fmr06.o" -o "$OUT/fmr06_replay"
  "$OUT/fmr06_replay" > "$OUT/fmr06.txt" 2>&1 || { cat "$OUT/fmr06.txt" >&2; exit 1; }
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
      grep -Fq "$marker" "$OUT/fmr06.txt"
  done
  echo "FMR07_O${opt}=PASS"
done

cmp "$BUILD/o0/fmr07.txt" "$BUILD/o2/fmr07.txt"
cmp "$BUILD/o0/fmr06.txt" "$BUILD/o2/fmr06.txt"

echo 'FMR07_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'FMR07_FMR06_REPLAY_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/fmr07.txt"
echo 'FMR07_FMR06_FULL_SNOW_REPLAY=PASS'
echo 'FMR07_GATE PASS'
