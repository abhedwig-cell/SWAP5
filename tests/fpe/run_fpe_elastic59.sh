#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic59-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC59_FAIL $*" >&2; exit 1; }

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub tests/fsi/fsi04_real_headcalc_stubs.f90     --target tests/fpe/test_fpe_elastic59_mode7_typed_mass.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/result.txt" 2>&1 || {
    cat "$OUT/result.txt" >&2
    fail "mode7 typed mass O$opt"
  }
  for marker in     'F_PE_ELASTIC59_A1_TYPED_MODE7=PASS'     'F_PE_ELASTIC59_A2_RESIDUAL_IDENTITY=PASS'     'F_PE_ELASTIC59_A3_INTEGRATED_IDENTITY=PASS'     'F_PE_ELASTIC59_A4_PHYSICAL_LEDGER=PASS'     'F_PE_ELASTIC59_A5_QBOT_OWNER=PASS'     'F_PE_ELASTIC59_A6_RETRY_FAIL_CLOSED=PASS'     'F_PE_ELASTIC59_MODE7_TYPED_MASS=PASS'; do
    grep -Fq "$marker" "$OUT/result.txt" || { cat "$OUT/result.txt" >&2; fail "missing O$opt marker $marker"; }
  done
done

cmp -s "$BUILD/o0/result.txt" "$BUILD/o2/result.txt" || {
  diff -u "$BUILD/o0/result.txt" "$BUILD/o2/result.txt" >&2 || true
  fail "O0/O2 semantic drift"
}
cat "$BUILD/o2/result.txt"
echo "F_PE_ELASTIC59_A9_O0_O2=PASS"

# Replay existing F-SI38 mode-2 and F-SI25 mode-5 tests through the
# transitive compile closure. The historical F-SI38 shell compile list predates
# current transaction dependencies and is not itself preservation authority.
for opt in 0 2; do
  OUT38="$BUILD/fsi38_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub tests/fsi/fsi04_real_headcalc_stubs.f90     --target tests/fsi/test_fsi38_prescribed_qbot_temporal_certificate.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT38" --opt "$opt"
  "$OUT38/rom0_test" > "$OUT38/result.txt" 2>&1 || {
    cat "$OUT38/result.txt" >&2
    fail "F-SI38 preservation O$opt"
  }
  grep -Fq 'FSI38_PRESCRIBED_QBOT_TEMPORAL_CERTIFICATE=PASS' "$OUT38/result.txt" || {
    cat "$OUT38/result.txt" >&2
    fail "F-SI38 marker O$opt"
  }

  OUT25="$BUILD/fsi25_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub tests/fsi/fsi04_real_headcalc_stubs.f90     --target tests/fsi/test_fsi25_reference_indicator_production_seam.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT25" --opt "$opt"
  "$OUT25/rom0_test" -75.0 0.01 > "$OUT25/result.txt" 2>&1 || {
    cat "$OUT25/result.txt" >&2
    fail "F-SI25 preservation O$opt"
  }
  grep -Fq 'FSI25_REFERENCE_INDICATOR_CASE PASS' "$OUT25/result.txt" || {
    cat "$OUT25/result.txt" >&2
    fail "F-SI25 marker O$opt"
  }
done

cmp -s "$BUILD/fsi38_o0/result.txt" "$BUILD/fsi38_o2/result.txt" || {
  diff -u "$BUILD/fsi38_o0/result.txt" "$BUILD/fsi38_o2/result.txt" >&2 || true
  fail "F-SI38 preservation O0/O2 drift"
}
cmp -s "$BUILD/fsi25_o0/result.txt" "$BUILD/fsi25_o2/result.txt" || {
  diff -u "$BUILD/fsi25_o0/result.txt" "$BUILD/fsi25_o2/result.txt" >&2 || true
  fail "F-SI25 preservation O0/O2 drift"
}
echo "F_PE_ELASTIC59_A7_MODE2_PRESERVATION=PASS"
echo "F_PE_ELASTIC59_A8_MODE5_PRESERVATION=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD","--","src"],text=True).splitlines()
expected=["src/adapter/mod_reference_richards_legacy_binding.f90"]
if names!=expected:
    raise SystemExit("F_PE_ELASTIC59_SOURCE_SCOPE_FAIL="+repr(names))
print("F_PE_ELASTIC59_A10_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC59_RUN=PASS"
