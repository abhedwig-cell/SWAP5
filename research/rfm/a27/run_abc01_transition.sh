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
s=s.replace('[0.50d0, 0.50d0, 1.00d0, 1.00d0]','10.0d0')
s=s.replace('disnod(numnod+1) = 1.0d0','disnod(numnod+1) = [5.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,5.0d0]')
Path(sys.argv[1]).write_text(s)
GRID
mapfile -t MODULE_SRC < <(python3 - "$BUILD/grid_stubs.f90" <<'SOURCES'
from pathlib import Path
import sys
lines=Path('tests/fpm/run_ppa_wu05a26_backend_compile.sh').read_text().splitlines()
inside=False
for raw in lines:
    s=raw.strip()
    if s=='MODULE_SRC=(':
        inside=True;continue
    if inside and s==')':break
    if inside and s:
        if s=='tests/fsi/fsi04_real_headcalc_stubs.f90':s=sys.argv[1]
        print(s)
SOURCES
)
mapfile -t MODULE_SRC < <(python3 tests/support/augment_bartholomeus_backend_sources.py "${MODULE_SRC[@]}" | awk '$0 != "tests/fsi/fsi04_real_headcalc_stubs.f90"')
B="$BUILD/o2";mkdir -p "$B";objects=()
for source in "${MODULE_SRC[@]}"; do
 obj="$B/$(basename "${source%.*}").o"
 gfortran -std=f2008 -ffree-line-length-none -fcheck=all -fbacktrace -O2 -J"$B" -I"$B" -c "$source" -o "$obj"
 objects+=("$obj")
done
gfortran -std=f2008 -ffree-line-length-none -fcheck=all -fbacktrace -O2 -J"$B" -I"$B" "${objects[@]}" research/rfm/a27/test_abc01_transition.f90 -o "$B/diag"
"$B/diag" | tee "$OUTDIR/transition.txt"
grep -Fq 'A27_ABC01_TR01_EXECUTED=PASS' "$OUTDIR/transition.txt"
