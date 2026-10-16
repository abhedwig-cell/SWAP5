#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${B12_RUNTIME_BUILD:-${TMPDIR:-/tmp}/ppa-wu05b12-normal-runtime}"
case "$BUILD" in
  */ppa-wu05b12-normal-runtime*) ;;
  *) echo "Invalid owned B12 build directory" >&2; exit 2 ;;
esac
rm -rf "$BUILD"; mkdir -p "$BUILD"
cd "$ROOT"

python3 - <<'PY' > "$BUILD/sources"
import pathlib, re
files=list(pathlib.Path('src').rglob('*.f90'))+[pathlib.Path('tests/fsi/fsi04_real_headcalc_stubs.f90')]
modules={}
for path in files:
    text=path.read_text(errors='ignore')
    match=re.search(r'^\s*module\s+(?!procedure\b)(\w+)',text,re.I|re.M)
    if match: modules[match.group(1).lower()]=path
seen=set(); ordered=[]; visiting=[]
def visit(name):
    if name in seen: return
    if name in visiting: raise RuntimeError('module dependency cycle: '+name)
    path=modules.get(name)
    if path is None: return
    visiting.append(name)
    text=path.read_text(errors='ignore')
    uses=re.findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)',text,re.I|re.M)
    for used in dict.fromkeys(item.lower() for item in uses): visit(used)
    visiting.pop(); seen.add(name); ordered.append(path)
visit('mod_fmr_serialized_multiswap_runtime')
visit('mod_fmr_committed_restart')
visit('mod_fmr_production_application_bootstrap')
for path in ordered: print(path)
PY

for opt in ${B12_RUNTIME_OPTS:-0 2}; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  while IFS= read -r source; do
    object="$OUT/$(basename "${source%.*}").o"
    gfortran -std=f2008 -ffree-line-length-none -w -fopenmp -fcheck=all -fbacktrace \
      -ffpe-trap=invalid,zero,overflow -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$object"
    objects+=("$object")
  done < "$BUILD/sources"
  gfortran -std=f2008 -ffree-line-length-none -w -fopenmp -fcheck=all -fbacktrace \
    -ffpe-trap=invalid,zero,overflow -O"$opt" -J "$OUT" -I "$OUT" \
    -c src/legacy/b1_10_port/headcalc.f90 -o "$OUT/headcalc_legacy.o"
  objects+=("$OUT/headcalc_legacy.o")
  gfortran -std=f2008 -ffree-line-length-none -w -fopenmp -fcheck=all -fbacktrace \
    -ffpe-trap=invalid,zero,overflow -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/frost/mod_ppa_wu05b12_analytic_fixture.f90 -o "$OUT/analytic_fixture.o"
  objects+=("$OUT/analytic_fixture.o")
  gfortran -std=f2008 -ffree-line-length-none -w -fopenmp -fcheck=all -fbacktrace \
    -ffpe-trap=invalid,zero,overflow -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/frost/test_ppa_wu05b12_normal_runtime.f90 -o "$OUT/test.o"
  objects+=("$OUT/test.o")
  gfortran -fopenmp -O"$opt" "${objects[@]}" -o "$OUT/test"
  GFORTRAN_UNBUFFERED_ALL=y "$OUT/test" > "$OUT/output.txt"
  grep -Fq 'PPA_WU05B12_NORMAL_RESPONSE_DRAIN_RUNTIME=PASS' "$OUT/output.txt"
  cat "$OUT/output.txt"
  echo "PPA_WU05B12_NORMAL_RESPONSE_DRAIN_RUNTIME_O${opt}=PASS"
done
if [[ -f "$BUILD/o0/output.txt" && -f "$BUILD/o2/output.txt" ]]; then
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'PPA_WU05B12_NORMAL_RESPONSE_DRAIN_O0_O2_SEMANTIC_IDENTITY=PASS'
fi
