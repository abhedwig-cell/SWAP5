#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq20-scheduled-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

python3 tools/fvq/fvq20_scheduled_irrigation_gate.py

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
  src/process/mod_irrigation_process.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

FVQ18_QUALIFIED_COMMIT=973d2b9d38917a4a459f51b6b46dd51cfd9690c4
# Replay the independently qualified F-VQ18 oracle from its immutable closeout commit.
git show "${FVQ18_QUALIFIED_COMMIT}:tests/fvq/test_fvq18_fixed_irrigation_oracle.f90" \
  > "$BUILD/test_fvq18_fixed_irrigation_oracle.f90"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT" "$OUT/runtime"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/mod_soil_water_solver_contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/solver/mod_process_hydraulic_view.f90 -o "$OUT/mod_process_hydraulic_view.o"
  gfortran "${COMMON[@]}" -Werror=compare-reals -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/process/mod_irrigation_process.f90 -o "$OUT/mod_irrigation_process.o"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    tests/fvq/test_fvq20_scheduled_irrigation_oracle.f90 \
    "$OUT/mod_irrigation_process.o" "$OUT/mod_process_hydraulic_view.o" "$OUT/mod_soil_water_solver_contract.o" \
    -o "$OUT/fvq20_oracle"
  "$OUT/fvq20_oracle" > "$OUT/oracle.txt" 2>&1 || { cat "$OUT/oracle.txt" >&2; exit 1; }
  for marker in \
    'FVQ20_EXPLICIT_SELECTION_NONMIDNIGHT=PASS' \
    'FVQ20_TCS7_TRIGGER_ORACLE=PASS' \
    'FVQ20_DCS2_TRANSLATED_DEPTH_ORACLE=PASS' \
    'FVQ20_SINGLE_NODE_SSDI_ORACLE=PASS' \
    'FVQ20_AFGEN_BOUNDARY_ORACLE=PASS' \
    'FVQ20_PARTIAL_TABLE_FAIL_CLOSED=PASS' \
    'FVQ20_CONTINUATION_NO_SELECTION_REQUIRED=PASS' \
    'FVQ20_COMPLETION_NO_IMPLICIT_RETRIGGER=PASS' \
    'FVQ20_SPLIT_NO_MUTATION=PASS' \
    'FVQ20_ROLLBACK_REPLAY=PASS' \
    'FVQ20_A_B_A=PASS' \
    'FVQ20_SCHEDULED_IRRIGATION_SCIENTIFIC_ORACLE PASS'; do
      grep -Fq "$marker" "$OUT/oracle.txt"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    "$BUILD/test_fvq18_fixed_irrigation_oracle.f90" \
    "$OUT/mod_irrigation_process.o" "$OUT/mod_process_hydraulic_view.o" "$OUT/mod_soil_water_solver_contract.o" \
    -o "$OUT/fvq18_regression"
  "$OUT/fvq18_regression" > "$OUT/fixed_regression.txt" 2>&1 || { cat "$OUT/fixed_regression.txt" >&2; exit 1; }
  grep -Fq 'FVQ18_FIXED_IRRIGATION_SCIENTIFIC_ORACLE PASS' "$OUT/fixed_regression.txt"

  objects=()
  for src in "${RUNTIME_MODULES[@]}"; do
    obj="$OUT/runtime/$(basename "${src%.*}").o"
    extra=()
    if [[ "$src" == "src/process/mod_irrigation_process.f90" ]]; then
      extra=(-Werror=compare-reals)
    fi
    gfortran "${COMMON[@]}" "${extra[@]}" -O"$opt" -J "$OUT/runtime" -I "$OUT/runtime" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT/runtime" -I "$OUT/runtime" \
    -c tests/fvq/test_fvq20_scheduled_ssdi_runtime_mass.f90 -o "$OUT/runtime/test_fvq20_scheduled_ssdi_runtime_mass.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/runtime/test_fvq20_scheduled_ssdi_runtime_mass.o" \
    -o "$OUT/runtime/fvq20_scheduled_mass"
  "$OUT/runtime/fvq20_scheduled_mass" > "$OUT/runtime_mass.txt" 2>&1 || { cat "$OUT/runtime_mass.txt" >&2; exit 1; }
  grep -Fq 'FVQ20_COMMITTED_HYDRAULIC_VIEW_BINDING=PASS' "$OUT/runtime_mass.txt"
  grep -Fq 'FVQ20_SCHEDULED_AUTHORITATIVE_MASS_EXACTLY_ONCE=PASS' "$OUT/runtime_mass.txt"
  grep -Fq 'FVQ20_SCHEDULED_REAL_PHYSICS_STATE_IDENTITY=PASS' "$OUT/runtime_mass.txt"
  grep -Fq 'FVQ20_SCHEDULED_SSDI_RUNTIME_MASS PASS' "$OUT/runtime_mass.txt"

  cat "$OUT/oracle.txt" "$OUT/fixed_regression.txt" "$OUT/runtime_mass.txt" > "$OUT/output.txt"
  sha256sum "$OUT/output.txt" > "$OUT/output.sha256"
  echo "FVQ20_O${opt}=PASS"
done

cmp "$BUILD/o0/oracle.txt" "$BUILD/o2/oracle.txt"
echo 'FVQ20_ORACLE_O0_O2_OUTPUT_IDENTITY=PASS'
cmp "$BUILD/o0/fixed_regression.txt" "$BUILD/o2/fixed_regression.txt"
echo 'FVQ20_FVQ18_REGRESSION_O0_O2_OUTPUT_IDENTITY=PASS'
cmp "$BUILD/o0/runtime_mass.txt" "$BUILD/o2/runtime_mass.txt"
echo 'FVQ20_RUNTIME_MASS_O0_O2_OUTPUT_IDENTITY=PASS'
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FVQ20_FULL_O0_O2_OUTPUT_IDENTITY=PASS'

cat "$BUILD/o0/oracle.txt"
cat "$BUILD/o0/fixed_regression.txt"
cat "$BUILD/o0/runtime_mass.txt"
echo "FVQ20_OUTPUT_SHA256=$(cut -d' ' -f1 "$BUILD/o0/output.sha256")"
echo 'FVQ20_SCHEDULED_IRRIGATION_GATE PASS_INDEPENDENT_RESTRICTED_TCS7_DCS2_SINGLE_NODE_SSDI'
