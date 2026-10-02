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
python3 - "$B/grid.f90" research/rfm/a27/test_perf03.f90 > "$B/src" <<'PY'
from pathlib import Path
import re,sys
mods={}
for p in sorted(Path('src').rglob('*.f90')):
 t=p.read_text()
 for m in re.findall(r'^\s*module\s+(\w+)\s*$',t,re.M|re.I):mods[m.lower()]=str(p)
p=Path(sys.argv[1])
for m in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):mods[m.lower()]=str(p)
seen=set();order=[]
def visit(p):
 if p in seen:return
 t=Path(p).read_text()
 for m in re.findall(r'^\s*use\s*(?:,\s*(?:intrinsic|non_intrinsic)\s*)?(?:::\s*)?(\w+)',t,re.M|re.I):
  q=mods.get(m.lower())
  if q:visit(q)
 seen.add(p);order.append(p)
for m in re.findall(r'^\s*use\s*(?:,\s*(?:intrinsic|non_intrinsic)\s*)?(?:::\s*)?(\w+)',Path(sys.argv[2]).read_text(),re.M|re.I):
 q=mods.get(m.lower())
 if q:visit(q)
print('\n'.join(order))
PY
mkdir "$B/o";objs=()
while IFS= read -r s;do [[ -z "$s" ]]&&continue;o="$B/o/$(basename "${s%.*}").o";gfortran -std=f2008 -ffree-line-length-none -O2 -J"$B/o" -I"$B/o" -c "$s" -o "$o";objs+=("$o");done < "$B/src"
gfortran -std=f2008 -ffree-line-length-none -O2 -J"$B/o" -I"$B/o" "${objs[@]}" research/rfm/a27/test_perf03.f90 -o "$B/p"
"$B/p"|tee "$OUT/perf03.csv"
grep -Fq 'A27_PERF03_EXECUTED=PASS' "$OUT/perf03.csv"
