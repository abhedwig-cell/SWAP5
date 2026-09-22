#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG=c11c08282a3abc9b1beee3002f5a9a01df58d95f
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-gc-rzm06e01-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${RZM06E01_EVIDENCE_DIR:-$ROOT/RZM06E01-EVIDENCE}"
mkdir -p "$BUILD/o0" "$BUILD/o2" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "GC_RZM06E01_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG" HEAD || fail "preregistration not ancestor"

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10 | tee "$EVIDENCE/materialize.txt"

grep -Fq 'F_ROM0_STUB_GEOMETRY_N=16' "$EVIDENCE/materialize.txt" || fail "node count"
grep -Fq 'F_ROM0_STUB_GEOMETRY_DZ_CM=10' "$EVIDENCE/materialize.txt" || fail "dz"

for opt in 0 2; do
  out="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target tests/research/test_gc_rootzone_memory_rzm06e01_expand.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$out" --opt "$opt"
  "$out/rom0_test" > "$EVIDENCE/e01-o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/e01-o$opt.txt" >&2
    fail "E01 executable O$opt"
  }
  cat "$EVIDENCE/e01-o$opt.txt"
  grep -Fq 'GC_RZM06E01_ZERO_DIVERGENCE_GENERATION=PASS' "$EVIDENCE/e01-o$opt.txt" || fail "generation marker O$opt"
done

cmp "$EVIDENCE/e01-o0.txt" "$EVIDENCE/e01-o2.txt" || fail "O0/O2 output drift"
sha256sum "$EVIDENCE/e01-o0.txt" "$EVIDENCE/e01-o2.txt" | tee "$EVIDENCE/sha256.txt"
echo 'GC_RZM06E01_O0_O2_IDENTITY=PASS'

python3 tests/research/test_gc_rootzone_memory_rzm06e01_select.py   --o0 "$EVIDENCE/e01-o0.txt" --o2 "$EVIDENCE/e01-o2.txt" | tee "$EVIDENCE/selection.txt"
grep -Fq 'GC_RZM06E01_RESPONSE_BLIND_SELECTION=PASS' "$EVIDENCE/selection.txt" || fail "selector marker"

echo 'GC_RZM06E01_QUALIFICATION=PASS'
