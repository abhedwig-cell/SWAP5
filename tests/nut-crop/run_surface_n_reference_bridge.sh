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
          'src/runtime/mod_b111_surface_n_reference_bridge.f90',
          'src/runtime/mod_b111_n_gross_direct_binding.f90',
          'src/runtime/mod_b111_n_reference_mineral_trial.f90']
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
  gfortran -std=f2008 -ffree-line-length-none -fopenmp -fcheck=all -O"$opt" \
    -J "$out" -I "$out" \
    "$out/mod_b111_n_gross_direct_binding.o" \
    tests/nut-crop/test_n_direct_gross_binding.f90 -o "$out/direct-test"
  "$out/direct-test" > "$out/direct-output"
  grep -Fq 'MC_NUT01_GROSS_DIRECT_REFERENCE_BOUNDING=PASS' "$out/direct-output"
  echo "MC_NUT01_GROSS_DIRECT_REFERENCE_O$opt=PASS"
  gfortran -std=f2008 -ffree-line-length-none -fopenmp -fcheck=all -O"$opt" \
    -J "$out" -I "$out" \
    "$out/mod_soil_n_pool_state.o" \
    "$out/mod_b111_soil_n_storage_conversion.o" \
    "$out/mod_b111_soil_n_transport.o" \
    "$out/mod_b111_soil_n_mineral_owner.o" \
    "$out/mod_b111_n_gross_direct_binding.o" \
    "$out/mod_b111_n_reference_mineral_trial.o" \
    tests/nut-crop/test_n_reference_mineral_trial.f90 -o "$out/mineral-trial"
  "$out/mineral-trial" > "$out/mineral-trial-output"
  grep -Fq 'MC_NUT01_REFERENCE_MINERAL_TRIAL=PASS' "$out/mineral-trial-output"
  echo "MC_NUT01_REFERENCE_MINERAL_TRIAL_O$opt=PASS"
done
cmp "$build/o0/output" "$build/o2/output"
cmp "$build/o0/direct-output" "$build/o2/direct-output"
cmp "$build/o0/mineral-trial-output" "$build/o2/mineral-trial-output"
