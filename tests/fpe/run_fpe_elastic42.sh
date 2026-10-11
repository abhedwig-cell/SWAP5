#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic42-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/data"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "F_PE_ELASTIC42_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic42.py \
  --repo-root "$ROOT" \
  --artifact-dir "$ARTIFACT_DIR" \
  --work-dir "$BUILD/data" \
  --fixture "$BUILD/test_fpe_elastic42.f90" | tee "$BUILD/prepare.txt"

for marker in \
  'F_PE_ELASTIC42_A1_SOURCE_AUTHORITY=PASS' \
  'F_PE_ELASTIC42_A3_INTERCHANGE_IDENTITY=PASS'; do
  grep -Fq "$marker" "$BUILD/prepare.txt" || fail "missing prepare marker $marker"
done
grep -Eq 'F_PE_ELASTIC42_A2_MINERAL_CANDIDATES=[1-9][0-9]*' "$BUILD/prepare.txt" || fail "no mineral candidates"

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target "$BUILD/test_fpe_elastic42.f90" \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"
  env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "end-to-end O$opt"
  }
  for marker in \
    'F_PE_ELASTIC42_A7_DEFAULT_OFF=PASS' \
    'F_PE_ELASTIC42_A4_EXPLICIT_REQUEST=PASS' \
    'F_PE_ELASTIC42_A5_REAL_PROFILE_BINDING=PASS' \
    'F_PE_ELASTIC42_A6_FINITE_POSITIVE_PRIORS=PASS' \
    'F_PE_ELASTIC42_A8_EXPLICIT_OWNER_PRESERVED=PASS' \
    'F_PE_ELASTIC42=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing O$opt marker $marker"
    }
  done
  grep -Fq 'F_PE_ELASTIC42_SELECTED_PROFILE=' "$OUT/output.txt" || fail "missing selected profile O$opt"
  cat "$OUT/output.txt"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 drift"
}
echo "F_PE_ELASTIC42_A9_O0_O2=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC42_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC42_A10_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC42_RUN=PASS"
