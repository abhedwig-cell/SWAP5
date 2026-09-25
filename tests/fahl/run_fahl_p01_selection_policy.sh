#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fahl-p01-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

gfortran -std=f2008 -Wall -Wextra -Werror -O0 -J "$BUILD" -I "$BUILD"   -c src/runtime/mod_fmr_adaptive_hydraulic_policy.f90 -o "$BUILD/policy.o"
gfortran -std=f2008 -Wall -Wextra -Werror -O0 -J "$BUILD" -I "$BUILD"   -c tests/fahl/test_fahl_p01_selection_policy.f90 -o "$BUILD/test.o"
gfortran -O0 "$BUILD/policy.o" "$BUILD/test.o" -o "$BUILD/test"
"$BUILD/test"

gfortran -std=f2008 -Wall -Wextra -Werror -O2 -J "$BUILD" -I "$BUILD"   -c src/runtime/mod_fmr_adaptive_hydraulic_policy.f90 -o "$BUILD/policy-o2.o"
gfortran -std=f2008 -Wall -Wextra -Werror -O2 -J "$BUILD" -I "$BUILD"   -c tests/fahl/test_fahl_p01_selection_policy.f90 -o "$BUILD/test-o2.o"
gfortran -O2 "$BUILD/policy-o2.o" "$BUILD/test-o2.o" -o "$BUILD/test-o2"
"$BUILD/test-o2"

echo 'F_AHL_P01_SELECTION_POLICY_O0_O2=PASS'
