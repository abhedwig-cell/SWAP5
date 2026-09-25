#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-zero-waste01-hctx01-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

COMMON=(-std=f2008 -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -ffree-line-length-none)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT"     src/transaction/mod_transaction_reference.f90     tests/transaction/test_transaction_attempt_context.f90     -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt"
  grep -Fq 'FPE_ZERO_WASTE01_HCTX01_CAPTURE_COUNT PASS' "$OUT/out.txt"
  grep -Fq 'FPE_ZERO_WASTE01_HCTX02_ZERO_CONTEXT PASS' "$OUT/out.txt"
  grep -Fq 'FCI08_TRANSACTION_ATTEMPT_CONTEXT PASS' "$OUT/out.txt"
  echo "FPE_ZERO_WASTE01_HCTX01_O${opt}=PASS"
done

cmp "$BUILD/o0/out.txt" "$BUILD/o2/out.txt"
cat "$BUILD/o0/out.txt"
echo 'FPE_ZERO_WASTE01_HCTX01_O0_O2_IDENTITY=PASS'
echo 'FPE_ZERO_WASTE01_HCTX01=PASS'
