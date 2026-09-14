#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap431-eb-r06-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FMR28_REF=origin/qualification/f-vq46-fmr28-reference-et-root-uptake-execution
FMR28_TEST=tests/fmr/test_fmr28_reference_et_root_uptake_execution.f90
FMR28_TEST_BLOB=78c6048c39c4d558bdf52123bf3854034847b1a2
CURRENT_COMPOSITION=src/runtime/mod_fmr_reference_et_root_uptake_composition.f90
CURRENT_COMPOSITION_BLOB=8ed7610144700f58d0b89482925471fcb2ff7d69
CURRENT_ROOT_PROCESS=src/process/mod_root_water_uptake_process.f90
CURRENT_ROOT_PROCESS_BLOB=e6134587cf3c0164bbe09f2f4c87aef6886aaeb3
CURRENT_ET_BINDING=src/runtime/mod_fmr_reference_et_demand_binding.f90
CURRENT_ET_BINDING_BLOB=8c679f911c9a82c498258224d83f5fce3cb09163

git cat-file -e "$FMR28_REF^{commit}"
test "$(git rev-parse "$FMR28_REF:$FMR28_TEST")" = "$FMR28_TEST_BLOB"
test "$(git hash-object "$CURRENT_COMPOSITION")" = "$CURRENT_COMPOSITION_BLOB"
test "$(git hash-object "$CURRENT_ROOT_PROCESS")" = "$CURRENT_ROOT_PROCESS_BLOB"
test "$(git hash-object "$CURRENT_ET_BINDING")" = "$CURRENT_ET_BINDING_BLOB"
echo 'EB_R06_FMR28_ORACLE_PINNED=PASS'
echo 'EB_R06_CURRENT_ET_ROOT_BLOBS_PINNED=PASS'

git show "$FMR28_REF:$FMR28_TEST" > "$BUILD/test_fmr28_current_replay.f90"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  tests/empirical_baseline/mod_eb_r06_minimal_b110_state.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_root_water_uptake_process.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/runtime/mod_fmr_root_uptake_process_binding.f90
  src/crop/mod_crop_root_uptake_input_contract.f90
  src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90
  src/process/mod_reference_et_demand_process.f90
  src/runtime/mod_fmr_reference_et_demand_binding.f90
  src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90
  src/runtime/mod_fmr_reference_et_root_uptake_composition.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -Wno-error=compare-reals -Wno-error=unused-dummy-argument \
      -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -Wno-error=unused-dummy-argument \
    -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/test_fmr28_current_replay.f90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  timeout 120s "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  grep -Fq 'FMR28_EXPLICIT_FCI29_FMR12_FMR10_CHAIN_BITWISE_IDENTITY=PASS' "$OUT/output.txt"
  grep -Fq 'FMR28_STALE_INCOMING_PTRA_CANNOT_AFFECT_ROOT_UPTAKE=PASS' "$OUT/output.txt"
  grep -Fq 'FMR28_UPSTREAM_ET_REJECTION_BLOCKS_ROOT_EXECUTION=PASS' "$OUT/output.txt"
  grep -Fq 'FMR28_INVALID_ROOT_GEOMETRY_BLOCKS_ROOT_EXECUTION=PASS' "$OUT/output.txt"
  grep -Fq 'FMR28_INACTIVE_CROP_DEPENDENCY_FREE_ZERO_ROUTE=PASS' "$OUT/output.txt"
  grep -Fq 'FMR28_COMMITTED_STATE_READ_ONLY=PASS' "$OUT/output.txt"
  grep -Fq 'FMR28_STATELESS_A_B_A_IDENTITY=PASS' "$OUT/output.txt"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'EB_R06_ET_ROOT_COMPOSITION_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "EB_R06_COMPOSITION_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'EB_R06_CURRENT_CANONICAL_ET_ROOT_COMPOSITION_REPLAY PASS'
