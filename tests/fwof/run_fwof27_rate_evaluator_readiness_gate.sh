#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=428ad482d6b449e3e71d0c42bcc8521a98b9f2fe

changed_src="$(git diff --name-only "$BASE" -- src)"
if [[ -n "$changed_src" ]]; then
  echo 'FWOF27_ZERO_PRODUCTION_DELTA=FAIL' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
fi
echo 'FWOF27_ZERO_PRODUCTION_DELTA=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF27_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/crop/mod_wofost_actual_biomass_state.f90 feab0672b38e1c9668ac418cbe9d800f032cf4d8
check_blob src/crop/mod_wofost_crop_owner_state.f90 31bb390a0b70bec0a3f525f1d704a2c53890f9b4
check_blob src/crop/mod_wofost_one_day_structural_evolution.f90 c1fd9704ca1617f1f34d41fd7ec38640cce81d94
check_blob integration/f-wof/F-WOF26_STATUS.json c632bcee7e59b56476fd5d5e0d79680dca3d189e
check_blob integration/f-wof/F-WOF26_QUALIFICATION_EVIDENCE.json 181eb0ed4862a3dd1b23f1790c7dcd2a66d987f0
echo 'FWOF27_FWO26_PRODUCTION_AND_QUALIFICATION_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
import json

root = Path('.')
paths = {
    'contract': root/'integration/f-wof/F-WOF27_WORK_UNIT_CONTRACT.json',
    'parameters': root/'integration/f-wof/F-WOF27_PARAMETER_INPUT_INVENTORY.json',
    'graph': root/'integration/f-wof/F-WOF27_RATE_DEPENDENCY_GRAPH.json',
    'provider': root/'integration/f-wof/F-WOF27_PROVIDER_BOUNDARY.json',
    'reconcile': root/'integration/f-wof/F-WOF27_THEORY_CODE_RECONCILIATION.json',
    'audit': root/'integration/f-wof/F-WOF27_INVARIANT_AUDIT.json',
}
for p in paths.values():
    assert p.exists(), p
    json.loads(p.read_text())

d = {k: json.loads(p.read_text()) for k,p in paths.items()}
contract=d['contract']; params=d['parameters']; graph=d['graph']; provider=d['provider']; rec=d['reconcile']; audit=d['audit']

assert contract['base']['commit'] == '428ad482d6b449e3e71d0c42bcc8521a98b9f2fe'
assert contract['base']['status'] == 'QUALIFIED_RESTRICTED_STANDARD_WOFOST_ONE_DAY_STRUCTURAL_STATE_INTEGRATOR'
assert contract['mode'] == 'ZERO_PRODUCTION_READINESS_FIRST'
assert contract['admitted_first_profile']['sw_wofost'] == 1
assert contract['admitted_first_profile']['actual_trajectory_only'] is True
assert contract['admitted_first_profile']['IDSL'] == [0,1]
assert contract['admitted_first_profile']['SWRD'] == 1
assert contract['admitted_first_profile']['nutrient_route'] is False
assert contract['admitted_first_profile']['oxygen_root_growth_suppression'] is False
assert contract['admitted_first_profile']['potential_shadow'] is False

assert params['source_provenance']['wofost_f90_sha256'] == '3f7daf222835c9b4b395feaa665614e8aef88a03125cdec9e0776ca793c6271b'
assert params['source_provenance']['functions_f90_sha256'] == 'b32dee127747e619cb92965d0473173ec7fd93c56128a0dbd5ebf5942c300527'
assert params['gate_results']['F_WOF27_G01_complete_parameter_inventory'].startswith('PASS')
assert params['gate_results']['F_WOF27_G02_complete_state_view_inventory'].startswith('PASS')
assert params['gate_results']['production_rate_evaluator'] == 'NOT_IMPLEMENTED'
excluded = {x['name'] for x in params['legacy_inputs_explicitly_excluded_from_restricted_provider']}
assert 'KDIR' in excluded
rules = ' '.join(x['target_rule'] for x in params['fail_closed_parameter_strengthening'])
for token in ['DLO>DLC','TSUMEA','KDIF>0','CFRDM>0','Q10>0']:
    assert token in rules, token

