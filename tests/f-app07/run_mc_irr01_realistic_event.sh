#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-mc-irr01-realistic-event-${GITHUB_RUN_ID:-local}-$$"
rm -rf "$BUILD"; mkdir -p "$BUILD"
cleanup(){ if [[ ${MC_IRR01_KEEP_BUILD:-0} == 1 ]]; then echo "MC_IRR01_DIAGNOSTIC_BUILD=$BUILD"; else rm -rf "$BUILD"; fi; }
trap cleanup EXIT
cd "$ROOT"
fail(){ echo "MC_IRR01_MANAGEMENT_PHYSICAL_FAIL $*" >&2; exit 1; }
TEST=tests/f-app07/test_mc_irr01_realistic_event.f90

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
  : > "$OUT/output.txt"
  for budget in 1e-6 1e-7 1e-8; do
    "$OUT/test" "$budget" >> "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt budget $budget"; }
  done
  grep -Fq 'MC_IRR01_MANAGEMENT_REAL_RICHARDS=PASS' "$OUT/output.txt" || fail "runtime O$opt"
  grep -Fq 'MC_IRR01_MANAGEMENT_AUTHORITATIVE_MASS=PASS' "$OUT/output.txt" || fail "mass O$opt"
  echo "MC_IRR01_MANAGEMENT_PHYSICAL_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true; fail "O0/O2 drift"; }
cat "$BUILD/o0/output.txt"
echo "MC_IRR01_MANAGEMENT_PHYSICAL_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'MC_IRR01_REALISTIC_EVENT_MASS=PASS'
python3 - "$BUILD/o0/output.txt" <<'PY'
import sys,numpy as np
lines=open(sys.argv[1]).read().splitlines()
heads=np.array([[float(x) for x in s.split('=')[1].split()] for s in lines if s.startswith('MC_IRR01_EVENT_HEAD=')])
theta=np.array([[float(x) for x in s.split('=')[1].split()] for s in lines if s.startswith('MC_IRR01_EVENT_THETA=')])
assert heads.shape==(3,5) and theta.shape==(3,5)
eh=np.max(abs(heads[:2,1:]-heads[2,1:]),axis=1); ew=np.max(abs(theta[:2,1:]-theta[2,1:]),axis=1)
print('MC_IRR01_EVENT_REFINEMENT_HEAD=',eh.tolist(),'THETA=',ew.tolist())
assert eh[1] < eh[0] and ew[1] < ew[0], 'refinement does not reduce error'
assert eh[1] < 2e-3 and ew[1] < 2e-6, 'declared refined profile accuracy target missed'
print('MC_IRR01_EVENT_REFINEMENT=PASS')
PY
