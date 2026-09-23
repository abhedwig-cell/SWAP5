#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-sw-rib-pa01-bootstrap-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

python3 - "$BUILD/compile-order.txt" <<'PY'
from pathlib import Path
import re, sys

test = Path("tests/sw-rib-pa01/test_bootstrap_profile_contract.f90")
stub = Path("tests/fsi/fsi04_real_headcalc_stubs.f90")
headcalc = Path("src/legacy/b1_10_port/headcalc.f90")
candidates=[stub]
candidates += sorted(p for p in Path("src").rglob("*.f90") if "src/legacy/" not in p.as_posix())
candidates += [headcalc,test]

module_re=re.compile(r"^\s*module\s+(?!procedure\b|subroutine\b|function\b)([a-zA-Z_]\w*)",re.I)
use_re=re.compile(r"^\s*use(?:\s*,\s*[^:]*)?\s*(?:::\s*)?([a-zA-Z_]\w*)",re.I)
mods={}; uses={}
for p in candidates:
    ml=[]; ul=[]
    for line in p.read_text(errors="replace").splitlines():
        m=module_re.match(line)
        if m: ml.append(m.group(1).lower())
        u=use_re.match(line)
        if u: ul.append(u.group(1).lower())
    mods[p]=ml; uses[p]=ul
providers={}
for p in [stub]:
    for m in mods[p]: providers[m]=p
for p in candidates:
    if p in (stub,headcalc,test): continue
    for m in mods[p]: providers.setdefault(m,p)

required=set(); unresolved=set()
def add(p):
    if p in required: return
    required.add(p)
    for m in uses.get(p,[]):
        q=providers.get(m)
        if q is not None and q!=p: add(q)
        elif q is None and (m.startswith("mod_") or m=="variables"):
            unresolved.add((p.as_posix(),m))
add(test); add(headcalc)
if unresolved:
    for p,m in sorted(unresolved): print(f"unresolved {m} from {p}",file=sys.stderr)
    raise SystemExit(2)
deps={p:{providers[m] for m in uses.get(p,[]) if m in providers and providers[m] in required and providers[m]!=p} for p in required}
order=[]; temp=set(); perm=set()
def visit(p):
    if p in perm:return
    if p in temp: raise RuntimeError(f"cycle {p}")
    temp.add(p)
    for q in sorted(deps[p],key=lambda x:x.as_posix()): visit(q)
    temp.remove(p);perm.add(p);order.append(p)
for p in sorted(required,key=lambda x:x.as_posix()): visit(p)
Path(sys.argv[1]).write_text("\n".join(p.as_posix() for p in order)+"\n")
print(f"SW_RIB_PA01_BOOTSTRAP_COMPILE_FILES={len(order)}")
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace)
objects=()
while IFS= read -r source; do
  key="$(printf '%s' "$source" | tr '/.' '__')"
  obj="$BUILD/$key.o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done < "$BUILD/compile-order.txt"
gfortran "${objects[@]}" -o "$BUILD/test"
"$BUILD/test" | tee "$BUILD/output.txt"
grep -Fq 'SW_RIB_PA01_BOOTSTRAP_PROFILE_CONTRACT=PASS' "$BUILD/output.txt"
echo 'SW_RIB_PA01_BOOTSTRAP_PROFILE_GATE=PASS'
