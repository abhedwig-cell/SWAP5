#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fapp09-profile-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

python3 - "$BUILD/compile-order.txt" <<'PY'
from pathlib import Path
import re, sys
roots=[
 Path("src/adapter/mod_ribasim_surface_water_profile.f90"),
 Path("tests/fapp09/test_profile_contract.f90"),
]
candidates=sorted(p for p in Path("src").rglob("*.f90") if "src/legacy/" not in p.as_posix())+roots[1:]
module_re=re.compile(r"^\s*module\s+(?!procedure\b|subroutine\b|function\b)([A-Za-z_]\w*)",re.I)
use_re=re.compile(r"^\s*use(?:\s*,\s*[^:]*)?\s*(?:::\s*)?([A-Za-z_]\w*)",re.I)
mods={}; uses={}
for p in candidates:
    ls=p.read_text(errors="replace").splitlines()
    mods[p]=[m.group(1).lower() for l in ls if (m:=module_re.match(l))]
    uses[p]=[m.group(1).lower() for l in ls if (m:=use_re.match(l))]
providers={}
for p in candidates:
    for m in mods[p]: providers.setdefault(m,p)
required=set()
def add(p):
    if p in required:return
    required.add(p)
    for m in uses[p]:
        q=providers.get(m)
        if q is not None and q!=p:add(q)
add(roots[1])
deps={p:{providers[m] for m in uses[p] if m in providers and providers[m] in required and providers[m]!=p} for p in required}
order=[]; temp=set(); perm=set()
def visit(p):
    if p in perm:return
    if p in temp: raise RuntimeError(f"cycle {p}")
    temp.add(p)
    for q in sorted(deps[p],key=str):visit(q)
    temp.remove(p);perm.add(p);order.append(p)
visit(roots[1])
Path(sys.argv[1]).write_text("\n".join(str(p) for p in order)+"\n")
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace)
while read -r src; do
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$src" -o "$BUILD/$(basename "$src" .f90).o"
done < "$BUILD/compile-order.txt"
gfortran "$BUILD"/*.o -o "$BUILD/test_profile"
"$BUILD/test_profile" | tee "$BUILD/out.txt"
grep -Fq 'FAPP09_PROFILE_CONTRACT=PASS' "$BUILD/out.txt"
echo 'FAPP09_PROFILE_GATE=PASS'
