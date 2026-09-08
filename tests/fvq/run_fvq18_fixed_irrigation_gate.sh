#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq18-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

python3 tools/fvq/fvq18_fixed_irrigation_gate.py

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
  mkdir -p "$OUT/oracle" "$OUT/runtime"

  gfortran "${COMMON[@]}" -Werror=compare-reals -O"$opt" -J "$OUT/oracle" -I "$OUT/oracle" \
    -c src/process/mod_irrigation_process.f90 -o "$OUT/oracle/mod_irrigation_process.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT/oracle" -I "$OUT/oracle" \
    tests/fvq/test_fvq18_fixed_irrigation_oracle.f90 "$OUT/oracle/mod_irrigation_process.o" \
    -o "$OUT/oracle/fvq18_oracle"
  "$OUT/oracle/fvq18_oracle" > "$OUT/oracle.txt" 2>&1 || { cat "$OUT/oracle.txt" >&2; exit 1; }
  for marker in \
    'FVQ18_FIXED_INACTIVE_NO_EVENT=PASS' \
    'FVQ18_FIXED_LEGACY_MATCH_BOUNDARY=PASS' \
    'FVQ18_FIXED_SURFACE_ORACLE=PASS' \
    'FVQ18_FIXED_SSDI_TRANSLATION_ORACLE=PASS' \
    'FVQ18_FIXED_TRANSACTION_REPLAY=PASS' \
    'FVQ18_FIXED_EVENT_END_POLICY=PASS' \
    'FVQ18_FIXED_A_B_A=PASS' \
    'FVQ18_FIXED_IRRIGATION_SCIENTIFIC_ORACLE PASS'; do
    grep -Fq "$marker" "$OUT/oracle.txt"
  done

  objects=()
  for src in "${RUNTIME_MODULES[@]}"; do
    obj="$OUT/runtime/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT/runtime" -I "$OUT/runtime" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT/runtime" -I "$OUT/runtime" \
    -c tests/fvq/test_fvq18_ssdi_mass.f90 -o "$OUT/runtime/test_fvq18_ssdi_mass.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/runtime/test_fvq18_ssdi_mass.o" \
    -o "$OUT/runtime/fvq18_ssdi_mass"
  "$OUT/runtime/fvq18_ssdi_mass" > "$OUT/mass.txt" 2>&1 || { cat "$OUT/mass.txt" >&2; exit 1; }
  grep -Fq 'FVQ18_SSDI_AUTHORITATIVE_EXACTLY_ONCE=PASS' "$OUT/mass.txt"
  grep -Fq 'FVQ18_SSDI_BALANCED_RICHARDS_IDENTITY=PASS' "$OUT/mass.txt"
  grep -Fq 'FVQ18_SSDI_MASS_COMPLETE=PASS' "$OUT/mass.txt"
  grep -Fq 'FVQ18_SSDI_INDEPENDENT_MASS_VERIFIER PASS' "$OUT/mass.txt"

  # Independently replay the admitted F-MR06 one-call-daily snow smoke fixture.
  # Do not invoke the F-PM03 engineering qualification script.
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT/runtime" -I "$OUT/runtime" \
    -c tests/fmr/test_fmr06_snow_smoke.f90 -o "$OUT/runtime/test_fmr06_snow_smoke.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/runtime/test_fmr06_snow_smoke.o" \
    -o "$OUT/runtime/fmr06_snow_smoke"
  "$OUT/runtime/fmr06_snow_smoke" > "$OUT/snow.txt" 2>&1 || { cat "$OUT/snow.txt" >&2; exit 1; }
  grep -Fq 'FMR06_SNOW_ONE_CALL_DAILY_TRIAL=PASS' "$OUT/snow.txt"
  grep -Fq 'FMR06_SNOW_ROLLBACK=PASS' "$OUT/snow.txt"
  grep -Fq 'FMR06_SNOW_REPLAY_BITWISE=PASS' "$OUT/snow.txt"
  grep -Fq 'FMR06_SNOW_COMMIT=PASS' "$OUT/snow.txt"
  grep -Fq 'FMR06_SNOW_AUTHORITATIVE_MASS_COMPLETE=PASS' "$OUT/snow.txt"
  grep -Fq 'FMR06_SNOW_SMOKE_TEST PASS' "$OUT/snow.txt"

  cat "$OUT/oracle.txt" "$OUT/mass.txt" "$OUT/snow.txt" > "$OUT/output.txt"
  sha256sum "$OUT/output.txt" > "$OUT/output.sha256"
  echo "FVQ18_O${opt}=PASS"
done

cmp "$BUILD/o0/oracle.txt" "$BUILD/o2/oracle.txt"
echo 'FVQ18_ORACLE_O0_O2_OUTPUT_IDENTITY=PASS'
cmp "$BUILD/o0/mass.txt" "$BUILD/o2/mass.txt"
echo 'FVQ18_MASS_O0_O2_OUTPUT_IDENTITY=PASS'
cmp "$BUILD/o0/snow.txt" "$BUILD/o2/snow.txt"
echo 'FVQ18_SNOW_O0_O2_OUTPUT_IDENTITY=PASS'
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FVQ18_FULL_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/oracle.txt"
cat "$BUILD/o0/mass.txt"
cat "$BUILD/o0/snow.txt"
echo "FVQ18_OUTPUT_SHA256=$(cut -d' ' -f1 "$BUILD/o0/output.sha256")"
echo 'FVQ18_GATE PASS_QUALIFIED_FPM03_RESTRICTED_FIXED_EVENT_IRRIGATION_SCIENTIFIC_ADMISSION'
