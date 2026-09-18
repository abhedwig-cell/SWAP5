#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${TMPDIR:-/tmp}/swap5-fgc43-$$"
mkdir -p "$BUILD"
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
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_swap_transaction_participant.f90
  tests/fgc/test_fgc43_production_swap_participant.f90
)
for opt in 0 2; do
  D="$BUILD/o$opt"; mkdir -p "$D"
  gfortran "${COMMON[@]}" -O"$opt" -J "$D" -I "$D" "${SOURCES[@]}" -o "$D/test"
  "$D/test" > "$D/output.txt"
  grep -Fq 'F-GC43 PRODUCTION SWAP PARTICIPANT GATE PASS' "$D/output.txt"
  grep '^FGC43_' "$D/output.txt" > "$D/stable.txt"
  echo "FGC43_O${opt}=PASS"
done
diff -u "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt"
cat "$BUILD/o0/stable.txt"
echo 'FGC43_O0_O2_IDENTITY=PASS'
