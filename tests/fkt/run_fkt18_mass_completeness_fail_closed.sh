#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fkt18-mass-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail() { echo "FKT18_MASS_GATE_FAIL:$*" >&2; exit 1; }

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace)
SOURCES=(
  src/transaction/mod_transaction_reference.f90
  tests/fkt/test_fkt18_mass_completeness_fail_closed.f90
)
MARKERS=(
  FKT18_INCOMPLETE_ZERO_RESIDUAL_FAIL_CLOSED=PASS
  FKT18_RETRY_EXHAUSTION_AND_STATE_IMMUTABILITY=PASS
  FKT18_NONZERO_MISSING_MASK_FAIL_CLOSED=PASS
  FKT18_COMPLETE_LEDGER_WITHIN_TOLERANCE_ACCEPTS=PASS
  FKT18_COMPLETE_LEDGER_OUTSIDE_TOLERANCE_REJECTS=PASS
  FKT18_ALTERNATIVE_SOLVER_INCOMPLETE_LEDGER_FAIL_CLOSED=PASS
  FKT18_COMPLETE_MODEL_CERTIFICATE_ACCEPTS=PASS
  FKT18_NONFINITE_MASS_FAIL_CLOSED=PASS
  FKT18_MASS_COMPLETENESS_FAIL_CLOSED_ORACLE=PASS
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
  gfortran "${FLAGS[@]}" -O"$opt" "${objects[@]}" -o "$out/test_fkt18_mass"
  "$out/test_fkt18_mass" > "$out/output.txt"
  for marker in "${MARKERS[@]}"; do
    grep -Fqx "$marker" "$out/output.txt" || fail "O${opt}:missing:$marker"
  done
  cat "$out/output.txt"
  echo "FKT18_MASS_COMPLETENESS_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail 'O0/O2 output differs'
echo 'FKT18_MASS_COMPLETENESS_O0_O2_IDENTITY=PASS'
echo 'FKT18_MASS_COMPLETENESS_OWNER_GATE=PASS'
