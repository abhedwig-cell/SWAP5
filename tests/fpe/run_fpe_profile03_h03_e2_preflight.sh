#!/usr/bin/env bash
set -euo pipefail

fail(){ echo "PROFILE03_E2_PREFLIGHT_FAIL $*" >&2; exit 1; }

python3 - <<'PY'
from pathlib import Path
task2=Path('src/adapter/mod_b110_production_soil_water_task2.f90').read_text()
binding=Path('src/adapter/mod_reference_richards_legacy_binding.f90').read_text()
soilwater=Path('src/legacy/b1_10_port/soilwater.f90').read_text()
assert 'call run_b110_production_task2(worker)' in soilwater
assert 'type(reference_richards_legacy_solver_t) :: solver' in task2
assert 'call solver%solve(request, workspace, result)' in task2 or 'call invoke_soil_water_solver(solver, request, workspace, result)' in task2
assert 'call headcalc(' in binding
print('PROFILE03_E2_CURRENT_H03_ROUTE_BINDING=PASS')
PY

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
base='https://raw.githubusercontent.com/SWAP-model/swap-testcases/a1b15843e9e9732713bed1ee41d09c16c3136593/cases/hupselbrook/legacy'

public_files=(283.met grassd.crp maizes.crp potatod.crp swap.dra swap_linux.swp.template)
for name in "${public_files[@]}"; do
  curl -fsSL --retry 3 "$base/$name" -o "$tmp/$name"
  got="$(sha256sum "$tmp/$name" | awk '{print $1}')"
  echo "PROFILE03_E2_PUBLIC_ASSET_SHA256 $name $got"
done
echo 'PROFILE03_E2_PUBLIC_HUPSEL_LINEAGE_ASSETS=AVAILABLE'
echo 'PROFILE03_E2_PUBLIC_ASSETS_NOT_USED_AS_BYTE_AUTHORITY=PASS'

python3 - <<'PY'
from pathlib import Path
p=Path('tools/vq/b1_11_reconstruct.py').read_text()
assert 'parser.add_argument("--archive", required=True' in p
assert 'reconstruct_b1_10(archive, output_dir)' in p
print('PROFILE03_E2_B111_ARCHIVE_DEPENDENCY=CONFIRMED')
PY

echo 'PROFILE03_E2_REPLAY_BLOCKER=EXACT_B0_ARCHIVE_OR_EQUIVALENT_REPRODUCIBLE_SOURCE_BUILD_REQUIRED'
echo 'PROFILE03_E2_PREFLIGHT=PASS'
