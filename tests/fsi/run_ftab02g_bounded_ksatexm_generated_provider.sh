#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ftab02g-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT

COMMON=(-std=f2018 -ffree-line-length-none -Wall -Wextra -pedantic -fcheck=all -fbacktrace)

python3 - <<'PY'
from pathlib import Path
state=Path("src/solver/mod_b110_generated_mvg_table_state.f90").read_text()
backend=Path("src/runtime/mod_fmr_serialized_reference_backend.f90").read_text()
required=[
    "b110_generated_mvg_ksatexm_profile_supported",
    "first_active_head",
    "nearest(ext_lo(i),1.0_real64)",
    "state%ksatexm_extension_enabled .and. h >= state%first_active_head(i)",
]
for token in required:
    assert token in state, token
assert "b110_generated_mvg_ksatexm_profile_supported(parameters%cofgen" in backend
admit=backend[backend.index("logical function fmr_serialized_execution_admitted"):backend.index("end function fmr_serialized_execution_admitted")]
generated=admit[admit.index("if (parameters%generated_mvg_acceleration_active) then"):admit.index("end if",admit.index("if (parameters%generated_mvg_acceleration_active) then"))+6]
assert ".not. parameters%ksatexm_extension_active" not in generated
assert "b110_generated_mvg_ksatexm_profile_supported" in generated
print("F_TAB02_G_STATIC_BOUNDED_FSI39=PASS")
print("F_TAB02_G_SERIALIZED_SELECTOR_BOUNDED_KSATEXM=PASS")
PY

compile_and_run() {
  local opt="$1"
  local out="$BUILD/o$opt"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out"     -c src/solver/mod_soil_water_solver_contract.f90 -o "$out/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out"     -c src/solver/mod_b110_default_mvg_provider.f90 -o "$out/mvg.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out"     -c src/solver/mod_b110_generated_mvg_tspack.f90 -o "$out/tspack.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out"     -c src/solver/mod_b110_generated_mvg_table_state.f90 -o "$out/state.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out"     -c src/solver/mod_b110_generated_mvg_provider.f90 -o "$out/provider.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out"     tests/fsi/test_ftab02g_bounded_ksatexm_generated_provider.f90     "$out/contract.o" "$out/mvg.o" "$out/tspack.o" "$out/state.o" "$out/provider.o"     -o "$out/test_ftab02g"
  "$out/test_ftab02g" > "$out/output.txt"
}

compile_and_run 0
compile_and_run 2
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o2/output.txt"
echo "F_TAB02_G_O0_O2_OUTPUT_IDENTITY=PASS"

git diff --check --   src/solver/mod_b110_generated_mvg_table_state.f90   src/runtime/mod_fmr_serialized_reference_backend.f90   tests/fsi/test_ftab02g_bounded_ksatexm_generated_provider.f90   tests/fsi/run_ftab02g_bounded_ksatexm_generated_provider.sh

echo "F-TAB02-G BOUNDED F-SI39 OWNER QUALIFICATION PASS"
