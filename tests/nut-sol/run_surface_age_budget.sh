#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT
for opt in 0 2; do
  gfortran -std=f2008 -Wall -Wextra -Werror -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -O"$opt" -J "$build" -I "$build" \
    src/process/mod_b111_surface_age_budget.f90 \
    tests/nut-sol/test_surface_age_budget.f90 -o "$build/age-o$opt"
  "$build/age-o$opt" > "$build/out-o$opt"
  grep -Fq 'MC_SOL01_SURFACE_AGE_BUDGET=PASS' "$build/out-o$opt"
  echo "MC_SOL01_SURFACE_AGE_BUDGET_O${opt}=PASS"
  gfortran -std=f2008 -Wall -Wextra -Werror -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -O"$opt" -J "$build" -I "$build" \
    src/process/mod_b111_surface_age_budget.f90 src/process/mod_b111_surface_age_owner.f90 \
    tests/nut-sol/test_surface_age_owner.f90 -o "$build/owner-o$opt"
  "$build/owner-o$opt" > "$build/owner-out-o$opt"
  grep -Fq "MC_SOL01_SURFACE_AGE_OWNER=PASS" "$build/owner-out-o$opt"
  echo "MC_SOL01_SURFACE_AGE_OWNER_O${opt}=PASS"
  gfortran -std=f2008 -Wall -Wextra -Werror -fcheck=all -ffpe-trap=invalid,zero,overflow \
    -O"$opt" -J "$build" -I "$build" \
    src/process/mod_b111_surface_age_budget.f90 src/process/mod_b111_surface_age_soil_handoff.f90 \
    tests/nut-sol/test_surface_age_soil_handoff.f90 -o "$build/handoff-o$opt"
  "$build/handoff-o$opt" > "$build/handoff-out-o$opt"
  grep -Fq 'MC_SOL01_SURFACE_AGE_SOIL_HANDOFF=PASS' "$build/handoff-out-o$opt"
  echo "MC_SOL01_SURFACE_AGE_SOIL_HANDOFF_O${opt}=PASS"
  # Compile admitted age kernel with new opt-in surface flux (zero-default unchanged).
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all \
    -O"$opt" -J "$build" -I "$build" -c src/process/mod_solute_compartment_state.f90 \
    -o "$build/solute-compartment-o$opt.o"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all \
    -O"$opt" -J "$build" -I "$build" -c src/process/mod_b111_age_tracer_substep.f90 \
    -o "$build/age-process-o$opt.o"
done
cmp "$build/out-o0" "$build/out-o2"
cmp "$build/owner-out-o0" "$build/owner-out-o2"
cmp "$build/handoff-out-o0" "$build/handoff-out-o2"
echo 'MC_SOL01_SURFACE_AGE_BUDGET_O0_O2=PASS'
