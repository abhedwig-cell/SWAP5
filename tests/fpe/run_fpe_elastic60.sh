#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic60-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC60_FAIL $*" >&2; exit 1; }

python3 tests/fpe/materialize_fpe_elastic60_mode7_oracle.py   --root "$ROOT"   --output "$BUILD/test_mode7.f90"   --preservation-output "$BUILD/test_mode2_preserve.f90" | tee "$BUILD/materialize.txt"
grep -Fq 'F_PE_ELASTIC60_MATERIALIZE=PASS' "$BUILD/materialize.txt" || fail "materialize"

IND=src/solver/mod_reference_richards_temporal_indicator.f90
grep -Fq 'request%boundary%bottom_mode /= 7' "$IND" || fail "mode7 envelope missing"
grep -Fq 'if (request%boundary%bottom_mode == 5) then' "$IND" || fail "mode5-only stiffness guard drift"

for opt in 0 2; do
  for name in mode7 mode2; do
    TARGET="$BUILD/test_mode7.f90"
    [ "$name" = mode2 ] && TARGET="$BUILD/test_mode2_preserve.f90"
    OUT="$BUILD/${name}_o${opt}"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub tests/fsi/fsi04_real_headcalc_stubs.f90       --target "$TARGET"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
    "$OUT/rom0_test" > "$OUT/result.txt" 2>&1 || { cat "$OUT/result.txt" >&2; fail "$name O$opt"; }
  done

  grep -Fq 'ELASTIC60_MODE7_INDICATOR_ADMISSION=PASS' "$BUILD/mode7_o$opt/result.txt" || {
    cat "$BUILD/mode7_o$opt/result.txt" >&2; fail "mode7 marker O$opt";
  }
  grep -Fq 'ELASTIC60_PRESERVE_PRESCRIBED_QBOT_TEMPORAL_CERTIFICATE=PASS' "$BUILD/mode2_o$opt/result.txt" || {
    cat "$BUILD/mode2_o$opt/result.txt" >&2; fail "mode2 preservation O$opt";
  }

  OUT="$BUILD/mode5_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub tests/fsi/fsi04_real_headcalc_stubs.f90     --target tests/fsi/test_fsi25_reference_indicator_production_seam.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" -75.0 0.01 > "$OUT/result.txt" 2>&1 || { cat "$OUT/result.txt" >&2; fail "mode5 O$opt"; }
  grep -Fq 'FSI25_REFERENCE_INDICATOR_CASE PASS' "$OUT/result.txt" || fail "mode5 marker O$opt"
  grep -Fq ':EXTRA_NONLINEAR=0:EXTRA_TRIDAG=1:' "$OUT/result.txt" || fail "mode5 cost O$opt"
done

cmp -s "$BUILD/mode7_o0/result.txt" "$BUILD/mode7_o2/result.txt" || {
  diff -u "$BUILD/mode7_o0/result.txt" "$BUILD/mode7_o2/result.txt" >&2 || true; fail "mode7 O0/O2";
}
cmp -s "$BUILD/mode2_o0/result.txt" "$BUILD/mode2_o2/result.txt" || {
  diff -u "$BUILD/mode2_o0/result.txt" "$BUILD/mode2_o2/result.txt" >&2 || true; fail "mode2 O0/O2";
}
cmp -s "$BUILD/mode5_o0/result.txt" "$BUILD/mode5_o2/result.txt" || {
  diff -u "$BUILD/mode5_o0/result.txt" "$BUILD/mode5_o2/result.txt" >&2 || true; fail "mode5 O0/O2";
}

echo "F_PE_ELASTIC60_A2_MODE7_ORACLE=PASS"
echo "F_PE_ELASTIC60_A4_PRODUCTION_BINDING=PASS"
echo "F_PE_ELASTIC60_A5_SWKIMPL1_FAIL_CLOSED=PASS"
echo "F_PE_ELASTIC60_A6_MODE2_MODE5_PRESERVATION=PASS"
echo "F_PE_ELASTIC60_A7_O0_O2=PASS"
echo "F_PE_ELASTIC60_A8_NO_BUDGET_BINDING=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
src=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD","--","src"],text=True).splitlines() if p]
expected=["src/solver/mod_reference_richards_temporal_indicator.f90"]
if src!=expected:
    raise SystemExit("F_PE_ELASTIC60_SOURCE_SCOPE_FAIL="+repr(src))
print("F_PE_ELASTIC60_A1_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC60=PASS"
