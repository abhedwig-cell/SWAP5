#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt22-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail(){ echo "FKT22_GATE_FAIL $*" >&2; exit 1; }

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

# F-KT22 is a publication-boundary capability. The admitted F-KT21 mutable
# composer and immutable result remain its authority; this gate may not replace
# them with a second directional-response contract.
grep -Fq 'accepted_trajectory_direction_result_t' src/runtime/mod_canonical_contracts.f90 || fail 'typed KT21 result missing from canonical contracts'
grep -Fq 'accepted_trajectory_direction_snapshot' src/runtime/mod_canonical_contracts.f90 || fail 'model snapshot hook missing'
grep -Fq 'model%accepted_trajectory_direction_snapshot' src/runtime/mod_canonical_interval_runtime.f90 || fail 'whole-window publication call missing'
if grep -Eq 'canonical_directional_response_t|finite.?difference|perturb.*solve' src/runtime/mod_canonical_contracts.f90 src/runtime/mod_canonical_interval_runtime.f90 tests/fkt/test_fkt22_canonical_trajectory_exposure.f90; then
  fail 'competing generic response or FD construction detected'
fi

run_one(){
  local opt="$1"
  local tag="$2"
  local out="$BUILD/$tag"
  mkdir -p "$out"

  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/solver/mod_soil_water_accepted_step_direction_contract.f90 -o "$out/step_contract.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 -o "$out/trajectory.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_accepted_trajectory_directional_publication.f90 -o "$out/publication.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/transaction/mod_transaction_reference.f90 -o "$out/transaction.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/runtime/mod_canonical_contracts.f90 -o "$out/contracts.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c src/runtime/mod_canonical_interval_runtime.f90 -o "$out/runtime.o"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c tests/fkt/test_fkt22_canonical_trajectory_exposure.f90 -o "$out/test.o"
  gfortran "$opt" "$out/step_contract.o" "$out/trajectory.o" "$out/publication.o" "$out/transaction.o" "$out/contracts.o" "$out/runtime.o" "$out/test.o" -o "$out/test_fkt22"
  "$out/test_fkt22" | tee "$out/output.txt"

  grep -Fq 'FKT22_CANONICAL_TRAJECTORY_EXPOSURE=PASS' "$out/output.txt" || fail "canonical exposure missing $tag"
  grep -Fq 'FKT22_FCI66_SPLIT_WHOLE_WINDOW_PROVENANCE=PASS' "$out/output.txt" || fail "whole-window provenance missing $tag"
  grep -Fq 'FKT22_PARTIAL_WINDOW_NO_PUBLICATION=PASS' "$out/output.txt" || fail "partial-window guard missing $tag"
  grep -Fq 'FKT22_DEFAULT_OFF_IDENTITY=PASS' "$out/output.txt" || fail "default-off identity missing $tag"
  grep '^FKT22_' "$out/output.txt" > "$out/stable.txt"
  echo "FKT22_OPT_PASS=$tag"
}

run_one -O0 o0
run_one -O2 o2
cmp "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt" || fail 'O0/O2 marker drift'

echo 'FKT22_CANONICAL_BOUNDARY_GATE=PASS'
echo 'FKT22_PRODUCTION_FMR_TRANSPORT=NOT_YET_QUALIFIED'
echo 'FKT22_GATE PASS'