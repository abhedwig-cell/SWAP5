#!/usr/bin/env bash
set -euo pipefail
B="${TMPDIR:-/tmp}/wu05d2-$$"
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
    src/process/mod_root_uptake_compensation.f90 \
    src/runtime/mod_root_uptake_compensation_execution.f90 \
    tests/physics/test_ppa_wu05d2_jarvis.f90 -o "$B/t$O"
  "$B/t$O" | tee "$B/o$O"
  grep -Fq PPA_WU05D2_JARVIS=PASS "$B/o$O"
done
python3 - <<'PY'
from pathlib import Path
p=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
assert 'call fmr_apply_bartholomeus_to_root_sink' in p
assert 'call apply_root_uptake_compensation' in p
reset='self%qrot = self%qrot_unmodified'
assert reset in p
assert p.index(reset) < p.index('call fmr_apply_bartholomeus_to_root_sink') < p.index('call apply_root_uptake_compensation')
assert p.index('call apply_root_uptake_compensation') < p.index('call bind_b110_root_sink_provider')
assert 'root_compensation_executed' in p
q=Path('src/process/mod_root_uptake_compensation.f90').read_text().lower()
for forbidden in ['mass_ledger','commit_receipt','restart_state','save ::']:
    assert forbidden not in q, forbidden
print('PPA_WU05D2_RUNTIME_ORDER=PASS')
PY
cmp "$B/o0" "$B/o2"
echo PPA_WU05D2_JARVIS_O0_O2=PASS
