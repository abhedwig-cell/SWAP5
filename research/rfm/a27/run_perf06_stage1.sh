#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.."&&pwd)";cd "$ROOT";B="$(mktemp -d)";OUT="${1:-$B/out}";mkdir -p "$OUT";trap 'rm -rf "$B"' EXIT
python3 - "$B/grid.f90" <<'GRID'
from pathlib import Path
import sys
s=Path('tests/fsi/fsi04_real_headcalc_stubs.f90').read_text().replace('numnod = 4','numnod = 10')
s=s.replace('[-0.25d0, -0.75d0, -1.50d0, -2.50d0]','['+','.join(str(-5-10*i)+'d0' for i in range(10))+']').replace('[0.50d0, 0.50d0, 1.00d0, 1.00d0]','10.0d0')
s=s.replace('disnod(numnod+1) = 1.0d0','disnod(numnod+1) = [5.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,10.0d0,5.0d0]')
Path(sys.argv[1]).write_text(s)
GRID
mapfile -t SRC < <(python3 - "$B/grid.f90" <<'PY'
from pathlib import Path
import sys
lines=Path('tests/fpm/run_ppa_wu05a26_backend_compile.sh').read_text().splitlines();inside=False
for raw in lines:
 s=raw.strip()
 if s=='MODULE_SRC=(':inside=True;continue
 if inside and s==')':break
 if inside and s:
  if s=='tests/fsi/fsi04_real_headcalc_stubs.f90':s=sys.argv[1]
  print(s)
PY
)
mapfile -t SRC < <(python3 tests/support/augment_bartholomeus_backend_sources.py "${SRC[@]}"|awk '$0!="tests/fsi/fsi04_real_headcalc_stubs.f90"')
mkdir "$B/o";objs=();for s in "${SRC[@]}";do o="$B/o/$(basename "${s%.*}").o";gfortran -std=f2008 -ffree-line-length-none -O2 -J"$B/o" -I"$B/o" -c "$s" -o "$o";objs+=("$o");done
gfortran -std=f2008 -ffree-line-length-none -O2 -J"$B/o" -I"$B/o" "${objs[@]}" research/rfm/a27/test_perf06_panels.f90 -o "$B/t"
"$B/t"|tee "$OUT/perf06_stage1.csv";grep -Fq A27_PERF06_STAGE1=PASS "$OUT/perf06_stage1.csv"
