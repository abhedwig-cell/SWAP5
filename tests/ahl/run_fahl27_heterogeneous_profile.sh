#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fahl27-het-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SRC=(
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_adaptive_hydraulic_builder.f90
  src/runtime/mod_b110_adaptive_hydraulic_cache.f90
  src/solver/mod_b110_adaptive_mvg_provider.f90
)
OUT="$BUILD/o2"; mkdir -p "$OUT"; objects=()
for source in "${SRC[@]}"; do
  obj="$OUT/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c tests/ahl/test_fahl27_heterogeneous_profile.f90 -o "$OUT/test.o"
gfortran -O2 "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
"$OUT/test" | tee /tmp/fahl27_heterogeneous.txt
grep -Fq 'FAHL27_HETEROGENEOUS_PROFILE=PASS' /tmp/fahl27_heterogeneous.txt

if grep -Eiq 'type\(b110_adaptive_hydraulic_cache_t\)[^!]*,[[:space:]]*save|save[[:space:]]*::[[:space:]]*shared_cache'   src/solver/mod_b110_adaptive_mvg_provider.f90 src/runtime/mod_b110_adaptive_hydraulic_cache.f90; then
  echo 'FAHL27_HET_FAIL module-global mutable SAVE cache remains' >&2
  exit 1
fi
echo 'FAHL27_NO_GLOBAL_MUTABLE_CACHE=PASS' | tee -a /tmp/fahl27_heterogeneous.txt
