#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fsi30-abi-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

EXPECTED_FIXED_BLOB=fb226f133bd48d8ab945f111c76897aeff49facf
ACTUAL_FIXED_BLOB="$(git hash-object src/solver/mod_fixed_flux_top_boundary_provider.f90)"
test "$ACTUAL_FIXED_BLOB" = "$EXPECTED_FIXED_BLOB"
echo "FSI30_FIXED_FLUX_PROVIDER_BLOB=$ACTUAL_FIXED_BLOB"
echo 'FSI30_FIXED_FLUX_ABI_PRESERVATION=PASS'

python3 - <<'PY'
from pathlib import Path
c=Path('src/solver/mod_soil_water_solver_contract.f90').read_text().lower()
a=Path('src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90').read_text().lower()
assert 'type, abstract, public :: top_boundary_provider_t' in c
assert 'procedure(top_boundary_evaluate_ifc), deferred :: evaluate' in c
assert 'type, abstract, public :: dynamic_top_boundary_provider_t' in c
assert 'procedure(dynamic_top_boundary_evaluate_ifc), deferred :: evaluate' in c
assert 'class(dynamic_top_boundary_provider_t), pointer :: dynamic_top_boundary => null()' in c
assert 'extends(dynamic_top_boundary_provider_t)' in a
assert 'carries_surface_mass_terms = .true.' in a
print('FSI30_SIBLING_INTERFACE_SOURCE_GUARD=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -pedantic -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
  src/solver/mod_b110_surface_evaporation_capacity_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
)

for opt in 0 2; do
  out="$BUILD/o$opt"
  mkdir -p "$out"
  for src in "${SOURCES[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c "$src" -o "$obj"
  done
  echo "FSI30_ABI_ADAPTER_COMPILE_O${opt}=PASS"
done

echo 'FSI30_ABI_ADAPTER_COMPILE_GATE=PASS'
