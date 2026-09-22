#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ORIGIN_A="${1:?origin A file required}"
ORIGIN_B="${2:?origin B file required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-gc-rzm06d04-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${GC_RZM06D04_EVIDENCE_DIR:-$BUILD/evidence}"
mkdir -p "$BUILD/o0" "$BUILD/o2" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "GC_RZM06D04_GATE_FAIL $*" >&2; exit 1; }

PREREG=8de97e12dc9cc50caab3d8808e88caf3db1599c3
git merge-base --is-ancestor "$PREREG" HEAD || fail "preregistration not ancestor"

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10 | tee "$BUILD/materialize.txt"
grep -Fq 'F_ROM0_STUB_GEOMETRY_N=16' "$BUILD/materialize.txt" || fail "node count"
grep -Fq 'F_ROM0_STUB_GEOMETRY_DZ_CM=10' "$BUILD/materialize.txt" || fail "dz"

for opt in 0 2; do
  out="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target tests/research/test_gc_rootzone_memory_rzm06d04_continuation.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$out" --opt "$opt"
  "$out/rom0_test" "$ORIGIN_A" "$ORIGIN_B" > "$EVIDENCE/d04-o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/d04-o$opt.txt" >&2
    fail "continuation executable O$opt"
  }
  grep -Fq 'GC_RZM06D04_LOCAL_CONTINUATION_MAP=PASS' "$EVIDENCE/d04-o$opt.txt" || fail "map marker O$opt"
done

cmp "$EVIDENCE/d04-o0.txt" "$EVIDENCE/d04-o2.txt" || fail "O0/O2 output drift"
python3 tests/research/analyze_gc_rootzone_memory_rzm06d04.py   --input "$EVIDENCE/d04-o2.txt" --output "$EVIDENCE/RZM06D04_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
grep -Fq 'GC_RZM06D04_STATE_ONLY_SELECTION=PASS' "$EVIDENCE/analyzer.txt" || fail "analysis marker"
sha256sum "$EVIDENCE/d04-o0.txt" "$EVIDENCE/d04-o2.txt" "$EVIDENCE/RZM06D04_RESULT.json"
echo 'GC_RZM06D04_O0_O2_IDENTITY=PASS'
echo 'GC_RZM06D04_QUALIFICATION=PASS'
