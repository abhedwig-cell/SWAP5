#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-gc-rzm06e10-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${RZM06E10_EVIDENCE_DIR:-$ROOT/RZM06E10-EVIDENCE}"
mkdir -p "$BUILD/o0" "$BUILD/o2" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "GC_RZM06E10_GATE_FAIL $*" >&2; exit 1; }

PREREG=2bc1b16f7e4d51e9cbcaa1a6cf16105a57403b9a
PAIR=f01c6330cc1c1a3956889225b7bf59108c4e704a
git merge-base --is-ancestor "$PREREG" HEAD || fail "preregistration not ancestor"
git merge-base --is-ancestor "$PAIR" HEAD || fail "E09 pair authority not ancestor"

python3 tests/research/test_gc_rootzone_memory_rzm06e10_extract.py   --result integration/research/GC_ROOTZONE_MEMORY_RZM06E09_RESULT.json   --output-a "$BUILD/e10-A.txt" --output-b "$BUILD/e10-B.txt"   | tee "$EVIDENCE/origin-extract.txt"
grep -Fq 'GC_RZM06E10_ORIGIN_EXTRACT=PASS' "$EVIDENCE/origin-extract.txt" || fail "origin extraction"

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10 | tee "$EVIDENCE/materialize.txt"
grep -Fq 'F_ROM0_STUB_GEOMETRY_N=16' "$EVIDENCE/materialize.txt" || fail "node count"
grep -Fq 'F_ROM0_STUB_GEOMETRY_DZ_CM=10' "$EVIDENCE/materialize.txt" || fail "dz"

for opt in 0 2; do
  out="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target tests/research/test_gc_rootzone_memory_rzm06e10_probe.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$out" --opt "$opt"
  "$out/rom0_test" "$BUILD/e10-A.txt" "$BUILD/e10-B.txt" > "$EVIDENCE/e10-o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/e10-o$opt.txt" >&2
    fail "E10 executable O$opt"
  }
  cat "$EVIDENCE/e10-o$opt.txt"
  grep -Fq 'GC_RZM06E10_ORDER_INDEPENDENCE=PASS' "$EVIDENCE/e10-o$opt.txt" || fail "order gate O$opt"
  grep -Fq 'GC_RZM06E10_FIXED_HC_PROBE_EXECUTION=PASS' "$EVIDENCE/e10-o$opt.txt" || fail "execution marker O$opt"
done

cmp "$EVIDENCE/e10-o0.txt" "$EVIDENCE/e10-o2.txt" || fail "O0/O2 output drift"
python3 tests/research/analyze_gc_rootzone_memory_rzm06e10.py   --input "$EVIDENCE/e10-o2.txt" --output "$EVIDENCE/result.json" | tee "$EVIDENCE/analysis.txt"
grep -Fq 'GC_RZM06E10_ANALYSIS=PASS' "$EVIDENCE/analysis.txt" || fail "analysis marker"

sha256sum "$EVIDENCE/origin-extract.txt" "$EVIDENCE/e10-o0.txt" "$EVIDENCE/e10-o2.txt"   "$EVIDENCE/analysis.txt" "$EVIDENCE/result.json" > "$EVIDENCE/sha256.txt"
echo 'GC_RZM06E10_O0_O2_IDENTITY=PASS'
echo 'GC_RZM06E10_QUALIFICATION=PASS'
