#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-top03-trace-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
STUB="${1:?stub path required}"
GEOMETRY="${2:?geometry id required}"
HEAD_SOURCE="src/legacy/b1_10_port/headcalc.f90"
HEAD_SOURCE="$BUILD/top03_research_headcalc.f90"
python3 tests/fapp/make_top03_terminal_trace_probe.py "$HEAD_SOURCE"
fail(){ echo "FAPP09_GATE_FAIL $*" >&2; exit 91; }

python3 - "$BUILD/compile-order.txt" "$STUB" "$HEAD_SOURCE" <<'PY'
from pathlib import Path
import re,sys
test=Path("tests/fapp/test_sw_rib_top03_surface_transition.f90")
stub=Path(sys.argv[2])
top=Path("tests/fmr/mod_fmr04_fixed_top_provider.f90")
headcalc=Path(sys.argv[3])
candidates=[stub,top,Path("tests/fapp/mod_top03_observed_top.f90")]+sorted(p for p in Path("src").rglob("*.f90") if "src/legacy/" not in p.as_posix())+[headcalc,test]
mr=re.compile(r"^\s*module\s+(?!procedure\b|subroutine\b|function\b)([a-zA-Z_]\w*)",re.I)
ur=re.compile(r"^\s*use(?:\s*,\s*[^:]*)?\s*(?:::\s*)?([a-zA-Z_]\w*)",re.I)
mods={}; uses={}
for p in candidates:
    ls=p.read_text(errors="replace").splitlines()
    mods[p]=[m.group(1).lower() for l in ls if (m:=mr.match(l))]
    uses[p]=[u.group(1).lower() for l in ls if (u:=ur.match(l))]
providers={}
for p in [stub,top]:
    for m in mods[p]: providers[m]=p
for p in candidates:
    if p in (stub,top,headcalc,test): continue
    for m in mods[p]: providers.setdefault(m,p)
required=set(); unresolved=set()
def add(p):
    if p in required:return
    required.add(p)
    for m in uses.get(p,[]):
        q=providers.get(m)
        if q is not None and q!=p:add(q)
        elif q is None and (m.startswith("mod_") or m=="variables"):unresolved.add((p.as_posix(),m))
add(test); add(headcalc)
if unresolved:
    for p,m in sorted(unresolved): print(f"unresolved {m} used by {p}",file=sys.stderr)
    raise SystemExit(2)
deps={p:{providers[m] for m in uses.get(p,[]) if m in providers and providers[m] in required and providers[m]!=p} for p in required}
order=[]; temp=set(); done=set()
def visit(p):
    if p in done:return
    if p in temp:raise RuntimeError(f"cycle {p}")
    temp.add(p)
    for q in sorted(deps[p],key=lambda x:x.as_posix()):visit(q)
    temp.remove(p); done.add(p); order.append(p)
for p in sorted(required,key=lambda x:x.as_posix()):visit(p)
Path(sys.argv[1]).write_text("\n".join(p.as_posix() for p in order)+"\n")
print(f"FAPP09_COMPILE_CLOSURE_FILES={len(order)}")
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  while IFS= read -r source; do
    key="$(printf '%s' "$source" | tr '/.' '__')"
    obj="$OUT/$key.o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done < "$BUILD/compile-order.txt"
  gfortran -O"$opt" "${objects[@]}" -o "$OUT/test" || fail "link O$opt"
  "$OUT/test" "$GEOMETRY" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  cat "$OUT/output.txt"
  echo "TOP03_TRANSITION_O${opt}=COMPLETED"
done



