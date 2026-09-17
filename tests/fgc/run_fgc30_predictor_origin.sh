#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fgc30-origin-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "FGC30_ORIGIN_FAIL $*" >&2; exit 1; }
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/runtime/mod_groundwater_coupling_contract.f90 -o "$OUT/gw_contract.o" || fail "compile groundwater contract O$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/runtime/mod_modflow6_swap_predictor_response.f90 -o "$OUT/predictor_response.o" || fail "compile predictor response O$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/runtime/mod_modflow6_swap_predictor_origin.f90 -o "$OUT/predictor_origin.o" || fail "compile predictor origin O$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fgc/test_fgc30_predictor_origin.f90 -o "$OUT/test.o" || fail "compile origin oracle O$opt"
  gfortran -O"$opt" "$OUT/gw_contract.o" "$OUT/predictor_response.o" "$OUT/predictor_origin.o" "$OUT/test.o" \
    -o "$OUT/test" || fail "link O$opt"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  for marker in \
    'FGC30_HBOT_START_USES_ACCEPTED_SWAP_HEAD=PASS' \
    'FGC30_ACCEPTED_HEAD_RESIDUAL_PROVENANCE=PASS' \
    'FGC30_UNCOMMITTED_ORIGIN_FAIL_CLOSED=PASS' \
    'FGC30_NONCONSERVATIVE_ORIGIN_FAIL_CLOSED=PASS' \
    'FGC30_PREDICTOR_ORIGIN_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  cat "$OUT/output.txt"
  echo "FGC30_PREDICTOR_ORIGIN_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 semantic drift'
}

git diff --check -- src/runtime/mod_modflow6_swap_predictor_origin.f90 \
  tests/fgc/test_fgc30_predictor_origin.f90 \
  tests/fgc/run_fgc30_predictor_origin.sh

echo 'FGC30_PREDICTOR_ORIGIN_O0_O2_IDENTITY=PASS'
echo 'FGC30_PREDICTOR_ORIGIN_QUALIFICATION=PASS'
