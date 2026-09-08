#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr09-root-replay-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

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
  src/solver/mod_b110_root_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
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
    -c tests/fmr/test_fmr09_root_sink_transaction_replay.f90 -o "$OUT/replay.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/replay.o" -o "$OUT/replay"
  "$OUT/replay" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  for marker in \
    'FMR09_HETEROGENEOUS_ROOT_TRANSACTION_FIXTURE=PASS' \
    'FMR09_ROOT_ROLLBACK_REPLAY=PASS' \
    'FMR09_ROOT_A_B_A_IDENTITY=PASS' \
    'FMR09_ROOT_TRANSACTION_HARD_MASS=PASS' \
    'FMR09_ROOT_TRANSACTION_REPLAY_TEST PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FMR09_ROOT_TRANSACTION_REPLAY_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FMR09_ROOT_TRANSACTION_REPLAY_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo 'FMR09_ROOT_TRANSACTION_REPLAY_GATE PASS'
