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

declare -A files=(
  [283.met]='1de5ba86caded630f8c5b828648e8bda091115acd243891fe7d8b3551bc5add6'
  [grassd.crp]='8ca3bcfd14c415b1fdbfd2980f1c1ad077f509cfb25bf753fe1bdcd1c820b882'
  [maizes.crp]='2fe2fd36d0d6901775278ee7288d04d95db09b3c1fc3b20b7ee00b7dcbc8aa33'
  [potatod.crp]='96b8591c2401a8363c6a2a35f9d535c01d78e10ebf25d3dba88a9b807381a707'
  [swap.dra]='070f6adee26fbf750d38bb01b99c014b587b297a5203a6429e22ded58c22ea17'
)

for name in "${!files[@]}"; do
  curl -fsSL --retry 3 "$base/$name" -o "$tmp/$name"
  got="$(sha256sum "$tmp/$name" | awk '{print $1}')"
  [[ "$got" == "${files[$name]}" ]] || fail "$name SHA mismatch: $got"
done

echo 'PROFILE03_E2_PUBLIC_HUPSEL_EXACT_ASSET_IDENTITY=PASS'

curl -fsSL --retry 3 "$base/swap_linux.swp.template" -o "$tmp/swap_linux.swp.template"
template_sha="$(sha256sum "$tmp/swap_linux.swp.template" | awk '{print $1}')"
echo "PROFILE03_E2_PUBLIC_SWP_TEMPLATE_SHA256=$template_sha"
[[ "$template_sha" != 'a54d110efa0cf003b23537109a3aea83f17f941fa875a5de6aefd65291405b5b' ]] || fail 'public SWP template unexpectedly equals official Hupsel swap.swp authority'
echo 'PROFILE03_E2_PUBLIC_SWP_TEMPLATE=LINEAGE_ONLY_NOT_BYTE_AUTHORITY'

python3 - <<'PY'
from pathlib import Path
p=Path('tools/vq/b1_11_reconstruct.py').read_text()
assert 'parser.add_argument("--archive", required=True' in p
assert 'reconstruct_b1_10(archive, output_dir)' in p
print('PROFILE03_E2_B111_ARCHIVE_DEPENDENCY=CONFIRMED')
PY

echo 'PROFILE03_E2_REPLAY_BLOCKER=EXACT_B0_ARCHIVE_OR_EQUIVALENT_REPRODUCIBLE_SOURCE_BUILD_REQUIRED'
echo 'PROFILE03_E2_PREFLIGHT=PASS'
