#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fahl49-provider-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -ffree-line-length-none -O3)
for src in   src/solver/mod_soil_water_solver_contract.f90   src/solver/mod_b110_default_mvg_provider.f90   src/solver/mod_b110_direct_retention_core.f90   src/solver/mod_b110_default_mvg_directional_provider.f90   src/solver/mod_b110_direct_retention_provider.f90; do
  obj="$BUILD/$(basename "${src%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$src" -o "$obj"
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c tests/fahl/test_fahl49_provider_extraction.f90 -o "$BUILD/test.o"
gfortran -O3 "$BUILD"/mod_*.o "$BUILD/test.o" -o "$BUILD/test"
"$BUILD/test"
