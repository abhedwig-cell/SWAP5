#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"; B="${TMPDIR:-/tmp}/c3a_active"; rm -rf "$B";mkdir -p "$B"
F=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -J"$B" -I"$B")
cat > "$B/mod_process_hydraulic_view.f90" <<'EOF'
module mod_process_hydraulic_view
 use iso_fortran_env,only:real64
 type::process_hydraulic_view_t
  integer::active_nodes=0
  real(real64),allocatable::pressure_head(:),water_content(:)
 end type
end module
EOF
cat > "$B/mod_soil_temperature_contract.f90" <<'EOF'
module mod_soil_temperature_contract
 use iso_fortran_env,only:real64
 type::soil_temperature_field_view_t
  integer::active_nodes=0
  real(real64),allocatable::temperature_c(:)
 end type
end module
EOF
"$FC" "${F[@]}" -c "$B/mod_process_hydraulic_view.f90" -o "$B/h.o"
"$FC" "${F[@]}" -c "$B/mod_soil_temperature_contract.f90" -o "$B/t.o"
mods=(mod_oxygen_macro_zero_depth mod_oxygen_scalar_bracket mod_bartholomeus_micro mod_bartholomeus_macro mod_bartholomeus_response mod_bartholomeus_profile_response mod_bartholomeus_soil_diffusivity mod_bartholomeus_temperature mod_bartholomeus_microbial mod_bartholomeus_waterfilm mod_bartholomeus_waterfilm_independent)
for m in "${mods[@]}"; do "$FC" "${F[@]}" -c "src/physics/oxygen/$m.f90" -o "$B/$m.o"; done
"$FC" "${F[@]}" -c src/process/mod_bartholomeus_runtime_input.f90 -o "$B/runtime.o"
"$FC" "${F[@]}" -c src/physics/oxygen/mod_bartholomeus_parameter_contract.f90 -o "$B/params.o"
"$FC" "${F[@]}" -c src/physics/oxygen/mod_bartholomeus_waterfilm_provider.f90 -o "$B/wfp.o"
"$FC" "${F[@]}" -c src/physics/oxygen/mod_bartholomeus_response_assembly.f90 -o "$B/assembly.o"
"$FC" "${F[@]}" -c src/physics/oxygen/mod_bartholomeus_factor_provider.f90 -o "$B/provider.o"
"$FC" "${F[@]}" tests/physics/test_bartholomeus_active_chain.f90 "$B"/*.o -o "$B/test"
"$B/test"
