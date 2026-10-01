#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${TMPDIR:-/tmp}/swap5-perch21-freduq"
rm -rf "$BUILD"; mkdir -p "$BUILD"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all)

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     src/transaction/mod_transaction_reference.f90 -o "$OUT/transaction.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     src/runtime/mod_fmr_macropore_reduction_continuation.f90 -o "$OUT/reduction.o"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/fpm/test_ppa_wu05_perch21_reduction_state_machine.f90 -o "$OUT/pure.o"
  gfortran -O"$opt" "$OUT/reduction.o" "$OUT/pure.o" -o "$OUT/pure"
  "$OUT/pure" | tee "$OUT/pure.txt"
  grep -Fq 'PPA_WU05_PERCH21_PURE_STATE_MACHINE_GATE=PASS' "$OUT/pure.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c     tests/fpm/test_ppa_wu05_perch21_freduq_transaction.f90 -o "$OUT/tx.o"
  gfortran -O"$opt" "$OUT/transaction.o" "$OUT/reduction.o" "$OUT/tx.o" -o "$OUT/tx"
  "$OUT/tx" | tee "$OUT/tx.txt"
  grep -Fq 'PPA_WU05_PERCH21_FREDUQ_TRANSACTION_GATE=PASS' "$OUT/tx.txt"
done

cmp "$BUILD/o0/pure.txt" "$BUILD/o2/pure.txt"
cmp "$BUILD/o0/tx.txt" "$BUILD/o2/tx.txt"
echo "PPA_WU05_PERCH21_FREDUQ_O0_O2_IDENTITY=PASS"
