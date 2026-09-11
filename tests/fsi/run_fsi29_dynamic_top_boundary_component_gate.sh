#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fsi29-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -pedantic -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
  src/solver/mod_b110_surface_evaporation_capacity_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
)

python3 - <<'PY'
from pathlib import Path
import re
p=Path('src/solver/mod_b110_dynamic_top_boundary_provider.f90').read_text().lower()
for forbidden in ('headcalc', 'mod_top', 'modflow', 'file_unit', '.swp'):
    assert forbidden not in p, forbidden
assert not re.search(r'(^|[^a-z0-9_])save([^a-z0-9_]|$)', p)
assert not re.search(r'\b(open|read|write|close)\s*\(', p)
print('FSI29_ARCHITECTURE_SOURCE_GUARD=PASS')
PY

run_one() {
  local opt="$1"
  local out="$BUILD/o$opt"
  mkdir -p "$out"
  local objs=()
  for src in "${SOURCES[@]}"; do
    local obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c "$src" -o "$obj"
    objs+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c \
    tests/fsi/test_fsi29_dynamic_top_boundary_provider.f90 -o "$out/test.o"
  gfortran -O"$opt" "${objs[@]}" "$out/test.o" -o "$out/test.exe"
  "$out/test.exe" > "$out/output.txt"
  cat "$out/output.txt"
  grep -Fxq 'FSI29_FPM06E_EMAX_REUSE=PASS' "$out/output.txt"
  grep -Fxq 'FSI29_FLUX_AND_HEAD_REGIMES=PASS' "$out/output.txt"
  grep -Fxq 'FSI29_ATMOSPHERIC_HEAD_SWITCH=PASS' "$out/output.txt"
  grep -Fxq 'FSI29_PONDING_LINEAR_RUNOFF=PASS' "$out/output.txt"
  grep -Fxq 'FSI29_UNSUPPORTED_RUNOFF_FAIL_CLOSED=PASS' "$out/output.txt"
  grep -Fxq 'FSI29_INPUT_NONMUTATION_AND_ABA=PASS' "$out/output.txt"
  grep -Fxq 'FSI29_COMPONENT_GATE=PASS' "$out/output.txt"
}

run_one 0
run_one 2
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FSI29_O0_O2_IDENTITY=PASS'
echo 'FSI29_DYNAMIC_TOP_BOUNDARY_COMPONENT_GATE=PASS'
