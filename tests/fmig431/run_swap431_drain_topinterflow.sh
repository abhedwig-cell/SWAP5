#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${TMPDIR:-/tmp}/swap431-topinterflow-$$"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/o0" "$BUILD/o2"
run_one() {
  local opt="$1" out="$2"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace "$opt" -J"$out" -I"$out" -c src/solver/mod_soil_water_solver_contract.f90 -o "$out/contract.o"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace "$opt" -J"$out" -I"$out" -c src/solver/mod_process_hydraulic_view.f90 -o "$out/view.o"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace "$opt" -J"$out" -I"$out" -c src/process/mod_drainage_spatial_distribution.f90 -o "$out/dist.o"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace "$opt" -J"$out" -I"$out" -c src/process/mod_drainage_top_interflow_distribution.f90 -o "$out/topint.o"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace "$opt" -J"$out" -I"$out" tests/fmig431/test_swap431_drain_topinterflow.f90 "$out/contract.o" "$out/view.o" "$out/dist.o" "$out/topint.o" -o "$out/test"
  "$out/test" > "$out/output.txt"
  grep -Fx 'SW431_DRAIN_TOPINTERFLOW=PASS' "$out/output.txt"
}
run_one -O0 "$BUILD/o0"
run_one -O2 "$BUILD/o2"
diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
