#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
OUTDIR="${1:-/tmp/kalmthout-swap5-pilot}"
mkdir -p "$OUTDIR"

python3 research/kalmthout_pilot/build_grid.py > "$OUTDIR/grid_500m.csv"
python3 - "$OUTDIR/grid_500m.csv" <<'PY'
import csv,sys
rows=list(csv.DictReader(open(sys.argv[1])))
assert len(rows)==1024, len(rows)
assert rows[0]["cell_id"]=="KAL_0001"
assert rows[-1]["cell_id"]=="KAL_1024"
c=rows[495]
assert c["cell_id"]=="KAL_0496"
assert c["easting"]=="600730.0" and c["northing"]=="5690770.0"
print("KALMTHOUT_OFFICIAL_GRID=PASS")
PY

python3 research/kalmthout_pilot/fetch_era5land_daily.py > "$OUTDIR/weather.csv"
python3 - "$OUTDIR/weather.csv" <<'PY'
import csv,sys
rows=list(csv.DictReader(open(sys.argv[1])))
assert len(rows)==24120, len(rows)
assert rows[0]["time"]=="2024-01-01T00:00"
assert rows[-1]["time"]=="2026-10-01T23:00"
print("KALMTHOUT_METEO_HOURLY_COMPLETE=PASS")
PY

echo "KALMTHOUT_CURRENT_CANONICAL_OWNER_GATE_BEGIN"
bash tests/fapp/run_ppa_wu01_production_application_bootstrap.sh > "$OUTDIR/owner_gate.log" 2>&1
grep -Fq "PPA_WU01_RUTTER_FMR_TRIAL_COMMIT=PASS" "$OUTDIR/owner_gate.log"
grep -Fq "PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP OWNER GATE PASS" "$OUTDIR/owner_gate.log"
echo "KALMTHOUT_CURRENT_CANONICAL_OWNER_GATE=PASS"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-kalmthout-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

mapfile -t MODULE_SRC < <(python3 - <<'PY'
from pathlib import Path
import re,shlex
s=Path("tests/fapp/run_ppa_wu01_production_application_bootstrap.sh").read_text()
m=re.search(r'MODULE_SRC=\(\n(.*?)\n\)',s,re.S)
assert m
for line in m.group(1).splitlines():
    line=line.strip()
    if line: print(shlex.split(line)[0])
PY
)
mapfile -t MODULE_SRC < <(python3 tests/support/augment_bartholomeus_backend_sources.py "${MODULE_SRC[@]}")
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fopenmp -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done

gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c research/kalmthout_pilot/kalmthout_swap5_pilot.f90 -o "$BUILD/pilot.o"
gfortran -fopenmp -O2 "${objects[@]}" "$BUILD/pilot.o" -o "$BUILD/kalmthout_pilot"

# Diagnostic-only owner-backed pilot: failure in a preliminary scenario
# must not prevent the independent atmospheric sensitivity matrix.
for entry in "48:1.0:probe_48h" "0:0.0:full_rainfall_2024_2026"; do
  IFS=: read -r hours scale name <<< "$entry"
  set +e
  "$BUILD/kalmthout_pilot" "$OUTDIR/weather.csv" "$OUTDIR/${name}.csv" "$hours" "$scale" > "$OUTDIR/${name}.log" 2>&1
  code=$?
  set -e
  completed=$(($(wc -l < "$OUTDIR/${name}.csv")-1))
  echo "KALMTHOUT_PRELIM_CASE scenario=$name exit=$code completed_hours=$completed"
done

# Preserve every diagnostic even when a specific atmosphere case fails.
# These runs use the same meteorology, soil, initial state and numerical
# policy; only the evaporation-demand multiplier changes.
cat > "$OUTDIR/atmospheric_matrix.csv" <<'CSV'
evap_scale,exit_code,completed_hours,first_failed_hour
CSV
for scale in 0.25 0.50 0.75 1.00; do
  tag="${scale//./_}"
  set +e
  "$BUILD/kalmthout_pilot" "$OUTDIR/weather.csv" "$OUTDIR/atmospheric_${tag}.csv" 0 "$scale" > "$OUTDIR/atmospheric_${tag}.log" 2>&1
  code=$?
  set -e
  completed=$(($(wc -l < "$OUTDIR/atmospheric_${tag}.csv")-1))
  first_failed=$(grep -m1 '^KALMTHOUT_SUBHOUR_FAIL' "$OUTDIR/atmospheric_${tag}.log" | awk '{print $2}' || true)
  printf '%s,%s,%s,%s\n' "$scale" "$code" "$completed" "$first_failed" >> "$OUTDIR/atmospheric_matrix.csv"
  echo "KALMTHOUT_ATMOSPHERIC_CASE scale=$scale exit=$code completed_hours=$completed failed_at=${first_failed:-none}"
done
python3 - "$OUTDIR/atmospheric_matrix.csv" <<'PY'
import csv,sys
rows=list(csv.DictReader(open(sys.argv[1])))
assert len(rows)==4 and [r["evap_scale"] for r in rows]==["0.25","0.50","0.75","1.00"]
print("KALMTHOUT_ATMOSPHERIC_MATRIX_RECORDED=PASS")
assert rows[-1]["exit_code"]=="0" and int(rows[-1]["completed_hours"])==24120, "full atmospheric case remains unqualified: see matrix"
print("KALMTHOUT_FULL_ATMOSPHERIC_2024_TO_2026=PASS")
PY
