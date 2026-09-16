#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"

src="src/runtime/mod_fmr_legacy_bottom_boundary_application_binding.f90"
test_src="tests/runtime/test_fapp02_legacy_swbotb6_zero_flux_binding.f90"
backend="src/runtime/mod_fmr_serialized_reference_backend.f90"
legacy_solver="src/adapter/mod_reference_richards_legacy_binding.f90"
headcalc="src/legacy/b1_10_port/headcalc.f90"

# The F-APP02 production delta is a semantic binding only: no parser, path,
# file-unit, solver or legacy-global authority is permitted.
if grep -Ein '\b(open|close|read|write)\s*\(|path|file[_ -]?unit|command_argument|environment_variable|MOD_BoundBottom|MOD_swap_base|variables' "$src"; then
  echo 'FAPP02_BOUNDED_AUTHORITY=FAIL'
  exit 1
fi
echo 'FAPP02_BOUNDED_AUTHORITY=PASS'

# Lock the already-admitted target semantics used by the binding.
grep -Fq 'request%boundary%bottom_mode = self%bottom_mode' "$backend"
grep -Fq 'request%boundary%bottom_flux = self%bottom_flux' "$backend"
grep -Fq 'request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2' "$legacy_solver"
grep -Fq 'fsi_ws%residual(NN) = fsi_ws%residual(NN) - state%qbot' "$headcalc"
echo 'FAPP02_TYPED_TARGET_SEMANTICS_LOCK=PASS'

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

for opt in 0 2; do
  exe="$work/fapp02_O${opt}"
  log="$work/fapp02_O${opt}.log"
  gfortran -std=f2008 -Wall -Wextra -O"$opt" \
    "$src" "$test_src" -o "$exe"
  "$exe" | tee "$log"
  grep -Fq 'FAPP02_OWNER_ORACLE=PASS' "$log"
done

diff -u "$work/fapp02_O0.log" "$work/fapp02_O2.log"
echo 'FAPP02_O0_O2_IDENTITY=PASS'
echo 'FAPP02_OWNER_GATE=PASS'
