#!/usr/bin/env bash
set -euo pipefail
B="${TMPDIR:-/tmp}/salfro01-$$"
mkdir -p "$B"
trap 'rm -rf "$B"' EXIT
cat > "$B/mod_soil_water_solver_contract.f90" <<'EOF'
module mod_soil_water_solver_contract
 use iso_fortran_env,only:real64
 implicit none
 type::soil_water_physical_state_t
  integer::active_nodes=0
  real(real64),allocatable::pressure_head(:),water_content(:)
  real(real64)::ponding_depth=0._real64,groundwater_level=0._real64
 end type
end module
EOF
for O in 0 2; do
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -O$O -J"$B" -I"$B" \
    "$B/mod_soil_water_solver_contract.f90" \
    src/solver/mod_process_hydraulic_view.f90 \
    src/process/mod_root_water_uptake_process.f90 \
    src/process/mod_root_frost_stress.f90 \
    src/process/mod_root_uptake_compensation.f90 \
    src/runtime/mod_root_uptake_compensation_execution.f90 \
    tests/physics/test_ppa_wu05e_salt_frost_process.f90 -o "$B/t$O"
  "$B/t$O" | tee "$B/o$O"
  grep -Fq PPA_SALFRO01_INDEPENDENT_PROCESS_ORACLE=PASS "$B/o$O"
done
cmp "$B/o0" "$B/o2"
echo PPA_SALFRO01_PROCESS_O0_O2=PASS
