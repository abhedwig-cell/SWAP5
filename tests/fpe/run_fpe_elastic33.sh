#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic33-${GITHUB_RUN_ID:-local}-$$"
ARTIFACT_DIR="${1:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/elastic33-pdok}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "F_PE_ELASTIC33_FAIL $*" >&2; exit 1; }

python3 tests/fpe/run_fpe_elastic33.py \
  --repo-root "$ROOT" \
  --artifact-dir "$ARTIFACT_DIR" \
  --fixture "$BUILD/test_fpe_elastic33_fortran_composition.f90" > "$BUILD/python.txt" 2>&1 || {
    cat "$BUILD/python.txt" >&2
    fail "python qualification"
  }
cat "$BUILD/python.txt"

for marker in \
  'F_PE_ELASTIC33_A1_SOURCE_GATE=PASS' \
  'F_PE_ELASTIC33_A2_ROW_MAPPING=PASS' \
  'F_PE_ELASTIC33_A3_F64_IDENTITY=PASS' \
  'F_PE_ELASTIC33_A4_ORGANIC_PROJECTION=PASS' \
  'F_PE_ELASTIC33_A5_PEAT_PROJECTION=PASS' \
  'F_PE_ELASTIC33_A6_SCHEMA_FAIL_CLOSED=PASS' \
  'F_PE_ELASTIC33_A7_DATA_FAIL_CLOSED=PASS' \
  'F_PE_ELASTIC33_A8_BYTE_IDENTITY=PASS' \
  'F_PE_ELASTIC33_A9_ALL_PROFILES=PASS' \
  'F_PE_ELASTIC33_A9_ALL_ROWS=PASS' \
  'F_PE_ELASTIC33=PASS'; do
  grep -Fq "$marker" "$BUILD/python.txt" || fail "missing python marker $marker"
done

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target "$BUILD/test_fpe_elastic33_fortran_composition.f90" \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "Fortran composition O$opt"
  }
  grep -Fq 'F_PE_ELASTIC33_A9_FORTRAN_COMPOSITION=PASS' "$OUT/output.txt" || {
    cat "$OUT/output.txt" >&2
    fail "missing Fortran composition marker O$opt"
  }
  cat "$OUT/output.txt"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 drift"
}
echo "F_PE_ELASTIC33_A9_O0_O2=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC33_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC33_A10_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC33_RUN=PASS"
