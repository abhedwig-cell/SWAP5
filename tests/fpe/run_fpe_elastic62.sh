#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic62-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC62_FAIL $*" >&2; exit 1; }

# Primary production-backend binding qualification.
for opt in 0 2; do
  OUT="$BUILD/main_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub tests/fsi/fsi04_real_headcalc_stubs.f90     --target tests/fpe/test_fpe_elastic62_csafe_binding.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/result.txt" 2>&1 || { cat "$OUT/result.txt" >&2; fail "main O$opt"; }
  for marker in     'F_PE_ELASTIC62_A2_MODE7_ALPHA_NORMALIZATION=PASS'     'F_PE_ELASTIC62_A3_THRESHOLD_AND_RETRY=PASS'     'F_PE_ELASTIC62_A4_MISSING_BUDGET=PASS'     'F_PE_ELASTIC62_A5_INVALID_BUDGET=PASS'     'F_PE_ELASTIC62_A6_MASS_FIRST=PASS'     'F_PE_ELASTIC62_A7_OBSERVED_RETRY_ONLY=PASS'     'F_PE_ELASTIC62_A8_SWKIMPL1_FAIL_CLOSED=PASS'     'F_PE_ELASTIC62_A10_COMMIT_AFTER_ACCEPTANCE=PASS'     'F_PE_ELASTIC62_RUNTIME=PASS'; do
    grep -Fq "$marker" "$OUT/result.txt" || { cat "$OUT/result.txt" >&2; fail "main marker O$opt $marker"; }
  done
done
cmp -s "$BUILD/main_o0/result.txt" "$BUILD/main_o2/result.txt" || {
  diff -u "$BUILD/main_o0/result.txt" "$BUILD/main_o2/result.txt" >&2 || true
  fail "main O0/O2 semantic drift"
}
cat "$BUILD/main_o2/result.txt"
echo "F_PE_ELASTIC62_A11_O0_O2=PASS"

# ELASTIC61 stateless envelope preservation.
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/e61_o$opt"; mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT"     -c src/adapter/mod_fmr_mode7_temporal_head_envelope.f90 -o "$OUT/mod.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT"     -c tests/fpe/test_fpe_elastic61_mode7_error_envelope.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/mod.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/result.txt"
  grep -Fq 'F_PE_ELASTIC61=PASS' "$OUT/result.txt" || fail "ELASTIC61 preservation O$opt"
done
cmp -s "$BUILD/e61_o0/result.txt" "$BUILD/e61_o2/result.txt" || fail "ELASTIC61 O0/O2 drift"
echo "F_PE_ELASTIC62_A12_ELASTIC61_PRESERVATION=PASS"

# Typed mode-7 mass publication preservation.
for opt in 0 2; do
  OUT="$BUILD/mass_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub tests/fsi/fsi04_real_headcalc_stubs.f90     --target tests/fpe/test_fpe_elastic59_mode7_typed_mass.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/result.txt"
  grep -Fq 'F_PE_ELASTIC59_MODE7_TYPED_MASS=PASS' "$OUT/result.txt" || fail "typed mass O$opt"
done
cmp -s "$BUILD/mass_o0/result.txt" "$BUILD/mass_o2/result.txt" || fail "typed mass O0/O2 drift"
echo "F_PE_ELASTIC62_A12_TYPED_MASS_PRESERVATION=PASS"

# Production mode-7 indicator and mode-2 indicator preservation.
python3 tests/fpe/materialize_fpe_elastic60_mode7_oracle.py   --root "$ROOT"   --output "$BUILD/mode7.f90"   --preservation-output "$BUILD/mode2.f90" > "$BUILD/materialize.txt"
grep -Fq 'F_PE_ELASTIC60_MATERIALIZE=PASS' "$BUILD/materialize.txt" || fail "ELASTIC60 materialize"
for opt in 0 2; do
  for name in mode7 mode2; do
    OUT="$BUILD/${name}_o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub tests/fsi/fsi04_real_headcalc_stubs.f90       --target "$BUILD/${name}.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
    "$OUT/rom0_test" > "$OUT/result.txt"
  done
  grep -Fq 'ELASTIC60_MODE7_INDICATOR_ADMISSION=PASS' "$BUILD/mode7_o$opt/result.txt" || fail "mode7 indicator O$opt"
  grep -Fq 'ELASTIC60_PRESERVE_PRESCRIBED_QBOT_TEMPORAL_CERTIFICATE=PASS' "$BUILD/mode2_o$opt/result.txt" || fail "mode2 preservation O$opt"
done
cmp -s "$BUILD/mode7_o0/result.txt" "$BUILD/mode7_o2/result.txt" || fail "mode7 indicator O0/O2 drift"
cmp -s "$BUILD/mode2_o0/result.txt" "$BUILD/mode2_o2/result.txt" || fail "mode2 indicator O0/O2 drift"
echo "F_PE_ELASTIC62_A9_MODE2_PRESERVATION=PASS"
echo "F_PE_ELASTIC62_A12_MODE7_INDICATOR_PRESERVATION=PASS"

# Existing mode-5 model-certificate runtime semantics remain intact.
for opt in 0 2; do
  OUT="$BUILD/mode5_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub tests/fsi/fsi04_real_headcalc_stubs.f90     --target tests/fpe/test_fpe_temporal08_registry_equivalence.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/result.txt" 2>&1 || { cat "$OUT/result.txt" >&2; fail "mode5 runtime O$opt"; }
  grep -Fq 'FPE_TEMPORAL08_P1_REGISTRY=PASS' "$OUT/result.txt" || fail "mode5 runtime marker O$opt"
done
cmp -s "$BUILD/mode5_o0/result.txt" "$BUILD/mode5_o2/result.txt" || {
  diff -u "$BUILD/mode5_o0/result.txt" "$BUILD/mode5_o2/result.txt" >&2 || true
  fail "mode5 runtime O0/O2 drift"
}
echo "F_PE_ELASTIC62_A9_MODE5_PRESERVATION=PASS"

# Exact production source scope.
python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
src=sorted(p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD","--","src"],text=True).splitlines() if p)
expected=["src/runtime/mod_fmr_serialized_reference_backend.f90"]
if src!=expected:
    raise SystemExit("F_PE_ELASTIC62_SOURCE_SCOPE_FAIL="+repr(src))
print("F_PE_ELASTIC62_A1_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC62_RUN=PASS"
