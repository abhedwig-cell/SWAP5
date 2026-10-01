#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; B="${TMPDIR:-/tmp}/swap5-c3a-$$"; mkdir -p "$B"; trap 'rm -rf "$B"' EXIT; cd "$ROOT"
python3 - <<'PY'
from pathlib import Path
p=Path('src/runtime/mod_fmr_bartholomeus_execution.f90').read_text().lower()
assert 'final_fluxes=base_fluxes' in p
assert 'route==fmr_bartholomeus_disabled' in p
assert 'route/=fmr_bartholomeus_active' in p
assert 'evaluate_bartholomeus_factors_from_state' in p
assert 'compose_root_sink_with_oxygen_factor' in p
for x in ['open(','read(','write(','save ::']:
    assert x not in p,x
print('C3A_EXECUTION_STATIC_OWNERSHIP=PASS')
PY
# Reuse already persisted narrow composition gate for exact root-sink ownership.
bash tests/physics/run_root_uptake_oxygen_composition.sh
# Activation is dependency-light and proves OFF/ACTIVE/UNSUPPORTED selection.
bash tests/physics/run_fmr_bartholomeus_activation.sh
echo 'PPA_WU05C3A_PRODUCTION_PRESERVATION_GATE=PASS'
