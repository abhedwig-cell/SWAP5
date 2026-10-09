#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
# Compile true transitive production Fortran sources, with no mocked .mod files.
mapfile -t SOURCES < <(python3 - "$ROOT" <<'PY'
from pathlib import Path
import re,sys
root=Path(sys.argv[1])
mp=re.compile(r'^\s*module\s+(?!procedure\b|function\b|subroutine\b)([a-z][\w]*)',re.I|re.M)
up=re.compile(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?([a-z][\w]*)',re.I|re.M)
by={}; deps={}
for path in sorted((root/'src').rglob('*.f90')):
    s=path.read_text(encoding='utf-8',errors='replace')
    deps[path]=[x.lower() for x in up.findall(s)]
    for x in mp.findall(s):
        x=x.lower()
        if x in by and by[x]!=path: raise SystemExit(f'duplicate module {x}')
        by[x]=path
order=[];seen=set();active=set()
def visit(name):
    if name not in by:
        if name.startswith('mod_'): raise SystemExit(f'missing module {name}')
        return
    path=by[name]
    if path in seen:return
    if path in active:raise SystemExit(f'cycle {path}')
    active.add(path)
    for child in deps[path]:visit(child)
    active.remove(path);seen.add(path);order.append(path.relative_to(root))
visit('mod_fmr_crop_accepted_hydraulic_provenance')
for p in order:print(p)
PY
)
test "${#SOURCES[@]}" -ge 8
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -Wno-error=function-elimination -fcheck=all)
for OPT in 0 2;do
    mkdir -p "$BUILD/o$OPT"
    (
      cd "$BUILD/o$OPT"
      for SOURCE in "${SOURCES[@]}";do
        gfortran "${COMMON[@]}" -O"$OPT" -J . -I . -c "$ROOT/$SOURCE"
      done
      gfortran "${COMMON[@]}" -O"$OPT" -J . -I . "$ROOT/tests/fmig431/test_crop_accepted_hydraulic_provenance.f90" ./*.o -o test
      ./test > out
    )
    grep -Fx 'SW431_CROP_ACCEPTED_HYDRAULIC_INVALID=PASS' "$BUILD/o$OPT/out"
done
cmp "$BUILD/o0/out" "$BUILD/o2/out"
echo 'SW431_CROP_ACCEPTED_HYDRAULIC_PROVENANCE_O0_O2=PASS'
