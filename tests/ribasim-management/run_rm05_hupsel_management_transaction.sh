#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-rm05-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/process/mod_tcs1_dcs2_sprinkling_irrigation_process.f90
  src/process/mod_rutter_interception_process.f90
  src/runtime/mod_fmr_hupsel_management_transaction.f90
)
for OPT in 0 2; do
  OUT="$BUILD/o$OPT"
  pushd "$OUT" >/dev/null
  for src in "${SOURCES[@]}"; do
    gfortran "${COMMON[@]}" -O"$OPT" -J . -I . -c "$ROOT/$src"
  done
  gfortran "${COMMON[@]}" -O"$OPT" -J . -I . "$ROOT/tests/ribasim-management/test_rm05_hupsel_management_transaction.f90" ./*.o -o test
  ./test > output.txt 2>&1
  popd >/dev/null
  grep -Fq 'RM05_HUPSEL_MANAGEMENT_TRANSACTION_GATE PASS' "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; exit 1; }
  echo "RM05_O${OPT}=PASS"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'RM05_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
