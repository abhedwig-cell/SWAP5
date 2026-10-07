#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${TMPDIR:-/tmp}/swap431-frost-rootdrain-$$"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/o0" "$BUILD/o2"
run_one() {
  local opt="$1" out="$2"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror "$opt" -J"$out" -I"$out" -c src/solver/mod_soil_water_solver_contract.f90 -o "$out/contract.o"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror "$opt" -J"$out" -I"$out" -c src/solver/mod_process_hydraulic_view.f90 -o "$out/view.o"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror "$opt" -J"$out" -I"$out" -c src/process/mod_frost_bottom_boundary_effect.f90 -o "$out/bottom.o"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror "$opt" -J"$out" -I"$out" -c src/process/mod_frost_drainage_effect.f90 -o "$out/drain.o"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror "$opt" -J"$out" -I"$out" -c src/process/mod_root_water_uptake_process.f90 -o "$out/root.o"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra "$opt" -J"$out" -I"$out" -c src/process/mod_root_frost_stress.f90 -o "$out/rootfrost.o"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror "$opt" -J"$out" -I"$out" tests/fmig431/test_swap431_frost_rootdrain.f90 "$out/contract.o" "$out/view.o" "$out/bottom.o" "$out/drain.o" "$out/root.o" "$out/rootfrost.o" -o "$out/test"
  "$out/test" > "$out/output.txt"
  grep -Fx 'SW431_FROST_ROOTDRAIN=PASS' "$out/output.txt"
}
run_one -O0 "$BUILD/o0"
run_one -O2 "$BUILD/o2"
diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
