#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi19-linear-solver-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

[[ "$(git hash-object src/solver/mod_reference_linear_solver.f90)" == 'b292d284e5549049eac1c80df4cc30008154eb96' ]] || {
  echo 'FSI19_LINEAR_SOLVER_BLOB_LOCK FAIL' >&2; exit 1; }
[[ "$(git hash-object tests/fsi/test_fsi19_reference_linear_solver.f90)" == "$(git rev-parse HEAD:tests/fsi/test_fsi19_reference_linear_solver.f90)" ]] || {
  echo 'FSI19_DIRECT_ORACLE_DIRTY FAIL' >&2; exit 1; }

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    src/solver/mod_reference_linear_solver.f90 tests/fsi/test_fsi19_reference_linear_solver.f90 \
    -o "$OUT/test"
  "$OUT/test" > "$OUT/run-a.txt"
  "$OUT/test" > "$OUT/run-b.txt"
  cmp "$OUT/run-a.txt" "$OUT/run-b.txt"
  grep -Fq 'FSI19_TRIDAG_SUCCESS_N1=PASS_BITWISE' "$OUT/run-a.txt"
  grep -Fq 'FSI19_TRIDAG_SUCCESS_N7=PASS_BITWISE' "$OUT/run-a.txt"
  grep -Fq 'FSI19_TRIDAG_IERROR_1000=PASS' "$OUT/run-a.txt"
  grep -Fq 'FSI19_TRIDAG_IERROR_1002=PASS' "$OUT/run-a.txt"
  grep -Fq 'FSI19_BAND_N4_FORCE_PIVOT_T=PASS_BITWISE_PADDED_ORACLE' "$OUT/run-a.txt"
  grep -Fq 'FSI19_BAND_N5_FORCE_PIVOT_T=PASS_BITWISE_PADDED_ORACLE' "$OUT/run-a.txt"
  grep -Fq 'FSI19_DIRECT_REFERENCE_LINEAR_SOLVER_ORACLE PASS' "$OUT/run-a.txt"
  echo "FSI19_DIRECT_ORACLE_O${opt}=PASS"
done
cmp "$BUILD/o0/run-a.txt" "$BUILD/o2/run-a.txt"
echo 'FSI19_DIRECT_ORACLE_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/run-a.txt"
echo 'FSI19_REFERENCE_LINEAR_SOLVER_GATE=PASS_SOURCE_BOUND_LEGACY_ORACLE'
