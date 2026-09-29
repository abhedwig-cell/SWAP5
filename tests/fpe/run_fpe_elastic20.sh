#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic20-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/run1" "$BUILD/run2"
trap 'rm -rf "$BUILD"' EXIT

: "${ELASTIC20_SOURCE_ARTIFACT_DIR:?missing source artifact dir}"
: "${ELASTIC20_PDOK_ARTIFACT_DIR:?missing pdok artifact dir}"
: "${ELASTIC20_OUTPUT_DIR:?missing output dir}"

python3 tools/elastic20_materialize_bofek_horizon_catalog.py \
  --source-artifact-dir "$ELASTIC20_SOURCE_ARTIFACT_DIR" \
  --pdok-artifact-dir "$ELASTIC20_PDOK_ARTIFACT_DIR" \
  --output-dir "$BUILD/run1" | tee "$BUILD/materialize1.txt"

python3 tools/elastic20_materialize_bofek_horizon_catalog.py \
  --source-artifact-dir "$ELASTIC20_SOURCE_ARTIFACT_DIR" \
  --pdok-artifact-dir "$ELASTIC20_PDOK_ARTIFACT_DIR" \
  --output-dir "$BUILD/run2" | tee "$BUILD/materialize2.txt"

cmp -s "$BUILD/run1/elastic20_bofek_horizon_catalog.csv" "$BUILD/run2/elastic20_bofek_horizon_catalog.csv"
cmp -s "$BUILD/run1/elastic20_bofek_horizon_catalog.meta.json" "$BUILD/run2/elastic20_bofek_horizon_catalog.meta.json"
echo "F_PE_ELASTIC20_A9_BYTE_DETERMINISM=PASS"

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/verifier_o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target tests/fpe/test_fpe_elastic20_catalog_row.f90 \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"
  python3 tests/fpe/run_fpe_elastic20_catalog.py \
    "$BUILD/run1/elastic20_bofek_horizon_catalog.csv" \
    "$BUILD/run1/elastic20_bofek_horizon_catalog.meta.json" \
    "$OUT/rom0_test" | tee "$BUILD/qualify_o$opt.txt"
done

cmp -s "$BUILD/qualify_o0.txt" "$BUILD/qualify_o2.txt"
echo "F_PE_ELASTIC20_VERIFIER_O0_O2=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC20_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC20_A10_SOURCE_SCOPE=PASS")
PY

cp "$BUILD/run1/elastic20_bofek_horizon_catalog.csv" "${ELASTIC20_OUTPUT_DIR}/"
cp "$BUILD/run1/elastic20_bofek_horizon_catalog.meta.json" "${ELASTIC20_OUTPUT_DIR}/"

echo "F_PE_ELASTIC20=PASS"
