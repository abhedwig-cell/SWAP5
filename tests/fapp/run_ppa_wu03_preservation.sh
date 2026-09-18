#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "PPA_WU03_PRESERVATION_FAIL $*" >&2; exit 1; }

BASE="$(git merge-base HEAD origin/integration/f-ci-canonical)"
protected=(
  src/process/mod_reference_et_demand_process.f90
  src/runtime/mod_fmr_reference_et_demand_binding.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/process/mod_pmdirect_swetr0_process.f90
  src/runtime/mod_fmr_pmdirect_swinter0_dynamic_top_binding.f90
  src/runtime/mod_fmr_pmdirect_dynamic_top_boundary_binding.f90
  src/runtime/mod_fmr_pmdirect_ptra_root_input_binding.f90
  src/runtime/mod_fmr_pmdirect_surface_evaporation_binding.f90
  src/process/mod_rutter_interception_process.f90
  src/runtime/mod_fmr_rutter_output_application_binding.f90
  src/process/mod_tcs1_dcs2_sprinkling_irrigation_process.f90
  src/runtime/mod_fmr_hupsel_irrigation_application_binding.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/adapter/mod_canonical_result_text_adapter.f90
  src/adapter/mod_b110_production_soil_water_task2.f90
)

for path in "${protected[@]}"; do
  git diff --quiet "$BASE" -- "$path" || fail "protected authority drift: $path"
done
echo 'PPA_WU03_FAPP_M1_PROTECTED_PRODUCTION_BLOBS=PASS'

bash tests/fapp/run_ppa_wu01_production_application_bootstrap.sh
echo 'PPA_WU03_PPA_WU01_REGRESSION=PASS'

bash tests/f-app07/run_fapp07_tcs1_dcs2_process.sh
echo 'PPA_WU03_FAPP07_IRRIGATION_REGRESSION=PASS'

bash tests/fci/run_fci93_fsi35_semantic_successor_preservation.sh
env FKT21_ALLOW_FCI98_SUCCESSOR=1 bash tests/fkt/run_fkt21_qualification.sh
python3 - <<'PY'
import json
from pathlib import Path
state=json.loads(Path('integration/m1/M1_FINAL_CLOSEOUT_20260918.json').read_text())
assert state['overall_verdict']=='M1_CLOSED_CURRENT_CANONICAL'
assert state['formal_exit'] is True
assert state['close_gate']=='PASS_CANONICALLY_ADMITTED'
assert state['production_mutation_in_closeout']=='NONE'
assert len(state['criteria'])==5
assert all(item['verdict'].startswith('PASS_') for item in state['criteria'])
print('PPA_WU03_M1_CLOSED_AUTHORITY=PASS')
PY
echo 'PPA_WU03_M1_CURRENT_SEMANTIC_REGRESSION=PASS'

echo 'PPA-WU03 PRESERVATION GATE PASS'
