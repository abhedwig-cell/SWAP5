#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${B12_RUNTIME_BUILD:-${TMPDIR:-/tmp}/ppa-wu05b12-low-air-runtime}"
case "$BUILD" in
  */ppa-wu05b12-low-air-runtime*) ;;
  *) echo "Invalid owned B12 build directory" >&2; exit 2 ;;
esac
if [[ ${B12_RUNTIME_RELINK_ONLY:-0} != 1 ]]; then
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

else
  python3 - "$ROOT" "$BUILD" <<'VERIFY'
import gzip,hashlib,json,pathlib,subprocess,sys
r=pathlib.Path(sys.argv[1]);b=pathlib.Path(sys.argv[2])
assert subprocess.check_output(["git","rev-parse","HEAD:src"],cwd=r,text=True).strip()=="7be5920b9c04eb3c985deeeb89207a2992ad2e65"
record=json.loads(gzip.decompress((r/"docs/audits/evidence/PPA_WU05B12_PARTIAL_RECOVERY.json.gz").read_bytes()))
for p,d in record["manifest"].items():
 if p.startswith("src/") or p=="tests/frost/mod_ppa_wu05b12_analytic_fixture.f90" or p=="tests/fsi/fsi04_real_headcalc_stubs.f90":
  assert hashlib.sha256((r/p).read_bytes()).hexdigest()==d,p
assert (b/"sources").is_file()
print("B12_UNCHANGED_CURRENT_WHOLE_MODULE_SOURCE_FOR_RELINK=PASS")
VERIFY
fi

for opt in ${B12_RUNTIME_OPTS:-0 2}; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  if [[ ${B12_RUNTIME_RELINK_ONLY:-0} != 1 ]]; then
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
  else
    for object in "$OUT"/*.o; do
      [[ $(basename "$object") == test.o ]] || objects+=("$object")
    done
    [[ -f "$OUT/mod_fmr_production_application_bootstrap.o" && -f "$OUT/analytic_fixture.o" ]] || exit 2
  fi
  gfortran -std=f2008 -ffree-line-length-none -w -fopenmp -fcheck=all -fbacktrace \
    -ffpe-trap=invalid,zero,overflow -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/frost/test_ppa_wu05b12_low_air_runtime.f90 -o "$OUT/test.o"
  objects+=("$OUT/test.o")
  gfortran -fopenmp -O"$opt" "${objects[@]}" -o "$OUT/test"
  : > "$OUT/output.txt"
  for family in 1 2 3 4 5; do
    GFORTRAN_UNBUFFERED_ALL=y "$OUT/test" "$family" > "$OUT/family-$family.txt"
    grep -Fq 'PPA_WU05B12_LOW_AIR_LOW_AIR_DRAIN_RUNTIME=PASS' "$OUT/family-$family.txt"
    cat "$OUT/family-$family.txt" >> "$OUT/output.txt"
    echo "PPA_WU05B12_LOW_AIR_O${opt}_FAMILY_${family}_FRESH_PROCESS=PASS"
  done
  grep -Fq 'PPA_WU05B12_LOW_AIR_LOW_AIR_DRAIN_RUNTIME=PASS' "$OUT/output.txt"
  cat "$OUT/output.txt"
  echo "PPA_WU05B12_LOW_AIR_LOW_AIR_DRAIN_RUNTIME_O${opt}=PASS"
done
if [[ -f "$BUILD/o0/output.txt" && -f "$BUILD/o2/output.txt" ]]; then
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'PPA_WU05B12_LOW_AIR_LOW_AIR_DRAIN_O0_O2_SEMANTIC_IDENTITY=PASS'
fi
