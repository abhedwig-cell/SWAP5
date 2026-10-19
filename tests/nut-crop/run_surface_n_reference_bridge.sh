#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT
python3 - "$build/roots" <<'PY'
import pathlib,shlex,sys
s=pathlib.Path('tests/publication/run_pub_p1e02_postsolver_rollback.sh').read_text()
part=s.split('MODULE_SRC=(',1)[1].split('\n)',1)[0]
roots=[]
for line in part.splitlines():
    line=line.split('#',1)[0].strip()
    if line: roots.extend(shlex.split(line))
roots += ['src/process/mod_b111_surface_n_gross_budget.f90',
          'src/runtime/mod_b111_surface_n_reference_bridge.f90']
pathlib.Path(sys.argv[1]).write_text('\n'.join(roots)+'\n')
PY
mapfile -t roots < "$build/roots"
python3 tests/publication/resolve_fortran_module_closure.py "${roots[@]}" > "$build/closure"
mapfile -t sources < "$build/closure"
for opt in 0 2; do
  out="$build/o$opt"
  mkdir -p "$out"
  for source in "${sources[@]}"; do
    gfortran -std=f2008 -ffree-line-length-none -fopenmp -fcheck=all -O"$opt" \
      -J "$out" -I "$out" -c "$source" \
      -o "$out/$(basename "${source%.f90}").o"
  done
  gfortran -std=f2008 -ffree-line-length-none -fopenmp -fcheck=all -O"$opt" \
    -J "$out" -I "$out" \
    "$out/mod_b111_surface_n_gross_budget.o" \
    "$out/mod_b111_surface_n_reference_bridge.o" \
    tests/nut-crop/test_surface_n_reference_bridge.f90 -o "$out/test"
  "$out/test" > "$out/output"
  grep -Fq 'MC_NUT01_REFERENCE_GROSS_N_BRIDGE=PASS' "$out/output"
  echo "MC_NUT01_REFERENCE_GROSS_N_BRIDGE_O$opt=PASS"
done
cmp "$build/o0/output" "$build/o2/output"
