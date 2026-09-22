#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-gc-rzm06c01-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "GC_RZM06C01_GATE_FAIL $*" >&2; exit 1; }

PREREG=11ae66fb732e404cf9f51391c693a1db21e2470a
git merge-base --is-ancestor "$PREREG" HEAD || fail "preregistration not ancestor"

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10 | tee "$BUILD/materialize.txt"

grep -Fq 'F_ROM0_STUB_GEOMETRY_N=16' "$BUILD/materialize.txt" || fail "node count materialization"
grep -Fq 'F_ROM0_STUB_GEOMETRY_DZ_CM=10' "$BUILD/materialize.txt" || fail "dz materialization"

for opt in 0 2; do
  out="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target tests/research/test_gc_rootzone_memory_rzm06c01_carrier.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$out" --opt "$opt"
  "$out/rom0_test" > "$BUILD/c01-o$opt.txt" 2>&1 || {
    cat "$BUILD/c01-o$opt.txt" >&2
    fail "carrier executable O$opt"
  }
  cat "$BUILD/c01-o$opt.txt"
  grep -Fq 'GC_RZM06C01_16NODE_FIXED_HEAD_CARRIER=PASS' "$BUILD/c01-o$opt.txt" || fail "PASS marker O$opt"
  grep -Fq 'RZM06C01_CARRIER|N=16|DZ_CM=10.000000000000000|ROOT_NODES=3' "$BUILD/c01-o$opt.txt" || fail "geometry marker O$opt"
done

cmp "$BUILD/c01-o0.txt" "$BUILD/c01-o2.txt" || fail "O0/O2 output drift"
sha256sum "$BUILD/c01-o0.txt" "$BUILD/c01-o2.txt"
echo 'GC_RZM06C01_O0_O2_IDENTITY=PASS'
echo 'GC_RZM06C01_CARRIER_QUALIFICATION=PASS'
