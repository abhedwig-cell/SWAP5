#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
STATE_FILE="${1:?audit-state file required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-gc-rzm06d02-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "GC_RZM06D02_GATE_FAIL $*" >&2; exit 1; }

PREREG=bde3f52447c8c2c27f81f2fc4f74a923169ca2ae
git merge-base --is-ancestor "$PREREG" HEAD || fail "preregistration not ancestor"

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10 | tee "$BUILD/materialize.txt"
grep -Fq 'F_ROM0_STUB_GEOMETRY_N=16' "$BUILD/materialize.txt" || fail "node count"
grep -Fq 'F_ROM0_STUB_GEOMETRY_DZ_CM=10' "$BUILD/materialize.txt" || fail "dz"

for opt in 0 2; do
  out="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target tests/research/test_gc_rootzone_memory_rzm06d02_reseed.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$out" --opt "$opt"
  "$out/rom0_test" "$STATE_FILE" > "$BUILD/d02-o$opt.txt" 2>&1 || {
    cat "$BUILD/d02-o$opt.txt" >&2
    fail "reseed executable O$opt"
  }
  cat "$BUILD/d02-o$opt.txt"
  grep -Fq 'GC_RZM06D02_COMMON_TIME_RESEED=PASS' "$BUILD/d02-o$opt.txt" || fail "PASS marker O$opt"
done
cmp "$BUILD/d02-o0.txt" "$BUILD/d02-o2.txt" || fail "O0/O2 output drift"
sha256sum "$BUILD/d02-o0.txt" "$BUILD/d02-o2.txt"
echo 'GC_RZM06D02_O0_O2_IDENTITY=PASS'
echo 'GC_RZM06D02_RESEED_QUALIFICATION=PASS'
