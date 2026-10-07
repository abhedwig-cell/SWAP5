#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
OUTDIR="${1:-/tmp/kalmthout-swap5-pilot}"
mkdir -p "$OUTDIR"
python3 research/kalmthout_pilot/fetch_era5land_daily.py > "$OUTDIR/weather.csv"
python3 - "$OUTDIR/weather.csv" <<'PY'
import csv,sys
rows=list(csv.DictReader(open(sys.argv[1])))
assert len(rows)==24120, len(rows)
assert rows[0]["time"]=="2024-01-01T00:00"
assert rows[-1]["time"]=="2026-10-01T23:00"
print("KALMTHOUT_METEO_HOURLY_COMPLETE=PASS")
PY

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
gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c research/kalmthout_pilot/kalmthout_swap5_daily_pilot.f90 -o "$BUILD/pilot.o"
gfortran -fopenmp -O2 "${objects[@]}" "$BUILD/pilot.o" -o "$BUILD/kalmthout_pilot"
"$BUILD/kalmthout_pilot" "$OUTDIR/weather.csv" "$OUTDIR/swap5_daily_results.csv" | tee "$OUTDIR/run.log"
grep -Fq 'KALMTHOUT_SWAP5_DAILY_PILOT=PASS' "$OUTDIR/run.log"
echo "KALMTHOUT_PILOT_RUNNER=PASS"
