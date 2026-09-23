#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ftab02d-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT

python3 - <<'PY'
from pathlib import Path
contract=Path("src/solver/mod_soil_water_solver_contract.f90").read_text()
temporal=Path("src/solver/mod_reference_richards_temporal_indicator.f90").read_text()
expected="""subroutine constitutive_evaluate_ifc(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
       import :: constitutive_hydraulics_provider_t, real64
       class(constitutive_hydraulics_provider_t), intent(in) :: self
       real(real64), intent(in) :: pressure_head(:)
       real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
     end subroutine constitutive_evaluate_ifc"""
assert expected in contract
assert "procedure :: context_compatible => constitutive_context_incompatible" in contract
assert "select type (constitutive => request%evaluation%constitutive)" not in temporal
assert "b110_default_mvg_provider_t" not in temporal
assert "request%evaluation%constitutive%context_compatible(dt)" in temporal
assert "constitutive-dt-mismatch" in temporal
print("F_TAB02_D_HOT_EVALUATE_ABI_UNCHANGED=PASS")
print("F_TAB02_D_TEMPORAL_PROVIDER_GENERIC=PASS")
PY

compile_and_run() {
  local opt="$1"
  local out="$BUILD/o$opt"
  local C=(-std=f2018 -ffree-line-length-none -Wall -Wextra -pedantic -fcheck=all -fbacktrace -O"$opt")
  gfortran "${C[@]}" -J "$out" -I "$out" -c src/solver/mod_soil_water_solver_contract.f90 -o "$out/contract.o"
  gfortran "${C[@]}" -J "$out" -I "$out" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$out/mvg.o"
  gfortran "${C[@]}" -J "$out" -I "$out" -c src/solver/mod_b110_generated_mvg_tspack.f90 -o "$out/tspack.o"
  gfortran "${C[@]}" -J "$out" -I "$out" -c src/solver/mod_b110_generated_mvg_table_state.f90 -o "$out/state.o"
  gfortran "${C[@]}" -J "$out" -I "$out" -c src/solver/mod_b110_generated_mvg_provider.f90 -o "$out/generated.o"
  gfortran "${C[@]}" -J "$out" -I "$out"     tests/fsi/test_ftab02d_constitutive_context_capability.f90     "$out/contract.o" "$out/mvg.o" "$out/tspack.o" "$out/state.o" "$out/generated.o"     -o "$out/test_ftab02d"
  "$out/test_ftab02d" > "$out/output.txt"
}

compile_and_run 0
compile_and_run 2
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o2/output.txt"
echo "F_TAB02_D_O0_O2_OUTPUT_IDENTITY=PASS"
echo "F-TAB02-D OWNER QUALIFICATION PASS"
