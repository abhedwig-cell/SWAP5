#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fapp09-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "FAPP09_GATE_FAIL $*" >&2; exit 89; }

python3 - "$BUILD/compile-order.txt" <<'PY'
from pathlib import Path
import re, sys

test = Path("tests/fapp/test_fapp09_external_surface_water_profile.f90")
stub = Path("tests/fsi/fsi04_real_headcalc_stubs.f90")
top = Path("tests/fmr/mod_fmr04_fixed_top_provider.f90")
headcalc = Path("src/legacy/b1_10_port/headcalc.f90")
candidates = [stub, top]
candidates += sorted(p for p in Path("src").rglob("*.f90") if "src/legacy/" not in p.as_posix())
candidates += [headcalc, test]

module_re = re.compile(r"^\s*module\s+(?!procedure\b|subroutine\b|function\b)([a-zA-Z_]\w*)", re.I)
use_re = re.compile(r"^\s*use(?:\s*,\s*[^:]*)?\s*(?:::\s*)?([a-zA-Z_]\w*)", re.I)
mods_by_file, uses_by_file = {}, {}
for p in candidates:
    mods, uses = [], []
    for line in p.read_text(errors="replace").splitlines():
        m = module_re.match(line)
        if m: mods.append(m.group(1).lower())
        u = use_re.match(line)
        if u: uses.append(u.group(1).lower())
    mods_by_file[p], uses_by_file[p] = mods, uses

providers = {}
for p in [stub, top]:
    for m in mods_by_file[p]: providers[m] = p
for p in candidates:
    if p in (stub, top, headcalc, test): continue
    for m in mods_by_file[p]: providers.setdefault(m, p)

required, unresolved = set(), set()
def add_file(p):
    if p in required: return
    required.add(p)
    for m in uses_by_file.get(p, []):
        q = providers.get(m)
        if q is not None and q != p: add_file(q)
        elif q is None and (m.startswith("mod_") or m in {"variables"}):
            unresolved.add((p.as_posix(), m))
add_file(test)
add_file(headcalc)
if unresolved:
    for p,m in sorted(unresolved): print(f"unresolved required module {m} used by {p}", file=sys.stderr)
    raise SystemExit(2)

deps={}
for p in required:
    deps[p]={providers[m] for m in uses_by_file.get(p,[]) if m in providers and providers[m] in required and providers[m]!=p}
order=[]; temporary=set(); permanent=set()
def visit(p):
    if p in permanent: return
    if p in temporary: raise RuntimeError(f"module dependency cycle at {p}")
    temporary.add(p)
    for q in sorted(deps[p], key=lambda x:x.as_posix()): visit(q)
    temporary.remove(p); permanent.add(p); order.append(p)
for p in sorted(required,key=lambda x:x.as_posix()): visit(p)
Path(sys.argv[1]).write_text("\n".join(p.as_posix() for p in order)+"\n")
print(f"FAPP09_COMPILE_CLOSURE_FILES={len(order)}")
PY

for required in   src/process/mod_drainage_extended_exchange.f90   src/runtime/mod_fmr_drainage_response_binding.f90   src/runtime/mod_fmr_surface_water_head_forcing_adapter.f90   src/runtime/mod_fmr_surface_water_swap_participant.f90   src/runtime/mod_fmr_serialized_reference_backend.f90; do
  grep -Fq "$required" "$BUILD/compile-order.txt" || fail "missing compile dependency $required"
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
  for marker in     'FAPP09_TYPED_HEAD_MATERIALIZER_GUARDS=PASS'     'FAPP09_SURFACE_WATER_OWNER_XOR=PASS'     'FAPP09_MISMATCH_RECOMPOSE_SAME_ORIGIN=PASS'     'FAPP09_POSITIVE_DRAINAGE_KERNEL_COMMIT=PASS'     'FAPP09_NEGATIVE_INFILTRATION_KERNEL_COMMIT=PASS'     'FAPP09_NO_PERSISTENT_SURFACE_WATER_STATE=PASS'     'FAPP09_STALE_ORIGIN_FAIL_CLOSED=PASS'     'FAPP09_EXTERNAL_SURFACE_WATER_PROFILE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || { cat "$OUT/output.txt" >&2; fail "missing marker O$opt $marker"; }
  done
  grep '^FAPP09_' "$OUT/output.txt" > "$OUT/stable.txt"
  echo "FAPP09_O${opt}=PASS"
done
diff -u "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt"
cat "$BUILD/o0/stable.txt"
echo 'FAPP09_O0_O2_IDENTITY=PASS'
echo 'FAPP09_PRODUCTION_OWNER_GATE=PASS'
