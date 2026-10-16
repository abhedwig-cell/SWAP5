#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-mc-irr01-realistic-sensor-${GITHUB_RUN_ID:-local}-$$"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
fail(){ echo "MC_IRR01_MANAGEMENT_PHYSICAL_FAIL $*" >&2; exit 1; }
TEST=tests/f-app07/test_mc_irr01_realistic_sensor_restart.f90

python3 - "$TEST" <<'PY' > "$BUILD/sources"
import pathlib,re,sys
test=pathlib.Path(sys.argv[1])
files=list(pathlib.Path('src').rglob('*.f90'))+[pathlib.Path('tests/f-app07/mc_irr01_realistic_headcalc_stubs.f90'), pathlib.Path('tests/fmr/mod_fmr04_fixed_top_provider.f90')]
modules={}
for path in files:
    text=path.read_text(errors='ignore')
    m=re.search(r'^\s*module\s+(?!procedure\b)(\w+)',text,re.I|re.M)
    if m: modules[m.group(1).lower()]=path
seen=set(); ordered=[]; visiting=[]
def visit(name):
    name=name.lower()
    if name in seen: return
    if name in visiting: raise RuntimeError('module dependency cycle: '+name)
    path=modules.get(name)
    if path is None: return
    visiting.append(name)
    text=path.read_text(errors='ignore')
    uses=re.findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)',text,re.I|re.M)
    for used in dict.fromkeys(u.lower() for u in uses): visit(used)
    visiting.pop(); seen.add(name); ordered.append(path)
text=test.read_text()
for used in re.findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)',text,re.I|re.M): visit(used)
for path in ordered: print(path)
PY

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  while IFS= read -r source; do
    obj="$OUT/$(echo "$source" | tr '/' '_' | sed 's/\.f90$/.o/')"
    gfortran -std=f2008 -ffree-line-length-none -w -fopenmp -fcheck=all -fbacktrace       -ffpe-trap=invalid,zero,overflow -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done < "$BUILD/sources"
  gfortran -std=f2008 -ffree-line-length-none -w -fopenmp -fcheck=all -fbacktrace     -ffpe-trap=invalid,zero,overflow -O"$opt" -J "$OUT" -I "$OUT"     -c src/legacy/b1_10_port/headcalc.f90 -o "$OUT/headcalc_legacy.o" || fail "legacy headcalc O$opt"
  objects+=("$OUT/headcalc_legacy.o")
  gfortran -std=f2008 -ffree-line-length-none -w -fopenmp -fcheck=all -fbacktrace     -ffpe-trap=invalid,zero,overflow -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/test.o" || fail "test compile O$opt"
  objects+=("$OUT/test.o")
  gfortran -fopenmp -O"$opt" "${objects[@]}" -o "$OUT/test" || fail "link O$opt"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
  grep -Fq 'MC_IRR01_MANAGEMENT_REAL_RICHARDS=PASS' "$OUT/output.txt" || fail "runtime O$opt"
  grep -Fq 'MC_IRR01_MANAGEMENT_AUTHORITATIVE_MASS=PASS' "$OUT/output.txt" || fail "mass O$opt"
  echo "MC_IRR01_MANAGEMENT_PHYSICAL_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail "O0/O2 drift"; }
cat "$BUILD/o0/output.txt"
echo "MC_IRR01_MANAGEMENT_PHYSICAL_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'MC_IRR01_MANAGEMENT_PHYSICAL_MASS=PASS'
