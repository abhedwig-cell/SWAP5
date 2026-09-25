#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ahl35-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fbacktrace)
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
  gfortran "${COMMON[@]}" -O3 -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O3 -J "$BUILD" -I "$BUILD" -c   research/ahl/test_ahl35_warm_hit_sampler_elimination.f90 -o "$BUILD/test.o"
gfortran -O3 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"
"$BUILD/test" | tee /tmp/ahl35_result.txt
grep -Fq 'AHL35_STEP_DURATION_FALLBACK=PASS' /tmp/ahl35_result.txt
grep -Fq 'AHL35_WARM_HIT_SAMPLER_ELIMINATION=PASS' /tmp/ahl35_result.txt

# Frozen semantic/registry regressions.
bash research/ahl/run_ahl28b_same_key_memoization.sh | tee /tmp/ahl35_ahl28b_regression.txt
bash research/ahl/run_ahl32_registry.sh | tee /tmp/ahl35_ahl32_regression.txt
