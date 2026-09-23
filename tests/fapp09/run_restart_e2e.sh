#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fapp09-e2e-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail(){ echo "FAPP09_E2E_GATE_FAIL $*" >&2; exit 1; }

python3 - "$BUILD/compile-order.txt" <<'PY'
from pathlib import Path
import re,sys
stub=Path("tests/fsi/fsi04_real_headcalc_stubs.f90")
top=Path("tests/fmr/mod_fmr04_fixed_top_provider.f90")
headcalc=Path("src/legacy/b1_10_port/headcalc.f90")
test=Path("tests/fapp09/test_restart_e2e.f90")
candidates=[stub,top]+sorted(p for p in Path("src").rglob("*.f90") if "src/legacy/" not in p.as_posix())+[headcalc,test]
mr=re.compile(r"^\s*module\s+(?!procedure\b|subroutine\b|function\b)([A-Za-z_]\w*)",re.I)
ur=re.compile(r"^\s*use(?:\s*,\s*[^:]*)?\s*(?:::\s*)?([A-Za-z_]\w*)",re.I)
mods={};uses={}
for p in candidates:
 ls=p.read_text(errors="replace").splitlines();mods[p]=[];uses[p]=[]
 for l in ls:
  m=mr.match(l);u=ur.match(l)
  if m:mods[p].append(m.group(1).lower())
  if u:uses[p].append(u.group(1).lower())
providers={}
for p in [stub,top]:
 for m in mods[p]:providers[m]=p
for p in candidates:
 if p in (stub,top,headcalc,test):continue
 for m in mods[p]:providers.setdefault(m,p)
required=set();unresolved=set()
def add(p):
 if p in required:return
 required.add(p)
 for m in uses[p]:
  q=providers.get(m)
  if q is not None and q!=p:add(q)
  elif q is None and (m.startswith("mod_") or m=="variables"):unresolved.add((str(p),m))
add(test);add(headcalc)
if unresolved:
 print(unresolved,file=sys.stderr);raise SystemExit(2)
deps={p:{providers[m] for m in uses[p] if m in providers and providers[m] in required and providers[m]!=p} for p in required}
order=[];temp=set();perm=set()
def visit(p):
 if p in perm:return
 if p in temp:raise RuntimeError(f"cycle {p}")
 temp.add(p)
 for q in sorted(deps[p],key=str):visit(q)
 temp.remove(p);perm.add(p);order.append(p)
for p in sorted(required,key=str):visit(p)
Path(sys.argv[1]).write_text("\n".join(str(p) for p in order)+"\n")
print(f"FAPP09_E2E_COMPILE_CLOSURE_FILES={len(order)}")
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
 OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
 while read -r src; do
   obj="$OUT/$(basename "${src%.*}").o"
   gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
   objects+=("$obj")
 done < "$BUILD/compile-order.txt"
 gfortran -O"$opt" "${objects[@]}" -o "$OUT/test"
 "$OUT/test" > "$OUT/out.txt" 2>&1 || { cat "$OUT/out.txt" >&2; fail "O$opt"; }
 grep -Fq 'FAPP09_RESTART_E2E=PASS' "$OUT/out.txt" || fail "marker O$opt"
 echo "FAPP09_E2E_O${opt}=PASS"
done
cmp -s "$BUILD/o0/out.txt" "$BUILD/o2/out.txt" || fail "O0/O2 identity"
cat "$BUILD/o0/out.txt"
echo 'FAPP09_RESTART_E2E_GATE=PASS'
