#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic65-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC65_FAIL $*" >&2; exit 1; }

for opt in 0 2; do
  OUT="$BUILD/mode7_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub tests/fsi/fsi04_real_headcalc_stubs.f90     --target tests/fpe/test_fpe_elastic65_mode7_csafe_binding.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/result.txt" 2>&1 || {
    cat "$OUT/result.txt" >&2
    fail "mode7 C-SAFE O$opt"
  }
  for marker in     'F_PE_ELASTIC65_A1_MODE7_NORMALIZATION=PASS'     'F_PE_ELASTIC65_A2_REFINE_RECHECK=PASS'     'F_PE_ELASTIC65_A3_MISSING_BUDGET_FAIL_CLOSED=PASS'     'F_PE_ELASTIC65_A4_MASS_INDEPENDENT=PASS'     'F_PE_ELASTIC65_A7_SWKIMPL1_FAIL_CLOSED=PASS'     'F_PE_ELASTIC65=PASS'; do
    grep -Fq "$marker" "$OUT/result.txt" || { cat "$OUT/result.txt" >&2; fail "missing mode7 marker $marker"; }
  done
done

cmp -s "$BUILD/mode7_o0/result.txt" "$BUILD/mode7_o2/result.txt" || {
  diff -u "$BUILD/mode7_o0/result.txt" "$BUILD/mode7_o2/result.txt" >&2 || true
  fail "mode7 O0/O2 drift"
}
cat "$BUILD/mode7_o2/result.txt"
echo "F_PE_ELASTIC65_A8_O0_O2=PASS"

# Mode-2 indicator preservation.
for opt in 0 2; do
  OUT="$BUILD/mode2_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub tests/fsi/fsi04_real_headcalc_stubs.f90     --target tests/fsi/test_fsi38_prescribed_qbot_temporal_certificate.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/result.txt" 2>&1 || { cat "$OUT/result.txt" >&2; fail "mode2 O$opt"; }
  grep -Fq 'FSI38_PRESCRIBED_QBOT_TEMPORAL_CERTIFICATE=PASS' "$OUT/result.txt" || fail "mode2 marker O$opt"
done
cmp -s "$BUILD/mode2_o0/result.txt" "$BUILD/mode2_o2/result.txt" || fail "mode2 O0/O2 drift"
echo "F_PE_ELASTIC65_A5_MODE2_PRESERVATION=PASS"

# Mode-5 model-certificate/live registry semantics preservation.
for opt in 0 2; do
  OUT="$BUILD/mode5_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT"     --stub tests/fsi/fsi04_real_headcalc_stubs.f90     --target tests/fpe/test_fpe_temporal08_registry_equivalence.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/result.txt" 2>&1 || { cat "$OUT/result.txt" >&2; fail "mode5 registry O$opt"; }
  grep -Fq 'FPE_TEMPORAL08_P1_REGISTRY=PASS' "$OUT/result.txt" || fail "mode5 registry marker O$opt"
done
cmp -s "$BUILD/mode5_o0/result.txt" "$BUILD/mode5_o2/result.txt" || fail "mode5 O0/O2 drift"
echo "F_PE_ELASTIC65_A6_MODE5_PRESERVATION=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
src=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD","--","src"],text=True).splitlines() if p]
expected=["src/runtime/mod_fmr_serialized_reference_backend.f90"]
if src!=expected:
    raise SystemExit("F_PE_ELASTIC65_SOURCE_SCOPE_FAIL="+repr(src))
print("F_PE_ELASTIC65_A9_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC65_RUN=PASS"
