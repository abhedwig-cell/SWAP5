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
python3 - "$BUILD/grid_stubs.f90" research/rfm/a27/test_profile01.f90 > "$BUILD/sources.txt" <<'RESOLVE'
from pathlib import Path
import re,sys
root=Path('.')
modules={}
for path in sorted((root/'src').rglob('*.f90')):
    text=path.read_text()
    for name in re.findall(r'^\s*module\s+(\w+)\s*$',text,re.M|re.I):
        modules[name.lower()]=str(path)
stub=Path(sys.argv[1])
for name in re.findall(r'^\s*module\s+(\w+)\s*$',stub.read_text(),re.M|re.I):
    modules[name.lower()]=str(stub)
seen=set();visiting=set();ordered=[]
def uses(text):
    return re.findall(r'^\s*use\s*(?:,\s*(?:intrinsic|non_intrinsic)\s*)?(?:::\s*)?(\w+)',text,re.M|re.I)
def visit_source(source):
    if source in seen:return
    if source in visiting:raise RuntimeError('cycle '+source)
    visiting.add(source)
    text=Path(source).read_text()
    for name in uses(text):
        dep=modules.get(name.lower())
        if dep and dep!=source:visit_source(dep)
    visiting.remove(source);seen.add(source);ordered.append(source)
test=Path(sys.argv[2]).read_text()
for name in uses(test):
    dep=modules.get(name.lower())
    if dep:visit_source(dep)
print('\n'.join(ordered))
RESOLVE
B="$BUILD/o2";mkdir -p "$B";objects=()
while IFS= read -r source; do
  [[ -z "$source" ]] && continue
  obj="$B/$(basename "${source%.*}").o"
  gfortran -std=f2008 -ffree-line-length-none -fcheck=all -fbacktrace -O2 -J"$B" -I"$B" -c "$source" -o "$obj"
  objects+=("$obj")
done < "$BUILD/sources.txt"
gfortran -std=f2008 -ffree-line-length-none -fcheck=all -fbacktrace -O2 -J"$B" -I"$B" "${objects[@]}" research/rfm/a27/test_profile01.f90 -o "$B/profile"
"$B/profile" | tee "$OUTDIR/profile01.txt"
grep -Fq 'A27_PROFILE01_EXECUTED=PASS' "$OUTDIR/profile01.txt"
python3 research/rfm/a27/analyze_profile01.py "$OUTDIR/profile01.txt" "$OUTDIR"
# Static zero-waste ownership checks.
grep -Fq 'result%mb_sorptivity_cm_sqrt_day=s' src/runtime/mod_rfm_wall_hydraulic_history_binding.f90
if grep -Fq 'mb_sorptivity_cm_sqrt_day' src/runtime/mod_rfm_production_candidate_composer.f90; then
  echo "PROFILE01 static gate: production composer consumes MB sorptivity unexpectedly" >&2; exit 1
fi
grep -Fq 'if (request%source_rate_cm_per_day <= 0.0_real64)' src/process/macropore/mod_rfm_unponded_activation.f90
