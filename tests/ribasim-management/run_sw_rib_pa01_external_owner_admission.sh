#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-sw-rib-pa01-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "SW_RIB_PA01_FAIL $*" >&2; exit 87; }

python3 - "$BUILD/compile-order.txt" <<'PY'
from pathlib import Path
import re, sys

root = Path(".")
test = Path("tests/ribasim-management/test_sw_rib_pa01_external_owner_admission.f90")
stub = Path("tests/fsi/fsi04_real_headcalc_stubs.f90")
top = Path("tests/fmr/mod_fmr04_fixed_top_provider.f90")
headcalc = Path("src/legacy/b1_10_port/headcalc.f90")

candidates = [stub, top]
candidates += sorted(p for p in Path("src").rglob("*.f90") if "src/legacy/" not in p.as_posix())
candidates += [headcalc, test]

module_re = re.compile(r"^\s*module\s+(?!procedure\b|subroutine\b|function\b)([a-zA-Z_]\w*)", re.I)
use_re = re.compile(r"^\s*use(?:\s*,\s*[^:]*)?\s*(?:::\s*)?([a-zA-Z_]\w*)", re.I)

mods_by_file = {}
uses_by_file = {}
for p in candidates:
    text = p.read_text(errors="replace").splitlines()
    mods = []
    uses = []
    for line in text:
        m = module_re.match(line)
        if m:
            mods.append(m.group(1).lower())
        u = use_re.match(line)
        if u:
            uses.append(u.group(1).lower())
    mods_by_file[p] = mods
    uses_by_file[p] = uses

providers = {}
# Explicit test fixtures override any legacy-global providers.
for p in [stub, top]:
    for m in mods_by_file[p]:
        providers[m] = p
for p in candidates:
    if p in (stub, top, headcalc, test):
        continue
    for m in mods_by_file[p]:
        providers.setdefault(m, p)

required = set()
unresolved = set()
def add_file(p):
    if p in required:
        return
    required.add(p)
    for m in uses_by_file.get(p, []):
        q = providers.get(m)
        if q is not None and q != p:
            add_file(q)
        elif q is None and (m.startswith("mod_") or m in {"variables"}):
            unresolved.add((p.as_posix(), m))

add_file(test)
# The legacy reference wrapper calls HeadCalc as an external procedure rather
# than via a module interface, so it is an explicit link root.
add_file(headcalc)

if unresolved:
    for p,m in sorted(unresolved):
        print(f"unresolved required module {m} used by {p}", file=sys.stderr)
    raise SystemExit(2)

# File-level topological order.
deps = {}
for p in required:
    d = set()
    for m in uses_by_file.get(p, []):
        q = providers.get(m)
        if q is not None and q in required and q != p:
            d.add(q)
    deps[p] = d

order = []
temporary = set()
permanent = set()
def visit(p):
    if p in permanent:
        return
    if p in temporary:
        raise RuntimeError(f"module dependency cycle at {p}")
    temporary.add(p)
    for q in sorted(deps[p], key=lambda x:x.as_posix()):
        visit(q)
    temporary.remove(p)
    permanent.add(p)
    order.append(p)

for p in sorted(required, key=lambda x:x.as_posix()):
    visit(p)

Path(sys.argv[1]).write_text("\n".join(p.as_posix() for p in order)+"\n")
print(f"SW_RIB_PA01_COMPILE_CLOSURE_FILES={len(order)}")
PY

grep -Fq 'src/process/mod_drainage_extended_exchange.f90' "$BUILD/compile-order.txt" || fail 'extended exchange absent from compile closure'
grep -Fq 'src/runtime/mod_fmr_drainage_response_binding.f90' "$BUILD/compile-order.txt" || fail 'response binding absent from compile closure'
grep -Fq 'src/runtime/mod_fmr_serialized_reference_backend.f90' "$BUILD/compile-order.txt" || fail 'serialized backend absent from compile closure'
echo 'SW_RIB_PA01_COMPILE_CLOSURE=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  while IFS= read -r source; do
    key="$(printf '%s' "$source" | tr '/.' '__')"
    obj="$OUT/$key.o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done < "$BUILD/compile-order.txt"

  gfortran -O"$opt" "${objects[@]}" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "Q4B O$opt execution"
  }

  for marker in \
    'SW_RIB_PA01_POSITIVE_DRAINAGE_SINGLE_BOOKING=PASS' \
    'SW_RIB_PA01_NEGATIVE_INFILTRATION_SINGLE_BOOKING=PASS' \
    'SW_RIB_PA01_SIGNED_HARD_MASS_CLOSURE=PASS' \
    'SW_RIB_PA01_MISSING_EXTERNAL_HEAD_FAIL_CLOSED=PASS' \
    'SW_RIB_PA01_FIXED_WEIR_OWNER_CONFLICT_FAIL_CLOSED=PASS' \
    'SW_RIB_PA01_INVALID_PROCESS_ROLLBACK=PASS' \
    'SW_RIB_PA01_EXTERNAL_OWNER_ADMISSION=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing O$opt marker: $marker"
    }
  done
  echo "SW_RIB_PA01_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 output identity'
}

cat "$BUILD/o0/output.txt"
echo "SW_RIB_PA01_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'SW_RIB_PA01_O0_O2_EXACT_IDENTITY=PASS'
echo 'SW_RIB_PA01_GATE=PASS'
