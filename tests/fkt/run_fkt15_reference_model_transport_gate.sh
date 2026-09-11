#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fkt15-reference-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail() { echo "FKT15_REFERENCE_RUNNER_FAIL $*" >&2; exit 1; }

[[ "$(git hash-object src/adapter/mod_soil_water_transaction_result_bridge.f90)" == \
   ba7547ec4c39f61c4724ed146e2b1ba9daf4baba ]] || fail 'F-KT14 mapper blob drift'
grep -Fq 'call map_soil_water_interface_sensitivity_to_trial' src/adapter/mod_b1_10_reference_model.f90 || \
  fail 'reference model does not call exact F-KT14 mapper'
grep -Fq 'if (self%worker%soil_water_trial%typed_accepted) then' src/adapter/mod_b1_10_reference_model.f90 || \
  fail 'accepted-only guard missing'
echo 'FKT15_REFERENCE_TRANSPORT_SOURCE_GUARD=PASS'

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  tests/fkt/fkt15_reference_model_stubs.f90
  src/adapter/mod_soil_water_transaction_result_bridge.f90
  src/adapter/mod_b1_10_reference_model.f90
  tests/fkt/test_fkt15_reference_model_transport.f90
)
for opt in 0 2; do
  out="$BUILD/o$opt"
  mkdir -p "$out"
  objects=()
  for src in "${SOURCES[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${FLAGS[@]}" -O"$opt" -J"$out" -I"$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${FLAGS[@]}" -O"$opt" "${objects[@]}" -o "$out/test_fkt15_reference"
  "$out/test_fkt15_reference" > "$out/output.txt"
  for marker in \
    FKT15_REFERENCE_ACCEPTED_FKT14_TRANSPORT=PASS \
    FKT15_REFERENCE_REJECTED_STALE_EXCLUSION=PASS \
    FKT15_REFERENCE_DIRECT_FALLBACK_NO_SENSITIVITY=PASS \
    FKT15_REFERENCE_MODEL_TRANSPORT_GATE=PASS; do
    grep -Fq "$marker" "$out/output.txt" || fail "O${opt} missing $marker"
  done
  cat "$out/output.txt"
  echo "FKT15_REFERENCE_TRANSPORT_O${opt}=PASS"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail 'reference transport O0/O2 output differs'
echo 'FKT15_REFERENCE_TRANSPORT_O0_O2_IDENTITY=PASS'
echo 'FKT15_REFERENCE_MODEL_TRANSPORT_RUNNER=PASS'
