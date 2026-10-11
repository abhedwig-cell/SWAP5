#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/migmac02-provider-${GITHUB_RUN_ID:-local}-$$"; mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT
mapfile -t SRC < <(python3 - <<'PY'
from pathlib import Path
import re
test=Path('tests/fpm/test_ppa_wu05_migmac02_provider_geometry.f90')
mr=re.compile(r'^\s*module\s+(?!procedure\b)([a-z][a-z0-9_]*)',re.I|re.M)
ur=re.compile(r'^\s*use(?:\s*,[^:]*)?(?:\s*::)?\s*([a-z][a-z0-9_]*)',re.I|re.M)
def defs(p): return {x.lower() for x in mr.findall(p.read_text(errors='ignore'))}
def uses(p): return {x.lower() for x in ur.findall(p.read_text(errors='ignore'))}
owners={}
for p in sorted(Path('src').rglob('*.f90')):
 for m in defs(p): owners[m]=p
done=set(); visiting=set(); ordered=[]
def vm(m):
 if m in owners: vf(owners[m])
def vf(p):
 k=str(p)
 if k in done:return
 if k in visiting: raise SystemExit('cycle '+k)
 visiting.add(k)
 for m in sorted(uses(p)):vm(m)
 visiting.remove(k);done.add(k);ordered.append(p)
for m in sorted(uses(test)):vm(m)
for p in ordered:print(p)
PY
)
for opt in 0 2; do
 OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objs=()
 for f in "${SRC[@]}"; do o="$OUT/$(basename "${f%.*}").o"; gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -O"$opt" -J"$OUT" -I"$OUT" -c "$f" -o "$o"; objs+=("$o"); done
 gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -O"$opt" -J"$OUT" -I"$OUT" -c tests/fpm/test_ppa_wu05_migmac02_provider_geometry.f90 -o "$OUT/test.o"
 gfortran -O"$opt" "${objs[@]}" "$OUT/test.o" -o "$OUT/test"
 "$OUT/test" | tee "$OUT/out.txt"
 grep -Fq 'PPA_WU05_MIGMAC02_PROVIDER_TRIAL_GEOMETRY=PASS' "$OUT/out.txt"
done
echo 'PPA_WU05_MIGMAC02_PROVIDER_O0_O2=PASS'
