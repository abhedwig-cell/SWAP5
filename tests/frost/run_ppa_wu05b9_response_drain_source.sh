#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/ppa-wu05b9-response-drain-source"
mkdir -p "$BUILD"
# Pure process input carrier seam only; actual solver/runtime is tested separately.
cat > "$BUILD/mod_soil_water_solver_contract.f90" <<'STUB'
module mod_soil_water_solver_contract
 use iso_fortran_env,only:real64
 implicit none
 type::soil_water_physical_state_t
  integer::active_nodes=0
  real(real64),allocatable::pressure_head(:),water_content(:)
  real(real64)::ponding_depth=0._real64,groundwater_level=0._real64
 end type
end module
STUB
for opt in 0 2; do
 mkdir -p "$BUILD/o$opt"
 gfortran -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow -O"$opt" \
  -J "$BUILD/o$opt" -I "$BUILD/o$opt" \
  "$BUILD/mod_soil_water_solver_contract.f90" \
  "$ROOT/src/solver/mod_process_hydraulic_view.f90" \
  "$ROOT/src/process/mod_drainage_process.f90" \
  "$ROOT/tests/frost/test_ppa_wu05b5_corrected_drain_globals.f90" \
  "$ROOT/reference/swap-4.3.1/frost-corrections/FROST-DRAIN-01/frozencond.f90" \
  "$ROOT/src/process/mod_frost_bottom_boundary_effect.f90" \
  "$ROOT/src/process/mod_frost_drainage_effect.f90" \
  "$ROOT/tests/frost/test_ppa_wu05b9_response_drain_source.f90" -o "$BUILD/o$opt/test"
 "$BUILD/o$opt/test" > "$BUILD/o$opt/output.txt"
 cat "$BUILD/o$opt/output.txt"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'PPA_WU05B9_RESPONSE_SOURCE_O0_O2_IDENTITY=PASS'
