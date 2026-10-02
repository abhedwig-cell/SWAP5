#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"
BUILD="$(mktemp -d)"
OUTDIR="${1:-$BUILD/result}"
mkdir -p "$OUTDIR"
trap 'rm -rf "$BUILD"' EXIT

python3 - "$BUILD/grid_stubs.f90" <<'GRID'
from pathlib import Path
import sys
s=Path('tests/fsi/fsi04_real_headcalc_stubs.f90').read_text()
s=s.replace('numnod = 4','numnod = 10')
s=s.replace('[-0.25d0, -0.75d0, -1.50d0, -2.50d0]','['+','.join(str(-5-10*i)+'d0' for i in range(10))+']')
s=s.replace('[0.50d0, 0.50d0, 1.00d0, 1.00d0]','10.0d0').replace('disnod(numnod+1) = 1.0d0','disnod(numnod+1) = [5.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,5.0d0]')
Path(sys.argv[1]).write_text(s)
GRID

mapfile -t MODULE_SRC < <(python3 - "$BUILD/grid_stubs.f90" <<'SOURCES'
from pathlib import Path
import re,sys
text=Path('tests/fpm/run_ppa_wu05a26_backend_compile.sh').read_text()
m=re.search(r'MODULE_SRC=\\(\\n(.*?)\\n\\)',text,re.S)
if not m:
    raise SystemExit('A27 ABC01 could not recover current backend compile source list')
for raw in m.group(1).splitlines():
    source=raw.strip()
    if not source:
        continue
    if source=='tests/fsi/fsi04_real_headcalc_stubs.f90':
        source=sys.argv[1]
    print(source)
SOURCES
)
# Reuse the current production backend dependency augmenter, but the 10-cell
# replacement stub owns the legacy stub modules for this fixture.
mapfile -t MODULE_SRC < <(python3 tests/support/augment_bartholomeus_backend_sources.py "${MODULE_SRC[@]}" | \
  grep -v '^tests/fsi/fsi04_real_headcalc_stubs.f90
for opt in 0 2; do
  B="$BUILD/o$opt";mkdir -p "$B";objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$B/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J"$B" -I"$B" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J"$B" -I"$B" "${objects[@]}" research/rfm/a27/test_production_abc01.f90 -o "$B/abc"
  "$B/abc" > "$OUTDIR/abc_o$opt.txt"
  grep -Fq 'A27_ABC01_EXECUTION_COMPLETE' "$OUTDIR/abc_o$opt.txt"
done
python3 research/rfm/a27/analyze_production_abc01.py "$OUTDIR/abc_o2.txt" "$OUTDIR"
)
COMMON=(-std=f2008 -ffree-line-length-none -fcheck=all -fbacktrace)

for opt in 0 2; do
  B="$BUILD/o$opt";mkdir -p "$B";objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$B/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J"$B" -I"$B" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J"$B" -I"$B" "${objects[@]}" research/rfm/a27/test_production_abc01.f90 -o "$B/abc"
  "$B/abc" > "$OUTDIR/abc_o$opt.txt"
  grep -Fq 'A27_ABC01_EXECUTION_COMPLETE' "$OUTDIR/abc_o$opt.txt"
done
python3 research/rfm/a27/analyze_production_abc01.py "$OUTDIR/abc_o2.txt" "$OUTDIR"
