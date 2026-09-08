#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=24eee52efc0ce68c879632bb6fa42cce6289f901
SOURCE_INVENTORY=integration/f-wof/F-WOF12_SOURCE_BOUND_PROVIDER_INVENTORY.json
CONTRACT=integration/f-wof/F-WOF15_ROOT_STATE_OWNERSHIP_CONTRACT.json
EVIDENCE=integration/f-wof/F-WOF15_SOURCE_BOUND_OWNERSHIP_EVIDENCE.json

changed_src="$(git diff --name-only "$BASE" -- src)"
[[ -z "$changed_src" ]] || {
  echo 'FWOF15_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF15_ZERO_PRODUCTION_DELTA=PASS'

[[ "$(git hash-object "$SOURCE_INVENTORY")" == "53613edbbc238e9b4fbc17f8ad336db378c2b2e5" ]] || {
  echo 'FWOF15_FWO12_SOURCE_INVENTORY_BLOB_MISMATCH' >&2
  exit 1
}
echo 'FWOF15_FWO12_SOURCE_BINDING_LOCK=PASS'

python3 - "$SOURCE_INVENTORY" "$CONTRACT" "$EVIDENCE" <<'PY'
import json, sys
from pathlib import Path

source = json.loads(Path(sys.argv[1]).read_text())
contract = json.loads(Path(sys.argv[2]).read_text())
evidence = json.loads(Path(sys.argv[3]).read_text())

expected_hash = 'c2df137291357553541d4d7026b8859242c32565affe173c66a685d565190ccf'
assert source['source_provenance']['files']['SWAP/MOD_cropdevelopment.f90'] == expected_hash
assert contract['source_provenance']['legacy_cropdevelopment_sha256'] == expected_hash
assert evidence['source_provenance']['sha256'] == expected_hash

assert contract['decision'] == 'OPTION_DEPENDENT_MINIMAL_ROOT_STATE_WITH_DERIVED_VIEW'
assert contract['view_production_contract']['potential_transpiration'].startswith('explicitly excluded')

opt = contract['ownership_classes']['optional_persistent_root_state']
assert opt['SWRD_1']['required_independent_root_depth_state'] is False
assert opt['SWRD_2']['required'] == ['actual_root_depth', 'potential_root_depth']
assert opt['SWRD_3']['required_independent_root_depth_state'] is False
assert opt['SWRDC_1']['required'] == ['per_node_root_biomass_distribution_or_semantic_equivalent']
assert opt['SWRDC_nonadaptive']['required_per_node_dynamic_distribution_state'] is False

reconstructible = ' '.join(contract['ownership_classes']['reconstructible_or_intra_update_workspace']).lower()
for token in ['noddrz', 'mxnoddrz', 'cumdens', 'cumdens_top', 'noddrz_old', 'rr/actual']:
    assert token.lower() in reconstructible, token

rules = ' '.join(contract['memory_scaling_rules']).lower()
assert 'do not allocate per-node adaptive root state for swrdc != 1' in rules
assert 'swrd=2 and swrdc=1 optional state' in rules

matrix = evidence['option_matrix']
assert len(matrix) == 4
m1 = next(x for x in matrix if x['SWRD'] == 1 and x['SWRDC'] == 'nonadaptive')
m2 = next(x for x in matrix if x['SWRD'] == 2 and x['SWRDC'] == 'nonadaptive')
m3 = next(x for x in matrix if x['SWRD'] == 3 and x['SWRDC'] == 'nonadaptive')
ma = next(x for x in matrix if x['SWRDC'] == 1)
assert m1['independent_root_depth_state'] == [] and m1['per_node_dynamic_root_state'] == []
assert m2['independent_root_depth_state'] == ['actual_root_depth', 'potential_root_depth']
assert m2['per_node_dynamic_root_state'] == []
assert m3['independent_root_depth_state'] == [] and m3['per_node_dynamic_root_state'] == []
assert ma['per_node_dynamic_root_state'] == ['per_node_root_biomass_distribution_or_semantic_equivalent']

root_ext = evidence['root_extension']['ownership_consequence']
assert root_ext['SWRD_1_independent_rd_state'] is False
assert root_ext['SWRD_2_rd_state'] is True
assert root_ext['SWRD_2_rdpot_state'] is True
assert root_ext['SWRD_3_independent_rd_state'] is False
assert root_ext['noddrz_persistent_state'] is False

assert 'previous wroot_node values' in evidence['root_distribution']['update_wroot_node_2160_2235']['prior_dynamic_dependency']
assert 'derived normalized representation' in evidence['root_distribution']['update_cumdens_2239_2275']['ownership_consequence']
assert 'derived view field' in evidence['root_distribution']['update_cumdens_top_2279_2301']['ownership_consequence']

nonclaims = ' '.join(evidence['important_nonclaims']).lower()
assert 'exact swap5 crop-host state type is not defined' in nonclaims
assert 'does not qualify a root-growth update implementation' in nonclaims
assert 'does not qualify arbitrary subdaily root-growth cadence' in nonclaims
assert 'does not qualify potential transpiration production' in nonclaims

print('FWOF15_SOURCE_HASH_RECONCILIATION=PASS')
print('FWOF15_SWRD_OPTION_DEPENDENT_DEPTH_STATE=PASS')
print('FWOF15_SWRDC_OPTION_DEPENDENT_DISTRIBUTION_STATE=PASS')
print('FWOF15_DERIVED_VIEW_FIELDS_NOT_COMMIT_AUTHORITIES=PASS')
print('FWOF15_OPTIONAL_STATE_MEMORY_SCALING=PASS')
print('FWOF15_ET_OWNERSHIP_REMAINS_SEPARATE=PASS')
print('FWOF15_NONCLAIMS_FAIL_CLOSED=PASS')
PY

echo 'FWOF15_DECISION=OPTION_DEPENDENT_MINIMAL_ROOT_STATE_WITH_DERIVED_VIEW'
echo 'FWOF15_ROOT_STATE_OWNERSHIP_GATE PASS'
