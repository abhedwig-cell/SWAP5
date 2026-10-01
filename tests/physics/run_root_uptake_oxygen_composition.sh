#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}"
B="${TMPDIR:-/tmp}/ppa_wu05c3p_compose"
rm -rf "$B"; mkdir -p "$B"
"$FC" -std=f2008 -Wall -Wextra -Werror -fcheck=all -J"$B" -I"$B" -c src/solver/mod_process_hydraulic_view.f90 -o "$B/view.o"
"$FC" -std=f2008 -Wall -Wextra -Werror -fcheck=all -J"$B" -I"$B" -c src/process/mod_root_water_uptake_process.f90 -o "$B/root.o"
"$FC" -std=f2008 -Wall -Wextra -Werror -fcheck=all -J"$B" -I"$B" -c src/process/mod_root_uptake_oxygen_composition.f90 -o "$B/oxy.o"
"$FC" -std=f2008 -Wall -Wextra -Werror -fcheck=all -J"$B" -I"$B" tests/physics/test_root_uptake_oxygen_composition.f90 "$B/root.o" "$B/oxy.o" -o "$B/test"
"$B/test"
