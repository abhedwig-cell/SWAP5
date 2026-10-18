#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT
# Reuse the already-admitted Reference production compilation roots, not stubs
# for the actual trace type or solver-side adapter.
python3 - "$build/roots" <<'PY'
import pathlib,shlex,sys
s=pathlib.Path('tests/publication/run_pub_p1e02_postsolver_rollback.sh').read_text()
part=s.split('MODULE_SRC=(',1)[1].split('\n)',1)[0]
roots=[]
for line in part.splitlines():
    line=line.split('#',1)[0].strip()
    if not line: continue
    roots.extend(shlex.split(line))
roots += [
 'src/process/mod_b111_surface_age_budget.f90',
 'src/process/mod_b111_surface_age_owner.f90',
 'src/runtime/mod_b111_surface_age_trace_bridge.f90']
pathlib.Path(sys.argv[1]).write_text('\n'.join(roots)+'\n')
PY
mapfile -t roots < "$build/roots"
python3 tests/publication/resolve_fortran_module_closure.py "${roots[@]}" > "$build/closure"
mapfile -t sources < "$build/closure"
for opt in 0 2; do
  dir="$build/o$opt"
  mkdir -p "$dir"
  for source in "${sources[@]}"; do
    gfortran -std=f2008 -ffree-line-length-none -fopenmp -fcheck=all -O"$opt" \
      -J "$dir" -I "$dir" -c "$source" -o "$dir/$(basename "${source%.f90}").o"
  done
  gfortran -std=f2008 -ffree-line-length-none -fopenmp -fcheck=all -O"$opt" \
    -J "$dir" -I "$dir" \
    "$dir/mod_b111_surface_age_budget.o" "$dir/mod_b111_surface_age_owner.o" \
    "$dir/mod_b111_surface_age_trace_bridge.o" \
    tests/nut-sol/test_surface_age_trace_bridge.f90 -o "$dir/test"
  "$dir/test" > "$build/output-$opt"
  grep -Fq 'MC_SOL01_REFERENCE_SURFACE_AGE_BRIDGE=PASS' "$build/output-$opt"
  echo "MC_SOL01_REFERENCE_SURFACE_AGE_BRIDGE_O${opt}=PASS"
done
cmp "$build/output-0" "$build/output-2"
echo 'MC_SOL01_REFERENCE_SURFACE_AGE_BRIDGE_O0_O2=PASS'
