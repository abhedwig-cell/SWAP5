#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

binding="src/runtime/mod_fmr_legacy_bottom_boundary_application_binding.f90"
contract="src/solver/mod_soil_water_solver_contract.f90"
state_binding="src/solver/mod_reference_richards_state_binding.f90"
test_src="tests/fvq/test_fvq102_fapp02_swbotb6_independent.f90"
expected_binding_blob="456c87437e83d1d362d41fbf9820e70d96353ff9"
canonical_base="5eb93542daf297d3aa89bee9552179387a7f2c68"

actual_blob="$(git rev-parse "HEAD:${binding}")"
[[ "$actual_blob" == "$expected_binding_blob" ]]
echo 'FVQ102_EXACT_OWNER_BLOB=PASS'

mapfile -t production_delta < <(git diff --name-only "$canonical_base"...HEAD -- src/)
[[ "${#production_delta[@]}" -eq 1 ]]
[[ "${production_delta[0]}" == "$binding" ]]
echo 'FVQ102_SINGLE_PRODUCTION_DELTA=PASS'

# Independent static boundary: the candidate may describe a semantic mapping,
# but it must not acquire parser, file, global legacy-state, solver or backend authority.
if grep -Ein '\b(open|close|read|write)\s*\(|path|file[_ -]?unit|command_argument|environment_variable|MOD_swap_base|use variables|HeadCalc|Richards' "$binding"; then
  echo 'FVQ102_BOUNDED_APPLICATION_AUTHORITY=FAIL'
  exit 1
fi
echo 'FVQ102_BOUNDED_APPLICATION_AUTHORITY=PASS'

grep -Fq 'state%qbot = request%boundary%bottom_flux' "$state_binding"
grep -Fq 'type, public :: soil_water_boundary_conditions_t' "$contract"
grep -Fq 'real(real64) :: bottom_flux = 0.0_real64' "$contract"
echo 'FVQ102_TYPED_CONTRACT_LOCK=PASS'

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

for opt in 0 2; do
  build="$work/O${opt}"
  mkdir -p "$build"
  gfortran -std=f2008 -Wall -Wextra -O"$opt" -J"$build" -I"$build" -c "$contract" -o "$build/contract.o"
  gfortran -std=f2008 -Wall -Wextra -O"$opt" -J"$build" -I"$build" -c "$binding" -o "$build/binding.o"
  gfortran -std=f2008 -Wall -Wextra -O"$opt" -J"$build" -I"$build" -c "$state_binding" -o "$build/state_binding.o"
  gfortran -std=f2008 -Wall -Wextra -O"$opt" -J"$build" -I"$build" \
    "$test_src" "$build/contract.o" "$build/binding.o" "$build/state_binding.o" -o "$build/fvq102"
  "$build/fvq102" | tee "$work/fvq102_O${opt}.log"
  grep -Fq 'FVQ102_INDEPENDENT_ORACLE=PASS' "$work/fvq102_O${opt}.log"
done

diff -u "$work/fvq102_O0.log" "$work/fvq102_O2.log"
echo 'FVQ102_O0_O2_IDENTITY=PASS'
echo 'FVQ102_INDEPENDENT_GATE=PASS'
