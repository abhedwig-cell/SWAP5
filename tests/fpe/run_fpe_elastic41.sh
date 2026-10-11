#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/elastic41-pdok}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic41-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "F_PE_ELASTIC41_FAIL $*" >&2; exit 1; }

python3 tests/fpe/run_fpe_elastic41.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR" > "$BUILD/python.txt" 2>&1 || {
    cat "$BUILD/python.txt" >&2
    fail "offline handoff oracle"
  }
cat "$BUILD/python.txt"

for marker in   'F_PE_ELASTIC41_A1_INACTIVE_NO_SOURCE_IO=PASS'   'F_PE_ELASTIC41_A2_ELASTIC36_ROW_IDENTITY=PASS'   'F_PE_ELASTIC41_A3_PROVENANCE_IDENTITY=PASS'   'F_PE_ELASTIC41_A4_REAL_SOURCE_SAMPLE=PASS'   'F_PE_ELASTIC41_A5_SPATIAL_FAIL_CLOSED=PASS'   'F_PE_ELASTIC41_A6_SOURCE_FAIL_CLOSED=PASS'   'F_PE_ELASTIC41_A7_REPEAT_IDENTITY=PASS'   'F_PE_ELASTIC41_A8_INACTIVE_SOURCE_INDEPENDENCE=PASS'   'F_PE_ELASTIC41_A9_ELASTIC37_CONSUMABLE_ROWS=PASS'   'F_PE_ELASTIC41=PASS'; do
  grep -Fq "$marker" "$BUILD/python.txt" || fail "missing marker $marker"
done

FIXTURE="$BUILD/test_fpe_elastic41_end_to_end.f90"
python3 tests/fpe/prepare_fpe_elastic41.py   --repo-root "$ROOT"   --artifact-dir "$ARTIFACT_DIR"   --work-dir "$BUILD/work"   --fixture "$FIXTURE" > "$BUILD/prepare.txt" 2>&1 || {
    cat "$BUILD/prepare.txt" >&2
    fail "prepare Fortran composition"
  }
cat "$BUILD/prepare.txt"

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py     --root "$ROOT" --stub "$BUILD/stub.f90"     --target "$FIXTURE"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "Fortran composition O$opt"
  }
  for marker in     'F_PE_ELASTIC41_A7_DEFAULT_OFF=PASS'     'F_PE_ELASTIC41_A4_EXPLICIT_REQUEST=PASS'     'F_PE_ELASTIC41_A5_REAL_PROFILE_BINDING=PASS'     'F_PE_ELASTIC41_A6_POSITIVE_PRIORS=PASS'     'F_PE_ELASTIC41_A8_EXPLICIT_OWNER_PRESERVED=PASS'     'F_PE_ELASTIC41=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing Fortran O$opt marker $marker"
    }
  done
  cat "$OUT/output.txt"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 drift"
}
echo "F_PE_ELASTIC41_A9_O0_O2=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC41_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC41_A10_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC41_RUN=PASS"
