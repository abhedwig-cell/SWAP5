#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fsi29-oracle-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

EXPECTED_PROVIDER_BLOB='3eadae0f32aba49534cd58464e28c0af5bc9bf7d'
ACTUAL_PROVIDER_BLOB="$(git hash-object src/solver/mod_b110_dynamic_top_boundary_provider.f90)"
[[ "$ACTUAL_PROVIDER_BLOB" == "$EXPECTED_PROVIDER_BLOB" ]]

python3 - <<'PY'
from pathlib import Path
import json, re
prov=json.loads(Path('integration/f-si/F-SI29_LEGACY_ORACLE_PROVENANCE.json').read_text())
assert prov['source_archive']['legacy_source_sha256'] == '69d0d4703af64212d7200898f12568853d015cea29cb45f81915bece15b63c04'
assert prov['source_archive']['nested_archive_sha256'] == '1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
text=Path('tests/fsi/test_fsi29_legacy_boundtop_oracle.f90').read_text().lower()
m=re.search(r'subroutine\s+legacy_restricted_oracle\b(.*?)end\s+subroutine\s+legacy_restricted_oracle', text, re.S)
assert m, 'oracle subroutine not found'
assert 'evaluate_b110_dynamic_top_boundary' not in m.group(1), 'candidate called from oracle implementation'
print('FSI29_ORACLE_PROVENANCE_GUARD=PASS')
print('FSI29_ORACLE_INDEPENDENCE_GUARD=PASS')
print('FSI29_ORACLE_PROVIDER_BLOB_GUARD=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -pedantic -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SOURCES=(
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
)

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
    tests/fsi/test_fsi29_legacy_boundtop_oracle.f90 -o "$out/test.o"
  gfortran -O"$opt" "${objs[@]}" "$out/test.o" -o "$out/test.exe"
  "$out/test.exe" > "$out/output.txt"
  cat "$out/output.txt"
  grep -Fxq 'FSI29_LEGACY_BOUNDARY_ORACLE=PASS' "$out/output.txt"
  grep -Fxq 'FSI29_EIGHT_CONTEXT_INTERLEAVED_REPLAY=PASS' "$out/output.txt"
}

run_one 0
run_one 2
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FSI29_ORACLE_O0_O2_IDENTITY=PASS'
echo 'FSI29_LEGACY_BOUNDARY_ORACLE_GATE=PASS'
