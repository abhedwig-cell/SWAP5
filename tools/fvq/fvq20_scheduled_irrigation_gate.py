#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

ROOT = Path('.')
CANDIDATE_CLOSEOUT = '46ef693672dda13261a966cc9904e72437c7bcfb'
CANDIDATE_TREE = 'a3d06ea93395bfc9c5eb1cf01c2369f91c98c5c6'
PRODUCTION_PATH = 'src/process/mod_irrigation_process.f90'
PRODUCTION_BLOB = 'c0755c1e0d0b7ca1a35e73cf26158c29e9940aec'
FVQ18_ORACLE_BLOB = '15989f375b557237eb36590f75361c02d19bb871'

contract = json.loads((ROOT / 'integration/f-vq/F-VQ20_CONTRACT.json').read_text(encoding='utf-8'))
oracle = json.loads((ROOT / 'integration/f-vq/F-VQ20_B110_ORACLE.json').read_text(encoding='utf-8'))
manifest = (ROOT / 'reference/swap-4.3.1/b0/file-manifest.sha256').read_text(encoding='utf-8')

assert contract['candidate_closeout_commit'] == CANDIDATE_CLOSEOUT
assert contract['candidate_production_blob'] == PRODUCTION_BLOB
assert contract['production_source_changes_allowed'] is False
assert contract['reference_source_changes_allowed'] is False
assert contract['independence']['FPM04_candidate_test_outputs_used_as_acceptance_oracle'] is False
assert contract['independence']['FPM04_candidate_gate_result_used_as_scientific_oracle'] is False
print('FVQ20_INDEPENDENCE_CONTRACT PASS')

observed_tree = subprocess.check_output(['git','rev-parse',f'{CANDIDATE_CLOSEOUT}^{{tree}}'], text=True).strip()
assert observed_tree == CANDIDATE_TREE, f'candidate closeout tree mismatch: {observed_tree}'
subprocess.run(['git','merge-base','--is-ancestor',CANDIDATE_CLOSEOUT,'HEAD'], check=True)
changed = subprocess.check_output(['git','diff','--name-only',CANDIDATE_CLOSEOUT,'HEAD','--','src','reference'], text=True).splitlines()
assert changed == [], f'qualification changed production/reference source: {changed}'
observed_blob = subprocess.check_output(['git','hash-object',PRODUCTION_PATH], text=True).strip()
assert observed_blob == PRODUCTION_BLOB, f'candidate production blob mismatch: {observed_blob}'
print('FVQ20_CANDIDATE_SOURCE_IMMUTABILITY PASS')

expected_members = {
    'SWAP/functions.f90': 'b32dee127747e619cb92965d0473173ec7fd93c56128a0dbd5ebf5942c300527',
    'SWAP/irrigation.f90': '65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1',
    'SWAP/swap.f90': '39d1cbd93dbd0f99505e92ef94ac0d23bddb496529c280397d2d7c2b7eb9b58a',
    'SWAP/timecontrol.f90': '6d2a62db0ff1e3ea00693f7b39bdb36e1811ba79011f15feef5a656ddf3181b8',
}
assert oracle['derivation']['nested_archive_sha256'] == '1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
for path, sha in expected_members.items():
    assert oracle['derivation']['members'][path] == sha
    assert f'{sha}' in manifest and path in manifest, f'canonical B0 manifest missing {path}'
print('FVQ20_CANONICAL_B110_SOURCE_LOCK PASS')

assert oracle['TCS7_equation']['threshold'] == 'phcrit = afgen(hcritab,14,dvs)'
assert oracle['TCS7_equation']['trigger'] == 'h(nodsen) <= phcrit'
assert oracle['DCS2_equation']['legacy'] == 'dps2 = afgen(fidtab,14,dvs); irr_depth_cm = 0.1*dps2'
assert oracle['regular_positive_rate_single_node_SSDI']['source'] == 'qssdi(nod_ssdi(1):nod_ssdi(2)) = irr_rate'
assert oracle['regular_positive_rate_single_node_SSDI']['duration'] == 'dt_irr_event = irr_depth/irr_rate'
assert oracle['selection_cadence']['target_abstraction'].startswith('selection_opportunity is an explicit')
assert 'partial tables above their explicit last knot' in oracle['scientific_equivalence_boundary']['not_claimed'][0]
print('FVQ20_INDEPENDENT_EQUATION_ORACLE PASS')

fvq18_blob = subprocess.check_output([
    'git','rev-parse','qualification/f-vq18-fpm03-fixed-irrigation:tests/fvq/test_fvq18_fixed_irrigation_oracle.f90'
], text=True).strip()
assert fvq18_blob == FVQ18_ORACLE_BLOB, f'F-VQ18 oracle blob mismatch: {fvq18_blob}'
print('FVQ20_FVQ18_REGRESSION_ORACLE_LOCK PASS')

candidate_source = (ROOT / PRODUCTION_PATH).read_text(encoding='utf-8').lower()
for forbidden in ['fldaystart','fldayend','t1900','dayfix','tcsfix','headcalc','open(','read(','write(']:
    assert forbidden not in candidate_source, f'hidden time/I/O/solver dependency in candidate: {forbidden}'
assert 'selection_opportunity' in candidate_source
assert 'process_hydraulic_view_t' in candidate_source
assert 'active_event_origin' in candidate_source
print('FVQ20_ARCHITECTURE_SOURCE_LOCK PASS')
