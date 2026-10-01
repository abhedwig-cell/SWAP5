#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${TMPDIR:-/tmp}/swap5-perch21-lifecycle"
rm -rf "$BUILD"; mkdir -p "$BUILD"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all)

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     src/transaction/mod_transaction_reference.f90 -o "$OUT/transaction.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/fpm/test_ppa_wu05_perch21_transaction_lifecycle.f90 -o "$OUT/perch21.o"
  gfortran -O"$opt" "$OUT/transaction.o" "$OUT/perch21.o" -o "$OUT/perch21"
  "$OUT/perch21" | tee "$OUT/perch21.txt"
  grep -Fq 'PPA_WU05_PERCH21_TRANSACTION_LIFECYCLE_GATE=PASS' "$OUT/perch21.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/transaction/test_transaction_reference.f90 -o "$OUT/reference_test.o"
  gfortran -O"$opt" "$OUT/transaction.o" "$OUT/reference_test.o" -o "$OUT/reference_test"
  "$OUT/reference_test" | tee "$OUT/reference.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/transaction/test_transaction_attempt_context.f90 -o "$OUT/context_test.o"
  gfortran -O"$opt" "$OUT/transaction.o" "$OUT/context_test.o" -o "$OUT/context_test"
  "$OUT/context_test" | tee "$OUT/context.txt"
done

cmp "$BUILD/o0/perch21.txt" "$BUILD/o2/perch21.txt"
cmp "$BUILD/o0/reference.txt" "$BUILD/o2/reference.txt"
cmp "$BUILD/o0/context.txt" "$BUILD/o2/context.txt"
echo "PPA_WU05_PERCH21_O0_O2_IDENTITY=PASS"
echo "PPA_WU05_PERCH21_CURRENT_TRANSACTION_PRESERVATION=PASS"
