#!/usr/bin/env bash
# EXPERIMENTAL ONLY. Not a replacement for either qualified incumbent gate.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-shared-irr-XXXXXX")"
trap 'rm -rf "$BUILD"' EXIT
fail() { echo "SHARED_IRR_FAIL $*" >&2; exit 1; }
ROOT_TEST=tests/f-app07/test_mc_irr01_allocated_root_restart.f90
SENSOR_TEST=tests/f-app07/test_mc_irr01_allocated_sensor_restart.f90
python3 - "$ROOT_TEST" "$SENSOR_TEST" <<'PY' > "$BUILD/sources"
from pathlib import Path
import re, sys
tests = [Path(x) for x in sys.argv[1:]]
files = list(Path('src').rglob('*.f90')) + [
    Path('tests/f-app07/mc_irr01_realistic_headcalc_stubs.f90'),
    Path('tests/fmr/mod_fmr04_fixed_top_provider.f90')]
modules = {}
for path in files:
    text = path.read_text(errors='ignore')
    found = re.search(r'^\s*module\s+(?!procedure\b)(\w+)', text, re.I | re.M)
    if found:
        modules[found.group(1).lower()] = path
seen, ordered, visiting = set(), [], []
def visit(name):
    name = name.lower()
    if name in seen: return
    if name in visiting: raise RuntimeError('module dependency cycle: ' + name)
    path = modules.get(name)
    if path is None: return
    visiting.append(name)
    text = path.read_text(errors='ignore')
    uses = re.findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)', text, re.I | re.M)
    for dep in dict.fromkeys(u.lower() for u in uses): visit(dep)
    visiting.pop()
    seen.add(name)
    ordered.append(path)
for test in tests:
    text = test.read_text()
    for dep in re.findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)', text, re.I | re.M):
        visit(dep)
for source in ordered: print(source)
PY
COMMON=(-std=f2008 -ffree-line-length-none -w -fopenmp -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
started=$SECONDS
for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"
  objects=()
  while IFS= read -r source; do
    obj="$OUT/$(echo "$source" | tr '/' '_' | sed 's/\.f90$/.o/')"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done < "$BUILD/sources"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/legacy/b1_10_port/headcalc.f90 -o "$OUT/headcalc_legacy.o" || fail "headcalc O$opt"
  objects+=("$OUT/headcalc_legacy.o")
  for case in root sensor; do
    if [[ "$case" == root ]]; then source="$ROOT_TEST"; else source="$SENSOR_TEST"; fi
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$OUT/$case.o" || fail "$case driver O$opt"
    gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/$case.o" -o "$OUT/$case" || fail "link $case O$opt"
    "$OUT/$case" > "$OUT/$case.output" 2>&1 || { cat "$OUT/$case.output" >&2; fail "$case runtime O$opt"; }
    grep -Fq 'MC_IRR01_MANAGEMENT_REAL_RICHARDS=PASS' "$OUT/$case.output" || fail "$case Richards"
    grep -Fq 'MC_IRR01_MANAGEMENT_AUTHORITATIVE_MASS=PASS' "$OUT/$case.output" || fail "$case mass"
  done
done
for case in root sensor; do
  cmp "$BUILD/o0/$case.output" "$BUILD/o2/$case.output" || fail "$case O0/O2 drift"
  cat "$BUILD/o0/$case.output"
  echo "SHARED_IRR_${case^^}_SHA256=$(sha256sum "$BUILD/o0/$case.output" | cut -d ' ' -f 1)"
done
echo "SHARED_IRR_COMPILED_SOURCES_PER_OPT=$(wc -l < "$BUILD/sources")"
echo "SHARED_IRR_WALL_SECONDS=$SECONDS"
echo "SHARED_IRR_SCIENCE=PASS"
