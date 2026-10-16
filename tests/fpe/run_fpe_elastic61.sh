#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic61-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC61_FAIL $*" >&2; exit 1; }

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/unit_o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT"     -c src/adapter/mod_fmr_mode7_temporal_head_envelope.f90 -o "$OUT/mod.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT"     -c tests/fpe/test_fpe_elastic61_mode7_error_envelope.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/mod.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/result.txt" 2>&1 || { cat "$OUT/result.txt" >&2; fail "unit O$opt"; }
  for marker in     'F_PE_ELASTIC61_A1_ALPHA=PASS'     'F_PE_ELASTIC61_A2_FORMULA=PASS'     'F_PE_ELASTIC61_A3_THRESHOLD=PASS'     'F_PE_ELASTIC61_A4_ZERO=PASS'     'F_PE_ELASTIC61_A5_FAIL_CLOSED=PASS'     'F_PE_ELASTIC61=PASS'; do
    grep -Fq "$marker" "$OUT/result.txt" || { cat "$OUT/result.txt" >&2; fail "missing unit marker $marker"; }
  done
done

cmp -s "$BUILD/unit_o0/result.txt" "$BUILD/unit_o2/result.txt" || {
  diff -u "$BUILD/unit_o0/result.txt" "$BUILD/unit_o2/result.txt" >&2 || true
  fail "unit O0/O2 drift"
}
cat "$BUILD/unit_o2/result.txt"
echo "F_PE_ELASTIC61_A8_O0_O2=PASS"

# Preservation: typed mode-7 mass publication.
for opt in 0 2; do
  OUT="$BUILD/mass_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub tests/fsi/fsi04_real_headcalc_stubs.f90     --target tests/fpe/test_fpe_elastic59_mode7_typed_mass.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/result.txt" 2>&1 || { cat "$OUT/result.txt" >&2; fail "mass preservation O$opt"; }
  grep -Fq 'F_PE_ELASTIC59_MODE7_TYPED_MASS=PASS' "$OUT/result.txt" || fail "mass marker O$opt"
done
cmp -s "$BUILD/mass_o0/result.txt" "$BUILD/mass_o2/result.txt" || fail "mass preservation O0/O2 drift"
echo "F_PE_ELASTIC61_A7_TYPED_MASS_PRESERVATION=PASS"

# Preservation: production mode-7 defect indicator and mode-2/mode-5 seams.
python3 tests/fpe/materialize_fpe_elastic60_mode7_oracle.py   --root "$ROOT"   --output "$BUILD/test_mode7.f90"   --preservation-output "$BUILD/test_mode2.f90" > "$BUILD/materialize.txt"
grep -Fq 'F_PE_ELASTIC60_MATERIALIZE=PASS' "$BUILD/materialize.txt" || fail "mode7 materialize"

for opt in 0 2; do
  for name in mode7 mode2; do
    target="$BUILD/test_mode7.f90"
    [ "$name" = mode2 ] && target="$BUILD/test_mode2.f90"
    OUT="$BUILD/${name}_o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub tests/fsi/fsi04_real_headcalc_stubs.f90       --target "$target"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
    "$OUT/rom0_test" > "$OUT/result.txt" 2>&1 || { cat "$OUT/result.txt" >&2; fail "$name O$opt"; }
  done
  grep -Fq 'ELASTIC60_MODE7_INDICATOR_ADMISSION=PASS' "$BUILD/mode7_o$opt/result.txt" || fail "mode7 marker O$opt"
  grep -Fq 'ELASTIC60_PRESERVE_PRESCRIBED_QBOT_TEMPORAL_CERTIFICATE=PASS' "$BUILD/mode2_o$opt/result.txt" || fail "mode2 marker O$opt"

  OUT="$BUILD/mode5_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub tests/fsi/fsi04_real_headcalc_stubs.f90     --target tests/fsi/test_fsi25_reference_indicator_production_seam.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" -75.0 0.01 > "$OUT/result.txt" 2>&1 || { cat "$OUT/result.txt" >&2; fail "mode5 O$opt"; }
  grep -Fq 'FSI25_REFERENCE_INDICATOR_CASE PASS' "$OUT/result.txt" || fail "mode5 marker O$opt"
done

cmp -s "$BUILD/mode7_o0/result.txt" "$BUILD/mode7_o2/result.txt" || fail "mode7 O0/O2 drift"
cmp -s "$BUILD/mode2_o0/result.txt" "$BUILD/mode2_o2/result.txt" || fail "mode2 O0/O2 drift"
cmp -s "$BUILD/mode5_o0/result.txt" "$BUILD/mode5_o2/result.txt" || fail "mode5 O0/O2 drift"
echo "F_PE_ELASTIC61_A7_INDICATOR_PRESERVATION=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
src=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD","--","src"],text=True).splitlines() if p]
expected=["src/adapter/mod_fmr_mode7_temporal_head_envelope.f90"]
if src!=expected:
    raise SystemExit("F_PE_ELASTIC61_SOURCE_SCOPE_FAIL="+repr(src))
print("F_PE_ELASTIC61_A9_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC61_RUN=PASS"
