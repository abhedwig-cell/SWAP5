#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fsi30-adapter-identity-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail() { echo "FSI30_ADAPTER_IDENTITY_RUNNER_FAIL $*" >&2; exit 1; }
FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -pedantic -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
  src/solver/mod_b110_surface_evaporation_capacity_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  tests/fsi/test_fsi30_adapter_identity.f90
)

for opt in 0 2; do
  out="$BUILD/o$opt"
  mkdir -p "$out"
  objects=()
  for src in "${SOURCES[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${FLAGS[@]}" -O"$opt" -J"$out" -I"$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${FLAGS[@]}" -O"$opt" "${objects[@]}" -o "$out/test_fsi30_adapter_identity"
  "$out/test_fsi30_adapter_identity" > "$out/output.txt"
  grep -Fq 'FSI30_ADAPTER_IDENTITY_CASES=9072' "$out/output.txt" || fail "O${opt} did not execute 9072 cases"
  grep -Fq 'FSI30_ADAPTER_DIRECT_FSI29_IDENTITY=PASS' "$out/output.txt" || fail "O${opt} direct/adapted identity failed"
  grep -Fq 'FSI30_ADAPTER_EIGHT_CONTEXT_REPLAY=PASS' "$out/output.txt" || fail "O${opt} interleaved replay failed"
  cat "$out/output.txt"
  echo "FSI30_ADAPTER_IDENTITY_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail 'O0/O2 observable adapter output differs'
echo 'FSI30_ADAPTER_IDENTITY_O0_O2=PASS'
echo 'FSI30_ADAPTER_IDENTITY_RUNNER=PASS'
