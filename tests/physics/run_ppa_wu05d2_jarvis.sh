#!/usr/bin/env bash
set -euo pipefail
B="${TMPDIR:-/tmp}/wu05d2-$$"
mkdir -p "$B"
trap 'rm -rf "$B"' EXIT
for O in 0 2; do
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -O$O -J"$B" -I"$B" \
    src/solver/mod_soil_water_solver_contract.f90 \
    src/solver/mod_process_hydraulic_view.f90 \
    src/process/mod_root_water_uptake_process.f90 \
    src/process/mod_root_uptake_compensation.f90 \
    tests/physics/test_ppa_wu05d2_jarvis.f90 -o "$B/t$O"
  "$B/t$O" | tee "$B/o$O"
  grep -Fq PPA_WU05D2_JARVIS=PASS "$B/o$O"
done
cmp "$B/o0" "$B/o2"
echo PPA_WU05D2_JARVIS_O0_O2=PASS
