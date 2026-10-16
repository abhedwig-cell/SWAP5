#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq128-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_VQ128_FAIL $*" >&2; exit 1; }

SUBJECT=ba3699f970d48b6b15db24fac1d1ec619f7fcb32
[[ -z "$(git diff --name-only "$SUBJECT"..HEAD -- src)" ]] || fail "qualification mutated production source"
[[ "$(git rev-parse HEAD:src/process/mod_drainage_extended_exchange.f90)" == 25d76013d25c2eaa2d254865149c740bc3257617 ]] || fail "extended exchange subject drift"
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_drainage_response_binding.f90)" == 263cf55b2c336d149ba41b4d04f510e10c4207e2 ]] || fail "drainage binding subject drift"
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == 0cdf05c1fc066f80aad7807c35a4e718fdecdb09 ]] || fail "serialized backend subject drift"
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_surface_water_head_forcing_adapter.f90)" == 1029cd4658a28f4aaf21db3cd480872c2d17722a ]] || fail "head materializer subject drift"
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_surface_water_swap_participant.f90)" == 5fd5007cf8e523d3b2cd4236114e887d0c383f0a ]] || fail "participant subject drift"
echo 'F_VQ128_SUBJECT_POSTIMAGES=PASS'

python3 - "$BUILD/compile-order.txt" <<'PY'
from pathlib import Path
import re,sys
test=Path("tests/fvq/test_fvq128_fapp09_independent.f90")
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
print(f"F_VQ128_COMPILE_CLOSURE_FILES={len(order)}")
PY

for required in   src/process/mod_drainage_extended_exchange.f90   src/runtime/mod_fmr_drainage_response_binding.f90   src/runtime/mod_fmr_serialized_reference_backend.f90   src/runtime/mod_fmr_surface_water_head_forcing_adapter.f90   src/runtime/mod_fmr_surface_water_swap_participant.f90; do
  grep -Fqx "$required" "$BUILD/compile-order.txt" || fail "missing compile closure: $required"
done

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
  for marker in     F_VQ128_SINGLE_LEVEL_SCOPE=PASS     F_VQ128_OWNER_XOR=PASS     F_VQ128_ACCEPTED_WINDOW_POSITIVE_EXCHANGE=PASS     F_VQ128_MISMATCH_DISCARD_REPLAY=PASS     F_VQ128_BASE_STATE_PRESERVED=PASS     F_VQ128_ACCEPTED_WINDOW_NEGATIVE_EXCHANGE=PASS     F_VQ128_SIGNED_TRANSACTION_COMMIT=PASS     F_VQ128_FAPP09_INDEPENDENT=PASS; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  grep '^F_VQ128_' "$OUT/output.txt" > "$OUT/stable.txt"
  echo "F_VQ128_O${opt}=PASS"
done

diff -u "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt"
cat "$BUILD/o0/stable.txt"
echo "F_VQ128_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/stable.txt" | awk '{print $1}')"
echo 'F_VQ128_O0_O2_IDENTITY=PASS'
echo 'F-VQ128 INDEPENDENT QUALIFICATION PASS'
