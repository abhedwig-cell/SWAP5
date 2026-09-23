#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fapp09-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail(){ echo "FAPP09_GATE_FAIL $*" >&2; exit 91; }

python3 - "$BUILD/compile-order.txt" <<'PY'
from pathlib import Path
import re,sys
test=Path("tests/fapp/test_fapp09_ribasim_external_surface_water_profile.f90")
stub=Path("tests/fsi/fsi04_real_headcalc_stubs.f90")
top=Path("tests/fmr/mod_fmr04_fixed_top_provider.f90")
headcalc=Path("src/legacy/b1_10_port/headcalc.f90")
candidates=[stub,top]+sorted(p for p in Path("src").rglob("*.f90") if "src/legacy/" not in p.as_posix())+[headcalc,test]
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

for required in   src/process/mod_drainage_extended_exchange.f90   src/runtime/mod_fmr_drainage_response_binding.f90   src/runtime/mod_fmr_surface_water_head_forcing_adapter.f90   src/runtime/mod_fmr_surface_water_swap_participant.f90   src/runtime/mod_fmr_serialized_reference_backend.f90; do
  grep -Fqx "$required" "$BUILD/compile-order.txt" || fail "missing compile closure: $required"
done
echo 'FAPP09_COMPILE_CLOSURE=PASS'

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
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  for marker in     FAPP09_TYPED_EXTERNAL_HEAD_MATERIALIZER=PASS     FAPP09_SURFACE_WATER_STATE_OWNER_XOR=PASS     FAPP09_RECOMPOSITION_DISCARD_REPLAY=PASS     FAPP09_POSITIVE_DRAINAGE_TRANSACTION=PASS     FAPP09_NEGATIVE_INFILTRATION_TRANSACTION=PASS     FAPP09_STALE_ORIGIN_FAIL_CLOSED=PASS     FAPP09_RIBASIM_EXTERNAL_SURFACE_WATER_PROFILE=PASS; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  grep '^FAPP09_' "$OUT/output.txt" > "$OUT/stable.txt"
  echo "FAPP09_O${opt}=PASS"
done
diff -u "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt"
cat "$BUILD/o0/stable.txt"
echo 'FAPP09_O0_O2_STABLE_IDENTITY=PASS'
echo 'F-APP09 OWNER GATE PASS'
