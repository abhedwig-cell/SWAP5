#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)";cd "$ROOT"
B="$(mktemp -d)";OUT="${1:-$B/out}";mkdir -p "$OUT";trap 'rm -rf "$B"' EXIT
python3 - "$B/grid.f90" <<'GRID'
from pathlib import Path
import sys
s=Path('tests/fsi/fsi04_real_headcalc_stubs.f90').read_text().replace('numnod = 4','numnod = 10')
s=s.replace('[-0.25d0, -0.75d0, -1.50d0, -2.50d0]','['+','.join(str(-5-10*i)+'d0' for i in range(10))+']')
s=s.replace('[0.50d0, 0.50d0, 1.00d0, 1.00d0]','10.0d0')
s=s.replace('disnod(numnod+1) = 1.0d0','disnod(numnod+1) = [5.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,5.0d0]')
Path(sys.argv[1]).write_text(s)
GRID
mapfile -t MODULE_SRC < <(python3 - "$B/grid.f90" <<'SOURCES'
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
printf '%s\n' "${MODULE_SRC[@]}" > "$B/src"
mkdir "$B/o";objs=()
while IFS= read -r s;do [[ -z "$s" ]]&&continue;o="$B/o/$(basename "${s%.*}").o";gfortran -std=f2008 -ffree-line-length-none -O2 -J"$B/o" -I"$B/o" -c "$s" -o "$o";objs+=("$o");done < "$B/src"
gfortran -std=f2008 -ffree-line-length-none -O2 -J"$B/o" -I"$B/o" "${objs[@]}" research/rfm/a27/test_perf03.f90 -o "$B/p"
"$B/p"|tee "$OUT/perf03.csv"
grep -Fq 'A27_PERF03_EXECUTED=PASS' "$OUT/perf03.csv"
