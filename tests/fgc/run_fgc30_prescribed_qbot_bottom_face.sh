#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fgc30-bottom-face-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "FGC30_BOTTOM_FACE_FAIL $*" >&2; exit 1; }
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/runtime/mod_groundwater_coupling_contract.f90 -o "$OUT/gw_contract.o" || fail "compile groundwater contract O$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90 -o "$OUT/bottom_face.o" || fail "compile bottom-face materializer O$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/fgc/test_fgc30_prescribed_qbot_bottom_face.f90 -o "$OUT/test.o" || fail "compile bottom-face oracle O$opt"
  gfortran -O"$opt" "$OUT/gw_contract.o" "$OUT/bottom_face.o" "$OUT/test.o" -o "$OUT/test" || fail "link O$opt"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  for marker in \
    'FGC30_QBOT_BOTTOM_FACE_DARCY_IDENTITY=PASS' \
    'FGC30_QBOT_BOTTOM_FACE_DATUM_TRANSLATION=PASS' \
    'FGC30_QBOT_BOTTOM_FACE_DIRECTIONAL_CHAIN_RULE=PASS' \
    'FGC30_QBOT_BOTTOM_FACE_CENTERED_FD_ORACLE=PASS' \
    'FGC30_QBOT_BOTTOM_FACE_FREE_DRAINAGE_IDENTITY=PASS' \
    'FGC30_QBOT_BOTTOM_FACE_FAIL_CLOSED=PASS' \
    'FGC30_QBOT_BOTTOM_FACE_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  cat "$OUT/output.txt"
  echo "FGC30_QBOT_BOTTOM_FACE_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 semantic drift'
}

git diff --check -- src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90 \
  tests/fgc/test_fgc30_prescribed_qbot_bottom_face.f90 \
  tests/fgc/run_fgc30_prescribed_qbot_bottom_face.sh

echo 'FGC30_QBOT_BOTTOM_FACE_O0_O2_IDENTITY=PASS'
echo 'FGC30_QBOT_BOTTOM_FACE_QUALIFICATION=PASS'