assert graph['phase_A_prepare_assimilation']['output'] == 'actual_pgass'
assert graph['source_order_preservation']['PGASS_before_soil_substeps'] is True
assert graph['source_order_preservation']['RELTR_after_accepted_process_aggregation'] is True
assert graph['source_order_preservation']['structural_cohort_mutation_inside_rate_provider'] is False
for key in ['F_WOF27_G03_prepare_vs_finalize_dependency_graph','F_WOF27_G04_exact_mapping_to_F_WOF26_rate_packet','F_WOF27_G07_restricted_SWRD1_root_rate_boundary','F_WOF27_G08_reference_GLAIEXP_carryover_read_contract']:
    assert graph['gate_results'][key].startswith('PASS'), key

assert provider['required_types']['state_view']['fields'] == ['DVS','WRT','WST','WSO','WLV','LAI','LAIEXP']
assert provider['required_types']['state_view']['mutation_allowed'] is False
assert provider['same_state_view_rule']['required'] is True
assert provider['required_types']['prepared_assimilation']['persistence'].startswith('event-local')
assert provider['production_readiness_findings']['rate_provider'] == 'NOT_IMPLEMENTED'
assert provider['production_readiness_findings']['read_only_state_view_contract'] == 'READY_AS_CONTRACT_NOT_IMPLEMENTED'
for forbidden in ['MOD_meteo or ASTRO','atmosphere_interface globals','plant_interface globals','MOD_integral','persistent WOFOST_rates workspace']:
    assert forbidden in provider['forbidden_dependencies'], forbidden

assert rec['frozen_source']['archive_sha256'] == '2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360'
ids = {x['id'] for x in rec['reconciled_findings']}
assert ids == {f'FWO27-R{i:02d}' for i in range(1,15)}
classes = {x['classification'] for x in rec['reconciled_findings']}
assert 'ORPHAN_LEGACY_INPUT' in classes
assert 'LEGACY_VALIDATION_GAP' in classes
assert 'OWNER_BOUNDARY' in classes
assert 'SWAP_SPECIFIC_EXTENSION_NOT_TO_BE_SILENTLY_NORMALIZED' in classes
assert rec['readiness_decision'].startswith('NO_UNRESOLVED_THEORY_CODE_DISCREPANCY_BLOCKS')

assert audit['production_delta_expected'] is False
assert audit['overall'] == 'PASS_READINESS_WITH_EXPLICIT_PREPRODUCTION_SEAMS'
assert audit['production_permission'] == 'NO_BROAD_RATE_PHYSICS_IN_F_WOF27'
open_items = {x['item']: x['severity'] for x in audit['open_architectural_items']}
assert open_items['semantic read-only WOFOST rate-state view assembly'] == 'REQUIRED_BEFORE_BROAD_RATE_PROVIDER'
assert open_items['accepted aggregate provenance token or runtime binding'] == 'REQUIRED_BEFORE_END_TO_END_RUNTIME_ADMISSION'

print('FWOF27_PARAMETER_AND_STATE_VIEW_INVENTORY=PASS')
print('FWOF27_PREPARE_FINALIZE_DEPENDENCY_GRAPH=PASS')
print('FWOF27_RATE_PACKET_MAPPING=PASS')
print('FWOF27_READ_ONLY_PROVIDER_BOUNDARY=PASS')
print('FWOF27_FAIL_CLOSED_PARAMETER_STRENGTHENING=PASS')
print('FWOF27_HIDDEN_GLOBALS_AND_CALENDAR_REMOVED_BY_CONTRACT=PASS')
print('FWOF27_REFERENCE_GLAIEXP_CARRYOVER_BOUNDARY=PASS')
print('FWOF27_THEORY_CODE_RECONCILIATION=PASS')
print('FWOF27_CORE_INVARIANT_AUDIT=PASS')
print('FWOF27_BROAD_RATE_PRODUCTION_NOT_IMPLEMENTED=PASS')
PY

echo 'FWOF27_RATE_EVALUATOR_READINESS_GATE PASS'
