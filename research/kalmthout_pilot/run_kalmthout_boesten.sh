#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
OUTDIR="${1:-/tmp/kalmthout-boesten}"
mkdir -p "$OUTDIR"

python3 research/kalmthout_pilot/build_grid.py > "$OUTDIR/grid_500m.csv"
python3 - "$OUTDIR/grid_500m.csv" <<'PY'
import csv,sys
r=list(csv.DictReader(open(sys.argv[1])))
assert len(r)==1024
assert r[495]["cell_id"]=="KAL_0496"
assert r[495]["easting"]=="600730.0" and r[495]["northing"]=="5690770.0"
print("KALMTHOUT_OFFICIAL_GRID=PASS")
PY

python3 research/kalmthout_pilot/fetch_era5land_daily.py > "$OUTDIR/weather.csv"
python3 - "$OUTDIR/weather.csv" <<'PY'
import csv,sys
r=list(csv.DictReader(open(sys.argv[1])))
assert len(r)==24120
assert r[0]["time"]=="2024-01-01T00:00"
assert r[-1]["time"]=="2026-10-01T23:00"
print("KALMTHOUT_METEO_HOURLY_COMPLETE=PASS")
PY

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-kalmthout-boesten-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
mapfile -t SOURCES < <(python3 tests/support/augment_bartholomeus_backend_sources.py --all   tests/fsi/fsi04_real_headcalc_stubs.f90   src/runtime/mod_fmr_production_application_bootstrap.f90   src/adapter/mod_ppa_wu04b_boesten_forcing_adapter.f90)
COMMON=(-std=f2008 -ffree-line-length-none -w -fopenmp -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
objects=()
for source in "${SOURCES[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c src/legacy/b1_10_port/headcalc.f90 -o "$BUILD/headcalc.o"
objects+=("$BUILD/headcalc.o")
gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c research/kalmthout_pilot/kalmthout_boesten_pilot.f90 -o "$BUILD/pilot.o"
gfortran -fopenmp -O2 "${objects[@]}" "$BUILD/pilot.o" -o "$BUILD/kalmthout_boesten"

"$BUILD/kalmthout_boesten" "$OUTDIR/weather.csv" "$OUTDIR/probe_48h.csv" 48 1.0 | tee "$OUTDIR/probe_48h.log"
grep -Fq 'KALMTHOUT_BOESTEN_PILOT=PASS' "$OUTDIR/probe_48h.log"
echo "KALMTHOUT_BOESTEN_48H=PASS"

"$BUILD/kalmthout_boesten" "$OUTDIR/weather.csv" "$OUTDIR/full_2024_2026.csv" 0 1.0 | tee "$OUTDIR/full_run.log"
grep -Fq 'KALMTHOUT_BOESTEN_PILOT=PASS' "$OUTDIR/full_run.log"
echo "KALMTHOUT_BOESTEN_FULL_2024_TO_2026=PASS"
