#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${TMPDIR:-/tmp}/swap5-perch20"
rm -rf "$BUILD"; mkdir -p "$BUILD"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace)
for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT"     src/transaction/mod_transaction_reference.f90     tests/fpm/test_ppa_wu05_perch20_transaction_retry_feedback.f90 -o "$OUT/test"
  "$OUT/test" | tee "$OUT/out.txt"
  grep -Fq 'PPA_WU05_PERCH20_TRANSACTION_PROTOCOL_GATE=PASS' "$OUT/out.txt"
done
cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt"

# Preserve existing transaction behavior.
bash tests/transaction/run_a23bl_gate.sh
gfortran "${COMMON[@]}" -O0 -J "$BUILD/context"   src/transaction/mod_transaction_reference.f90 tests/transaction/test_transaction_attempt_context.f90   -o "$BUILD/context_test"
"$BUILD/context_test"

echo "PPA_WU05_PERCH20_O0_O2_AND_PRESERVATION=PASS"
