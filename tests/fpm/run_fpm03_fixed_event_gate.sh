#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm03-fixed-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE="afb450bed0d53d20af2157d0b164d16a9e0a04cd"

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FPM03_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/process/mod_irrigation_process.f90 bbce5e21eb8e02775e68163a453cf0d88832bc3d
check_blob src/solver/mod_process_hydraulic_view.f90 d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
check_blob src/runtime/mod_fmr_process_hydraulic_view_binding.f90 37f5968ffe00b1ff56f824f77ab94d3825171acf
check_blob src/process/mod_snow_process.f90 54702d71b4c84dce2842813549bd14c57301a383
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 202ab846cbd30d149d0d450249b3d517e333994f
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 1bb0c6d4683db2729d48de31babcea72bc1a6caf
check_blob src/kernel/mod_kernel_transactions.f90 9f7c16e71cfb93b57f796ba759bae73824318a2f
check_blob src/solver/mod_soil_water_solver_contract.f90 57b51997d28807fbe2da1b2e5bf654fc4167adb9
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac

python3 - <<'PY'
import subprocess
changed = subprocess.check_output([
    'git','diff','--name-only','afb450bed0d53d20af2157d0b164d16a9e0a04cd','HEAD','--','src'
], text=True).splitlines()
expected = ['src/process/mod_irrigation_process.f90']
assert changed == expected, f'unexpected F-PM03 production source changes: {changed}'
print('FPM03_EXACT_PRODUCTION_SOURCE_SCOPE PASS')
PY

python3 tools/fpm/fpm03_fixed_event_gate.py

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
RUNTIME_MODULES=(
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
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/process/mod_irrigation_process.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT/process" "$OUT/runtime"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT/process" -I "$OUT/process" \
    src/process/mod_irrigation_process.f90 tests/fpm/test_fpm03_fixed_event_process.f90 \
    -o "$OUT/process/fpm03_process"
  "$OUT/process/fpm03_process" > "$OUT/process.txt" 2>&1 || { cat "$OUT/process.txt" >&2; exit 1; }
  for marker in \
    'FPM03_FIXED_INACTIVE=PASS' \
    'FPM03_FIXED_NO_TRIGGER=PASS' \
    'FPM03_FIXED_SURFACE=PASS' \
    'FPM03_FIXED_SSDI=PASS' \
    'FPM03_FIXED_CONTINUATION=PASS' \
    'FPM03_FIXED_SPLIT_NO_MUTATION=PASS' \
    'FPM03_FIXED_ROLLBACK_REPLAY=PASS' \
    'FPM03_FIXED_A_B_A=PASS' \
    'FPM03_FIXED_B110_EQUATION_IDENTITY=PASS' \
    'FPM03_FIXED_EVENT_PROCESS_TEST PASS'; do
      grep -Fq "$marker" "$OUT/process.txt"
  done

  objects=()
  for src in "${RUNTIME_MODULES[@]}"; do
    obj="$OUT/runtime/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT/runtime" -I "$OUT/runtime" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT/runtime" -I "$OUT/runtime" \
    -c tests/fpm/test_fpm03_ssdi_runtime_mass.f90 -o "$OUT/runtime/test_fpm03_ssdi_runtime_mass.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/runtime/test_fpm03_ssdi_runtime_mass.o" \
    -o "$OUT/runtime/fpm03_ssdi_runtime_mass"
  "$OUT/runtime/fpm03_ssdi_runtime_mass" > "$OUT/runtime.txt" 2>&1 || { cat "$OUT/runtime.txt" >&2; exit 1; }
  grep -Fq 'FPM03_SSDI_AUTHORITATIVE_MASS_EXACTLY_ONCE=PASS' "$OUT/runtime.txt"
  grep -Fq 'FPM03_SSDI_REAL_PHYSICS_STATE_IDENTITY=PASS' "$OUT/runtime.txt"
  grep -Fq 'FPM03_SSDI_RUNTIME_MASS_TEST PASS' "$OUT/runtime.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT/runtime" -I "$OUT/runtime" \
    -c tests/fmr/test_fmr06_snow_smoke.f90 -o "$OUT/runtime/test_fmr06_snow_smoke.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/runtime/test_fmr06_snow_smoke.o" \
    -o "$OUT/runtime/fmr06_snow_smoke"
  "$OUT/runtime/fmr06_snow_smoke" > "$OUT/snow.txt" 2>&1 || { cat "$OUT/snow.txt" >&2; exit 1; }
  grep -Fq 'FMR06_SNOW_ROLLBACK=PASS' "$OUT/snow.txt"
  grep -Fq 'FMR06_SNOW_REPLAY_BITWISE=PASS' "$OUT/snow.txt"
  grep -Fq 'FMR06_SNOW_COMMIT=PASS' "$OUT/snow.txt"
  grep -Fq 'FMR06_SNOW_AUTHORITATIVE_MASS_COMPLETE=PASS' "$OUT/snow.txt"
  grep -Fq 'FMR06_SNOW_SMOKE_TEST PASS' "$OUT/snow.txt"

  cat "$OUT/process.txt" "$OUT/runtime.txt" "$OUT/snow.txt" > "$OUT/output.txt"
  sha256sum "$OUT/output.txt" > "$OUT/output.sha256"
  echo "FPM03_FIXED_O${opt}=PASS"
done

cmp "$BUILD/o0/process.txt" "$BUILD/o2/process.txt"
echo 'FPM03_FIXED_PROCESS_O0_O2_OUTPUT_IDENTITY=PASS'
cmp "$BUILD/o0/runtime.txt" "$BUILD/o2/runtime.txt"
echo 'FPM03_FIXED_SSDI_RUNTIME_O0_O2_OUTPUT_IDENTITY=PASS'
cmp "$BUILD/o0/snow.txt" "$BUILD/o2/snow.txt"
echo 'FPM03_FIXED_FMR06_SNOW_O0_O2_OUTPUT_IDENTITY=PASS'
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPM03_FIXED_FULL_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/process.txt"
cat "$BUILD/o0/runtime.txt"
cat "$BUILD/o0/snow.txt"
echo "FPM03_FIXED_OUTPUT_SHA256=$(cut -d' ' -f1 "$BUILD/o0/output.sha256")"
echo 'FPM03_FIXED_EVENT_GATE PASS_STRUCTURAL_CANDIDATE_REQUIRES_INDEPENDENT_FVQ'
