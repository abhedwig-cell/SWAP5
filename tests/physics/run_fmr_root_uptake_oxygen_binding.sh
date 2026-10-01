#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"
B="${TMPDIR:-/tmp}/ppa_wu05c3p_runtime"
rm -rf "$B"; mkdir -p "$B"
F=(-std=f2008 -Wall -Wextra -Werror -Wno-unused-dummy-argument -fcheck=all -J"$B" -I"$B")
"$FC" "${F[@]}" -c src/solver/mod_soil_water_solver_contract.f90 -o "$B/contract.o"
"$FC" "${F[@]}" -c src/solver/mod_process_hydraulic_view.f90 -o "$B/view.o"
"$FC" "${F[@]}" -c src/kernel/mod_kernel_transactions.f90 -o "$B/transactions.o"
"$FC" "${F[@]}" -c src/process/mod_root_water_uptake_process.f90 -o "$B/root.o"
"$FC" "${F[@]}" -c src/runtime/mod_fmr_process_hydraulic_view_binding.f90 -o "$B/viewbind.o"
"$FC" "${F[@]}" -c src/runtime/mod_fmr_root_uptake_process_binding.f90 -o "$B/rootbind.o"
"$FC" "${F[@]}" -c src/process/mod_root_uptake_oxygen_composition.f90 -o "$B/compose.o"
"$FC" "${F[@]}" -c src/runtime/mod_fmr_root_uptake_oxygen_binding.f90 -o "$B/oxybind.o"
"$FC" "${F[@]}" tests/physics/test_fmr_root_uptake_oxygen_binding.f90 "$B"/*.o -o "$B/test"
"$B/test"
