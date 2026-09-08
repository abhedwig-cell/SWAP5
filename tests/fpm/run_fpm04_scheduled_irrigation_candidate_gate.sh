#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpm04-scheduled-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

python3 tools/fpm/fpm04_scheduled_irrigation_candidate_gate.py

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
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/process/mod_irrigation_process.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

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
    tests/fpm/test_fpm03_fixed_event_process.f90 \
    "$OUT/mod_irrigation_process.o" "$OUT/mod_process_hydraulic_view.o" "$OUT/mod_soil_water_solver_contract.o" \
    -o "$OUT/fpm03_fixed_regression"
  "$OUT/fpm03_fixed_regression" > "$OUT/fixed.txt" 2>&1 || { cat "$OUT/fixed.txt" >&2; exit 1; }
  grep -Fq 'FPM03_FIXED_EVENT_PROCESS_TEST PASS' "$OUT/fixed.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    tests/fpm/test_fpm03_time_tolerance.f90 \
    "$OUT/mod_irrigation_process.o" "$OUT/mod_process_hydraulic_view.o" "$OUT/mod_soil_water_solver_contract.o" \
    -o "$OUT/fpm03_time_regression"
  "$OUT/fpm03_time_regression" > "$OUT/time.txt" 2>&1 || { cat "$OUT/time.txt" >&2; exit 1; }
  grep -Fq 'FPM03_TIME_TOLERANCE_TEST PASS' "$OUT/time.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    tests/fpm/test_fpm04_scheduled_irrigation_process.f90 \
    "$OUT/mod_irrigation_process.o" "$OUT/mod_process_hydraulic_view.o" "$OUT/mod_soil_water_solver_contract.o" \
    -o "$OUT/fpm04_scheduled"
  "$OUT/fpm04_scheduled" > "$OUT/scheduled.txt" 2>&1 || { cat "$OUT/scheduled.txt" >&2; exit 1; }
  for marker in \
    'FPM04_SCHEDULED_INACTIVE=PASS' \
    'FPM04_SELECTION_OPPORTUNITY=PASS' \
    'FPM04_TCS7_TRIGGER=PASS' \
    'FPM04_DCS2_INTERPOLATION=PASS' \
    'FPM04_AFGEN_RESTRICTED=PASS' \
    'FPM04_FAIL_CLOSED_INPUTS=PASS' \
    'FPM04_SINGLE_NODE_SSDI_MASS=PASS' \
    'FPM04_CONTINUATION_NO_RETRIGGER=PASS' \
    'FPM04_SPLIT_NO_MUTATION=PASS' \
    'FPM04_ROLLBACK_REPLAY=PASS' \
    'FPM04_A_B_A=PASS' \
    'FPM04_SCHEDULED_PROCESS_TEST PASS'; do
      grep -Fq "$marker" "$OUT/scheduled.txt"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    tests/fpm/test_fpm04_ssdi_route_bridge.f90 \
    "$OUT/mod_irrigation_process.o" "$OUT/mod_process_hydraulic_view.o" "$OUT/mod_soil_water_solver_contract.o" \
    -o "$OUT/fpm04_route_bridge"
  "$OUT/fpm04_route_bridge" > "$OUT/bridge.txt" 2>&1 || { cat "$OUT/bridge.txt" >&2; exit 1; }
  grep -Fq 'FPM04_SCHEDULED_FIXED_SINGLE_NODE_SOURCE_IDENTITY=PASS' "$OUT/bridge.txt"
  grep -Fq 'FPM04_SSDI_ROUTE_BRIDGE_TEST PASS' "$OUT/bridge.txt"

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
    -c tests/fpm/test_fpm03_ssdi_runtime_mass.f90 -o "$OUT/runtime/test_fpm03_ssdi_runtime_mass.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/runtime/test_fpm03_ssdi_runtime_mass.o" \
    -o "$OUT/runtime/fpm03_ssdi_runtime_mass"
  "$OUT/runtime/fpm03_ssdi_runtime_mass" > "$OUT/runtime_mass.txt" 2>&1 || { cat "$OUT/runtime_mass.txt" >&2; exit 1; }
  grep -Fq 'FPM03_SSDI_AUTHORITATIVE_MASS_EXACTLY_ONCE=PASS' "$OUT/runtime_mass.txt"
  grep -Fq 'FPM03_SSDI_REAL_PHYSICS_STATE_IDENTITY=PASS' "$OUT/runtime_mass.txt"
  grep -Fq 'FPM03_SSDI_RUNTIME_MASS_TEST PASS' "$OUT/runtime_mass.txt"

  cat "$OUT/fixed.txt" "$OUT/time.txt" "$OUT/scheduled.txt" "$OUT/bridge.txt" "$OUT/runtime_mass.txt" > "$OUT/output.txt"
  sha256sum "$OUT/output.txt" > "$OUT/output.sha256"
  echo "FPM04_CANDIDATE_O${opt}=PASS"
done

cmp "$BUILD/o0/fixed.txt" "$BUILD/o2/fixed.txt"
echo 'FPM04_FIXED_REGRESSION_O0_O2_OUTPUT_IDENTITY=PASS'
cmp "$BUILD/o0/time.txt" "$BUILD/o2/time.txt"
echo 'FPM04_TIME_REGRESSION_O0_O2_OUTPUT_IDENTITY=PASS'
cmp "$BUILD/o0/scheduled.txt" "$BUILD/o2/scheduled.txt"
echo 'FPM04_SCHEDULED_O0_O2_OUTPUT_IDENTITY=PASS'
cmp "$BUILD/o0/bridge.txt" "$BUILD/o2/bridge.txt"
echo 'FPM04_ROUTE_BRIDGE_O0_O2_OUTPUT_IDENTITY=PASS'
cmp "$BUILD/o0/runtime_mass.txt" "$BUILD/o2/runtime_mass.txt"
echo 'FPM04_RUNTIME_MASS_O0_O2_OUTPUT_IDENTITY=PASS'
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPM04_FULL_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/fixed.txt"
cat "$BUILD/o0/time.txt"
cat "$BUILD/o0/scheduled.txt"
cat "$BUILD/o0/bridge.txt"
cat "$BUILD/o0/runtime_mass.txt"
echo "FPM04_CANDIDATE_OUTPUT_SHA256=$(cut -d' ' -f1 "$BUILD/o0/output.sha256")"
echo 'FPM04_SCHEDULED_CANDIDATE_GATE PASS_STRUCTURAL_CANDIDATE_REQUIRES_INDEPENDENT_FVQ'
