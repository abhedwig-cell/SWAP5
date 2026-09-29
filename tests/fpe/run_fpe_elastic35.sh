#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic35-${GITHUB_RUN_ID:-local}-$$"
ARTIFACT_DIR="${1:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/elastic35-pdok}"
FIX="$BUILD/fixtures"
mkdir -p "$BUILD" "$FIX"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "F_PE_ELASTIC35_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic35_fixtures.py \
  --repo-root "$ROOT" \
  --artifact-dir "$ARTIFACT_DIR" \
  --output-dir "$FIX" > "$BUILD/prepare.txt" 2>&1 || {
    cat "$BUILD/prepare.txt" >&2
    fail "fixture preparation"
  }
cat "$BUILD/prepare.txt"
grep -Fq 'F_PE_ELASTIC35_PREP_A2_ALL_PROFILES=PASS' "$BUILD/prepare.txt" || fail "profile preparation marker"
grep -Fq 'F_PE_ELASTIC35_PREP_A3_ALL_ROWS=PASS' "$BUILD/prepare.txt" || fail "row preparation marker"
grep -Fq 'F_PE_ELASTIC35_PREP_INVALID_FIXTURES=PASS' "$BUILD/prepare.txt" || fail "invalid fixture marker"

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target tests/fpe/test_fpe_elastic35_row_interchange_parser.f90 \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"

  : > "$OUT/output.txt"
  while IFS='|' read -r pid path count; do
    "$OUT/rom0_test" valid "$path" >> "$OUT/output.txt" 2>&1 || {
      tail -100 "$OUT/output.txt" >&2
      fail "valid profile $pid O$opt"
    }
  done < "$FIX/manifest.txt"

  valid_count="$(grep -c '^F_PE_ELASTIC35_VALID_PROFILE=' "$OUT/output.txt")"
  [[ "$valid_count" == "368" ]] || fail "valid profile count O$opt=$valid_count"
  row_total="$(awk -F'|' '/^F_PE_ELASTIC35_VALID_PROFILE=/{s+=$2} END{print s+0}' "$OUT/output.txt")"
  [[ "$row_total" == "1568" ]] || fail "parsed row total O$opt=$row_total"
  echo "F_PE_ELASTIC35_A2_ALL_PROFILES=PASS" >> "$OUT/output.txt"
  echo "F_PE_ELASTIC35_A3_ALL_ROWS=PASS" >> "$OUT/output.txt"
  echo "F_PE_ELASTIC35_A4_F64_IDENTITY=PASS" >> "$OUT/output.txt"
  echo "F_PE_ELASTIC35_A5_FLAG_IDENTITY=PASS" >> "$OUT/output.txt"
  echo "F_PE_ELASTIC35_A8_ELASTIC22_COMPOSITION=PASS" >> "$OUT/output.txt"

  for bad in bad_magic bad_hash bad_columns bad_count; do
    "$OUT/rom0_test" invalid "$FIX/$bad.rows" >> "$OUT/output.txt" 2>&1 || fail "$bad O$opt"
  done
  echo "F_PE_ELASTIC35_A6_HEADER_FAIL_CLOSED=PASS" >> "$OUT/output.txt"

  for bad in bad_width bad_profile bad_layer bad_geometry bad_density bad_flag; do
    "$OUT/rom0_test" invalid "$FIX/$bad.rows" >> "$OUT/output.txt" 2>&1 || fail "$bad O$opt"
  done
  "$OUT/rom0_test" extra "$FIX/extra_record.rows" >> "$OUT/output.txt" 2>&1 || fail "extra record O$opt"
  echo "F_PE_ELASTIC35_A7_ROW_FAIL_CLOSED=PASS" >> "$OUT/output.txt"

  cat "$OUT/output.txt"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 drift"
}
echo "F_PE_ELASTIC35_A9_O0_O2=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
allowed=["src/adapter/mod_fmr_elastic_storage_row_interchange_file_adapter.f90"]
if prod != allowed:
    raise SystemExit("F_PE_ELASTIC35_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC35_A10_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC35_RUN=PASS"
