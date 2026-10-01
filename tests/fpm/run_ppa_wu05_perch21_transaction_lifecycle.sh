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
done

cmp "$BUILD/o0/perch21.txt" "$BUILD/o2/perch21.txt"
echo "PPA_WU05_PERCH21_O0_O2_IDENTITY=PASS"
echo "PPA_WU05_PERCH21_CURRENT_TRANSACTION_PRESERVATION=PASS"
