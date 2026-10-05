#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/ppa-wu05b8-low-air-runtime"
rm -rf "$BUILD"; mkdir -p "$BUILD"
cd "$ROOT"

python3 - "$BUILD" <<'PY' > "$BUILD/sources"
import pathlib, re, sys
# This front-geometry fixture needs the static legacy grid to match its typed
# nonuniform grid. Keep the historical shared stub untouched for preservation.
original=pathlib.Path('tests/fsi/fsi04_real_headcalc_stubs.f90').read_bytes()
old=b'  real(8), parameter :: disnod(numnod+1) = 1.0d0'
new=b'  real(8), parameter :: disnod(numnod+1) = [0.25d0, 0.50d0, 0.75d0, 1.0d0, 0.50d0]'
assert original.count(old)==1
stubs=pathlib.Path(sys.argv[1])/'consistent_grid_stubs.f90'
stubs.write_bytes(original.replace(old,new))
files=list(pathlib.Path('src').rglob('*.f90'))+[stubs]
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

for opt in 0 2; do
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
    -c tests/frost/test_ppa_wu05b8_low_air_runtime.f90 -o "$OUT/test.o"
  objects+=("$OUT/test.o")
  gfortran -fopenmp -O"$opt" "${objects[@]}" -o "$OUT/test"
  GFORTRAN_UNBUFFERED_ALL=y "$OUT/test" > "$OUT/output.txt"
  grep -Fq 'PPA_WU05B8_LOW_AIR_DRAIN_RUNTIME=PASS' "$OUT/output.txt"
  cat "$OUT/output.txt"
  echo "PPA_WU05B8_LOW_AIR_DRAIN_RUNTIME_O${opt}=PASS"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'PPA_WU05B8_LOW_AIR_DRAIN_O0_O2_SEMANTIC_IDENTITY=PASS'
