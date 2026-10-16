#!/usr/bin/env bash
set -euo pipefail
build_dir="${TMPDIR:-/tmp}/ppa_wu05d_contract"
rm -rf "$build_dir"
mkdir -p "$build_dir"
gfortran -std=f2008 -Wall -Wextra -Werror -fcheck=all -O0 -J"$build_dir" -I"$build_dir" research/ppa_wu05d/mod_root_uptake_compensation_contract.f90 tests/physics/test_ppa_wu05d_compensation_contract.f90 -o "$build_dir/test_o0"
"$build_dir/test_o0"
gfortran -std=f2008 -Wall -Wextra -Werror -fcheck=all -O2 -J"$build_dir" -I"$build_dir" research/ppa_wu05d/mod_root_uptake_compensation_contract.f90 tests/physics/test_ppa_wu05d_compensation_contract.f90 -o "$build_dir/test_o2"
"$build_dir/test_o2"
