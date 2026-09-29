#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-ppa-wu04c-retry-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT

fail() { echo "PPA_WU04C_RETRY_GATE_FAIL $*" >&2; exit 1; }
cd "$ROOT"

MODULES=(
  src/transaction/mod_transaction_reference.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_vonhhbraden_source_window_progress.f90
  src/runtime/mod_ppa_wu04c_runtime_publication.f90
  src/process/mod_vonhhbraden_interception.f90
  src/process/mod_gash_interception.f90
)
COMMON=(-std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -ffree-line-length-none \
  -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  objects=()
  for source in "${MODULES[@]}"; do
    object="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$object"
    objects+=("$object")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fmr/test_fmr18_accepted_commit_receipt.f90 -o "$OUT/test.o"
  objects+=("$OUT/test.o")
  gfortran -O"$opt" "${objects[@]}" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "O$opt executable"; }
  for marker in \
    'PPA_WU04C_REJECTED_RETRY_NO_PROGRESS=PASS' \
    'PPA_WU04C_CHANGED_DT_ACCEPTED_REPLAY=PASS' \
    'PPA_WU04C_SOURCE_WINDOW_CLOSED_EXACTLY=PASS' \
    'FMR18_PREVALIDATION_REJECTION_IS_NONMUTATING_AND_REPLAYABLE=PASS'; do
    grep -Fq "$marker" "$OUT/out.txt" || fail "missing O$opt marker: $marker"
  done
done

cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt" || fail 'O0/O2 transcript mismatch'
cat "$BUILD/o2/out.txt"
echo 'PPA_WU04C_RETRY_RESTART_O0_O2_IDENTITY=PASS'
