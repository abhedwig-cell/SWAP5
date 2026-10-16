#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
bash tests/physics/run_bartholomeus_active_chain.sh
FC="${FC:-gfortran}";B="${TMPDIR:-/tmp}/c3a_active"
F=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -J"$B" -I"$B")
# Owner hydraulic/thermal types, physics, root sink and execution are production sources.
# Only the unrelated abstract transaction base is stubbed by the active-chain harness.
for path in src/process/mod_root_water_uptake_process.f90 src/process/mod_root_uptake_oxygen_composition.f90 \
 src/runtime/mod_fmr_bartholomeus_activation.f90 src/runtime/mod_fmr_bartholomeus_execution.f90;do
 "$FC" "${F[@]}" -c "$path" -o "$B/$(basename "$path" .f90).o"
done
"$FC" "${F[@]}" tests/physics/test_bartholomeus_runtime_boundaries.f90 "$B"/*.o -o "$B/runtime_boundaries"
"$B/runtime_boundaries"
