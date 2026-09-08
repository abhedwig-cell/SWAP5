#!/usr/bin/env bash
set -euo pipefail

BASE=fe5e55d5d5ebff42e8212cba8df15652e5f1a52b

git diff --quiet "$BASE" -- src/solver/mod_soil_water_solver_contract.f90 || {
  echo 'FAIL: F-SI17 modified the common soil-water solver contract'; exit 1;
}
git diff --quiet "$BASE" -- src/solver/mod_reference_richards_state_binding.f90 || {
  echo 'FAIL: F-SI17 modified reference-Richards state binding'; exit 1;
}
git diff --quiet "$BASE" -- src/solver/mod_reference_richards_workspace.f90 || {
  echo 'FAIL: F-SI17 modified reference-Richards workspace'; exit 1;
}

python3 tools/fsi/fsi17_process_hydraulic_view_gate.py

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

build_and_run() {
  local opt="$1"
  local outdir="$work/$opt"
  mkdir -p "$outdir"

  gfortran -std=f2008 -Wall -Wextra -fcheck=all -O"$opt" -J"$outdir" -I"$outdir" \
    -c src/solver/mod_soil_water_solver_contract.f90 -o "$outdir/contract.o"
  gfortran -std=f2008 -Wall -Wextra -fcheck=all -O"$opt" -J"$outdir" -I"$outdir" \
    -c src/solver/mod_process_hydraulic_view.f90 -o "$outdir/view.o"
  gfortran -std=f2008 -Wall -Wextra -fcheck=all -O"$opt" -J"$outdir" -I"$outdir" \
    tests/fsi/test_fsi17_process_hydraulic_view.f90 "$outdir/contract.o" "$outdir/view.o" \
    -o "$outdir/test_fsi17"
  "$outdir/test_fsi17" > "$outdir/output.txt"
  grep -F 'FSI17_PROCESS_HYDRAULIC_VIEW PASS' "$outdir/output.txt"
}

build_and_run 0
build_and_run 2
cmp "$work/0/output.txt" "$work/2/output.txt"

echo 'FSI17_O0_O2_OUTPUT_IDENTITY PASS'
echo 'FSI17_GATE PASS'
