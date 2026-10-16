#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-timearch05-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 tests/fpe/guard_fpe_timearch05_source.py

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror)
for OPT in 0 2; do
  OUT="$BUILD/o$OPT"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$OPT" -J "$OUT" -I "$OUT"     -c src/transaction/mod_transaction_reference.f90 -o "$OUT/transaction.o"
  gfortran "${COMMON[@]}" -O"$OPT" -J "$OUT" -I "$OUT"     -c tests/fpe/test_fpe_timearch05_retry_ownership.f90 -o "$OUT/test.o"
  gfortran -O"$OPT" "$OUT/transaction.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" | tee "$OUT/output.txt"
  grep -q '^F_PE_TIMEARCH05=PASS$' "$OUT/output.txt"
  echo "F_PE_TIMEARCH05_O${OPT}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  exit 1
}
echo F_PE_TIMEARCH05_O0_O2_IDENTITY=PASS
