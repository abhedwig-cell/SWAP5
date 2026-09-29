#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic37-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"; rm -f elastic37-valid.rows elastic37-peat.rows' EXIT

fail(){ echo "F_PE_ELASTIC37_FAIL $*" >&2; exit 1; }

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target tests/fpe/test_fpe_elastic37_row_application_binding.f90 \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "application composition O$opt"
  }
  for marker in \
    'F_PE_ELASTIC37_A1_DEFAULT_OFF_NO_IO=PASS' \
    'F_PE_ELASTIC37_A2_ACTIVE_BINDING=PASS' \
    'F_PE_ELASTIC37_A3_MANUAL_COMPOSITION_IDENTITY=PASS' \
    'F_PE_ELASTIC37_A4_EXPLICIT_OWNER_PRESERVED=PASS' \
    'F_PE_ELASTIC37_A5_PEAT_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC37_A6_ROW_FILE_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC37_A7_GRID_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC37_A8_STRADDLE_FAIL_CLOSED=PASS' \
    'F_PE_ELASTIC37=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing O$opt marker $marker"
    }
  done
  cat "$OUT/output.txt"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 drift"
}
echo "F_PE_ELASTIC37_A9_O0_O2=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
allowed=["src/adapter/mod_fmr_elastic_storage_row_application_binding.f90"]
if prod != allowed:
    raise SystemExit("F_PE_ELASTIC37_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC37_A10_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC37_RUN=PASS"
