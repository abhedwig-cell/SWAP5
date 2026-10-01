#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"; B="${TMPDIR:-/tmp}/ppa_wu05c3p_assembly"; rm -rf "$B";mkdir -p "$B"
F=(-std=f2008 -Wall -Wextra -Werror -Wno-unused-dummy-argument -fcheck=all -J"$B" -I"$B" -ffree-line-length-none)
cat > "$B/mod_transaction_reference.f90" <<'EOF'
module mod_transaction_reference
  implicit none
  type,abstract :: transaction_state_t
  contains
    procedure(clone_ifc),deferred :: clone
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
"$FC" "${F[@]}" -c "$B/mod_transaction_reference.f90" -o "$B/tr.o"
"$FC" "${F[@]}" -c src/solver/mod_soil_water_solver_contract.f90 -o "$B/sw.o"
"$FC" "${F[@]}" -c src/solver/mod_process_hydraulic_view.f90 -o "$B/h.o"
"$FC" "${F[@]}" -c src/process/mod_soil_temperature_contract.f90 -o "$B/t.o"
for f in mod_oxygen_macro_zero_depth mod_oxygen_scalar_bracket mod_bartholomeus_micro mod_bartholomeus_macro mod_bartholomeus_response mod_bartholomeus_soil_diffusivity mod_bartholomeus_temperature mod_bartholomeus_microbial; do
 "$FC" "${F[@]}" -c "src/physics/oxygen/$f.f90" -o "$B/$f.o"
done
"$FC" "${F[@]}" -c src/process/mod_bartholomeus_runtime_input.f90 -o "$B/rv.o"
"$FC" "${F[@]}" -c src/physics/oxygen/mod_bartholomeus_parameter_contract.f90 -o "$B/pc.o"
"$FC" "${F[@]}" -c src/physics/oxygen/mod_bartholomeus_response_assembly.f90 -o "$B/as.o"
"$FC" "${F[@]}" tests/physics/test_bartholomeus_response_assembly.f90 "$B"/*.o -o "$B/test"
"$B/test"
