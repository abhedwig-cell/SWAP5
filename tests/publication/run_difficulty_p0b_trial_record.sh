#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-difficulty-p0b-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -J "$BUILD" -I "$BUILD" -c src/solver/mod_soil_water_solver_contract.f90 -o "$BUILD/contract.o"
gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -J "$BUILD" -I "$BUILD" -c src/research/mod_difficulty_trial_record.f90 -o "$BUILD/difficulty.o"
gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -J "$BUILD" -I "$BUILD" -c tests/publication/test_difficulty_trial_record.f90 -o "$BUILD/test.o"
gfortran "$BUILD/contract.o" "$BUILD/difficulty.o" "$BUILD/test.o" -o "$BUILD/test"
"$BUILD/test" | tee "$BUILD/output.txt"
grep -Fq 'DIFFICULTY_P0B_TRIAL_RECORD=PASS' "$BUILD/output.txt"
echo 'DIFFICULTY_P0B_EXECUTABLE_CONTRACT=PASS'
