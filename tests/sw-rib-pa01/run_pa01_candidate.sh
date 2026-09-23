#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-sw-rib-pa01-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "SW_RIB_PA01_FAIL $*" >&2; exit 91; }
BASE=a2d99ddd149ffaa422d9c422f96bd66e92c8555d

expected_src="$(printf '%s\n' \
  src/process/mod_drainage_extended_exchange.f90 \
  src/runtime/mod_fmr_drainage_response_binding.f90 \
  src/runtime/mod_ribasim_surface_water_profile_contract.f90 | LC_ALL=C sort)"
actual_src="$(git diff --name-only "$BASE..HEAD" -- src | LC_ALL=C sort)"
[[ "$actual_src" == "$expected_src" ]] || {
  printf 'expected production scope:\n%s\nactual:\n%s\n' "$expected_src" "$actual_src" >&2
  fail "production source scope"
}
echo 'SW_RIB_PA01_EXACT_THREE_PRODUCTION_FILES=PASS'
! grep -Fq 'configure_fixed_weir_surface_water' src/runtime/mod_ribasim_surface_water_profile_contract.f90 || fail 'coupled wrapper configures internal fixed-weir context'
echo 'SW_RIB_PA01_WRAPPER_NEVER_CONFIGURES_FIXED_WEIR=PASS'

python3 - "$BUILD/compile-order.txt" <<'PY'
from pathlib import Path
import re, sys
test = Path("tests/sw-rib-pa01/test_pa01_profile_runtime.f90")
stub = Path("tests/fsi/fsi04_real_headcalc_stubs.f90")
top = Path("tests/fmr/mod_fmr04_fixed_top_provider.f90")
headcalc = Path("src/legacy/b1_10_port/headcalc.f90")
candidates=[stub,top]+sorted(p for p in Path("src").rglob("*.f90") if "src/legacy/" not in p.as_posix())+[headcalc,test]
module_re=re.compile(r"^\s*module\s+(?!procedure\b|subroutine\b|function\b)([a-zA-Z_]\w*)",re.I)
use_re=re.compile(r"^\s*use(?:\s*,\s*[^:]*)?\s*(?:::\s*)?([a-zA-Z_]\w*)",re.I)
mods={}; uses={}
for p in candidates:
    ls=p.read_text(errors="replace").splitlines()
    mods[p]=[m.group(1).lower() for line in ls if (m:=module_re.match(line))]
    uses[p]=[m.group(1).lower() for line in ls if (m:=use_re.match(line))]
providers={}
for p in [stub,top]:
    for m in mods[p]: providers[m]=p
for p in candidates:
    if p in (stub,top,headcalc,test): continue
    for m in mods[p]: providers.setdefault(m,p)
required=set(); unresolved=set()
def add(p):
    if p in required: return
    required.add(p)
    for m in uses.get(p,[]):
        q=providers.get(m)
        if q is not None and q!=p: add(q)
        elif q is None and (m.startswith("mod_") or m=="variables"): unresolved.add((p.as_posix(),m))
add(test); add(headcalc)
if unresolved:
    for p,m in sorted(unresolved): print(f"unresolved {m} used by {p}",file=sys.stderr)
    raise SystemExit(2)
deps={p:{providers[m] for m in uses.get(p,[]) if m in providers and providers[m] in required and providers[m]!=p} for p in required}
order=[]; temp=set(); done=set()
def visit(p):
    if p in done:return
    if p in temp: raise RuntimeError(f"cycle {p}")
    temp.add(p)
    for q in sorted(deps[p],key=lambda x:x.as_posix()):visit(q)
    temp.remove(p);done.add(p);order.append(p)
for p in sorted(required,key=lambda x:x.as_posix()):visit(p)
Path(sys.argv[1]).write_text("\n".join(p.as_posix() for p in order)+"\n")
print(f"SW_RIB_PA01_COMPILE_CLOSURE_FILES={len(order)}")
PY

for required in src/process/mod_drainage_extended_exchange.f90 src/runtime/mod_fmr_drainage_response_binding.f90 src/runtime/mod_ribasim_surface_water_profile_contract.f90; do
  grep -Fq "$required" "$BUILD/compile-order.txt" || fail "missing compile dependency $required"
done

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  while IFS= read -r source; do
    key="$(printf '%s' "$source" | tr '/.' '__')"; obj="$OUT/$key.o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done < "$BUILD/compile-order.txt"
  gfortran -O"$opt" "${objects[@]}" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "O$opt candidate execution"; }
  for marker in \
    'SW_RIB_PA01_PROFILE_CONTRACT=PASS' \\
    'SW_RIB_PA01_WRAPPER_OWNER_XOR=PASS' \
    'SW_RIB_SWM01_Q4B_POSITIVE_DRAINAGE_SINGLE_BOOKING=PASS' \
    'SW_RIB_SWM01_Q4B_NEGATIVE_INFILTRATION_SINGLE_BOOKING=PASS' \
    'SW_RIB_SWM01_Q4B_SIGNED_HARD_MASS_CLOSURE=PASS' \
    'SW_RIB_SWM01_Q4B_INVALID_PROCESS_ROLLBACK=PASS' \
    'SW_RIB_PA01_CANDIDATE_RUNTIME=PASS'; do
      grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing O$opt marker $marker"; }
  done
  echo "SW_RIB_PA01_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail "O0/O2 identity"; }
echo 'SW_RIB_PA01_O0_O2_EXACT_IDENTITY=PASS'

python3 tests/sw-rib-pa01/test_storage_geometry_epsilon.py > "$BUILD/q1h.txt"
grep -Fq 'SW_RIB_SWM01_Q1H_CONFIRMATORY_CHARACTERIZATION=PASS' "$BUILD/q1h.txt" || fail "Q1H replay"
grep -Fq 'SW_RIB_SWM01_Q1H_EPSILON=1.0e-05 MAX_ERROR_M3=3.342027508469389e-06' "$BUILD/q1h.txt" || fail "frozen epsilon evidence drift"
echo 'SW_RIB_PA01_STORAGE_GEOMETRY_EPSILON=PASS'

bash tests/fpm/run_fpm08d7_fixed_weir_process_checkpoint.sh > "$BUILD/fixed-weir.txt"
grep -Fq 'FPM08D7_FIXED_WEIR_PROCESS_CHECKPOINT PASS' "$BUILD/fixed-weir.txt" || fail "standalone fixed-weir preservation"
echo 'SW_RIB_PA01_STANDALONE_FIXED_WEIR_PRESERVATION=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path("src/runtime/mod_ribasim_surface_water_profile_contract.f90").read_text()
assert "e7fc8ade52a4bedeec10e508d2065577f33eb76a" in p
assert "2026.1.1" in p and "2026.1.0" in p
print("SW_RIB_PA01_RIBASIM_PROVENANCE_SEAM=PASS")
PY

git diff --check "$BASE..HEAD"
cat "$BUILD/o0/output.txt"
echo "SW_RIB_PA01_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'SW-RIB-PA01 CANDIDATE GATE PASS'
