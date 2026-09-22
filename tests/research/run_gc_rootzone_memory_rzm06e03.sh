#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PREREG=e6543e57bed84ec22615ea68f14f66ec400362cd
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-gc-rzm06e03-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${RZM06E03_EVIDENCE_DIR:-$ROOT/RZM06E03-EVIDENCE}"
mkdir -p "$BUILD/o0" "$BUILD/o2" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "GC_RZM06E03_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG" HEAD || fail "preregistration not ancestor"

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10 | tee "$EVIDENCE/materialize.txt"

grep -Fq 'F_ROM0_STUB_GEOMETRY_N=16' "$EVIDENCE/materialize.txt" || fail "node count"
grep -Fq 'F_ROM0_STUB_GEOMETRY_DZ_CM=10' "$EVIDENCE/materialize.txt" || fail "dz"

for opt in 0 2; do
  out="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target tests/research/test_gc_rootzone_memory_rzm06e03_expand.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$out" --opt "$opt"
  "$out/rom0_test" > "$EVIDENCE/e03-o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/e03-o$opt.txt" >&2
    fail "E03 executable O$opt"
  }
  cat "$EVIDENCE/e03-o$opt.txt"
  grep -Fq 'GC_RZM06E03_STATE_EXPANSION=PASS' "$EVIDENCE/e03-o$opt.txt" || fail "generation marker O$opt"
done

cmp "$EVIDENCE/e03-o0.txt" "$EVIDENCE/e03-o2.txt" || fail "O0/O2 output drift"
echo 'GC_RZM06E03_O0_O2_IDENTITY=PASS'

python3 tests/research/test_gc_rootzone_memory_rzm06e03_select.py   --o0 "$EVIDENCE/e03-o0.txt" --o2 "$EVIDENCE/e03-o2.txt" | tee "$EVIDENCE/selection.txt"
grep -Fq 'GC_RZM06E03_RESPONSE_BLIND_SELECTION=PASS' "$EVIDENCE/selection.txt" || fail "selector marker"

sha256sum "$EVIDENCE/materialize.txt" "$EVIDENCE/e03-o0.txt" "$EVIDENCE/e03-o2.txt" "$EVIDENCE/selection.txt"   > "$EVIDENCE/sha256.txt"

echo 'GC_RZM06E03_QUALIFICATION=PASS'
