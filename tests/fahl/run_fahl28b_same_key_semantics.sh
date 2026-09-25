#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fahl28b-sem-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace)
SRC=(
 src/solver/mod_soil_water_solver_contract.f90
 src/solver/mod_b110_default_mvg_provider.f90
 src/solver/mod_b110_adaptive_hydraulic_builder.f90
 src/solver/mod_b110_adaptive_hydraulic_cache.f90
 src/solver/mod_b110_adaptive_hydraulic_provider.f90
)
objects=()
for source in "${SRC[@]}"; do
 obj="$BUILD/$(basename "${source%.*}").o"
 gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
 objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c tests/fahl/test_fahl28b_same_key_semantics.f90 -o "$BUILD/test.o"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"
"$BUILD/test" | tee /tmp/fahl28b_semantics.txt
grep -Fq 'AHL28B_SAME_KEY_SEMANTICS=PASS' /tmp/fahl28b_semantics.txt
