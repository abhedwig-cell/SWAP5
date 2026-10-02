#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}";B="${TMPDIR:-/tmp}/ppa_wu05c3p_wf";rm -rf "$B";mkdir -p "$B"
F=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -J"$B" -I"$B" -ffree-line-length-none)
cat > "$B/mod_process_hydraulic_view.f90" <<'EOF'
module mod_process_hydraulic_view
 use iso_fortran_env,only:real64
 type::process_hydraulic_view_t
  integer::active_nodes=0
  real(real64),allocatable::pressure_head(:),water_content(:)
 end type
end module
EOF
cat > "$B/mod_transaction_reference.f90" <<'EOF'
module mod_transaction_reference
 implicit none
 type,abstract::transaction_state_t
 contains
  procedure(clone_ifc),deferred::clone
 end type
 abstract interface
  subroutine clone_ifc(self,copy)
   import transaction_state_t
   class(transaction_state_t),intent(in)::self
   class(transaction_state_t),allocatable,intent(out)::copy
  end subroutine
 end interface
end module
EOF
"$FC" "${F[@]}" -c "$B/mod_process_hydraulic_view.f90" -o "$B/h.o"
"$FC" "${F[@]}" -c "$B/mod_transaction_reference.f90" -o "$B/tr.o"
"$FC" "${F[@]}" -c src/process/mod_soil_temperature_contract.f90 -o "$B/t.o"
"$FC" "${F[@]}" -c src/process/mod_bartholomeus_runtime_input.f90 -o "$B/r.o"
"$FC" "${F[@]}" -c src/physics/oxygen/mod_bartholomeus_soil_diffusivity.f90 -o "$B/s.o"
"$FC" "${F[@]}" -c src/physics/oxygen/mod_bartholomeus_parameter_contract.f90 -o "$B/p.o"
"$FC" "${F[@]}" -c src/physics/oxygen/mod_bartholomeus_temperature.f90 -o "$B/temp.o"
"$FC" "${F[@]}" -c src/physics/oxygen/mod_bartholomeus_waterfilm.f90 -o "$B/w.o"
"$FC" "${F[@]}" -c src/physics/oxygen/mod_bartholomeus_waterfilm_independent.f90 -o "$B/wi.o"
"$FC" "${F[@]}" -c src/physics/oxygen/mod_bartholomeus_waterfilm_provider.f90 -o "$B/wp.o"
"$FC" "${F[@]}" tests/physics/test_bartholomeus_waterfilm_provider.f90 "$B"/*.o -o "$B/test"
"$B/test"
