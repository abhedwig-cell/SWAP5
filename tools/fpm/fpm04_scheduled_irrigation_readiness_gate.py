#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path('.')
BASE = '55efeb4090a669d179a8d93f73e0799e6c7623c5'
FSI17 = 'fca2f497e465c4782ebc6e25756aff70cbb2554e'
FMR07 = 'afb450bed0d53d20af2157d0b164d16a9e0a04cd'
FVQ18 = '973d2b9d38917a4a459f51b6b46dd51cfd9690c4'

EXPECTED_BLOBS = {
    'src/process/mod_irrigation_process.f90': 'af8dc3b3e16d261af573c9b626704638d5ee70c9',
    'src/solver/mod_process_hydraulic_view.f90': 'd7d85fe71ced0d94b29c8d9395859ae1834f7dd6',
    'src/runtime/mod_fmr_process_hydraulic_view_binding.f90': '37f5968ffe00b1ff56f824f77ab94d3825171acf',
    'src/solver/mod_b110_source_sink_provider.f90': 'd6c57add72387e5c0022a44319fff08046194aac',
    'src/kernel/mod_kernel_transactions.f90': '9f7c16e71cfb93b57f796ba759bae73824318a2f',
}

FUNCTIONS_SHA256 = 'b32dee127747e619cb92965d0473173ec7fd93c56128a0dbd5ebf5942c300527'
IRRIGATION_SHA256 = '65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1'
B110_MANIFEST_SHA256 = '2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1'


def run(*args: str) -> str:
    return subprocess.check_output(args, text=True).strip()


def git_json(commit: str, path: str) -> dict:
    raw = run('git', 'show', f'{commit}:{path}')
    return json.loads(raw)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


# Readiness is contract-only. Production source must still be exact F-PM03 closeout source.
changed_src = run('git', 'diff', '--name-only', BASE, 'HEAD', '--', 'src').splitlines()
require(changed_src == [], f'production source changed before readiness admission: {changed_src}')
print('FPM04_NO_PRODUCTION_SOURCE_CHANGE PASS')

for path, expected in EXPECTED_BLOBS.items():
    actual = run('git', 'hash-object', path)
    require(actual == expected, f'blob mismatch {path}: expected {expected}, got {actual}')
print('FPM04_QUALIFIED_INTERFACE_BLOBS PASS')

contract = json.loads((ROOT / 'integration/f-pm/F-PM04_READINESS_CONTRACT.json').read_text(encoding='utf-8'))
inventory = json.loads((ROOT / 'integration/f-pm/F-PM04_SCHEDULED_IRRIGATION_INVENTORY.json').read_text(encoding='utf-8'))
evidence = json.loads((ROOT / 'integration/f-pm/F-PM04_B110_SOURCE_EVIDENCE.json').read_text(encoding='utf-8'))

require(contract['readiness_only_until_gate_pass'] is True, 'readiness-only guard missing')
require(contract['production_source_change_allowed_before_gate_pass'] is False, 'pre-admission source guard missing')
profile = contract['selected_restricted_profile']
require(profile['timing_criterion'] == 'TCS7', 'not TCS7')
require(profile['depth_criterion'] == 'DCS2', 'not DCS2')
require(profile['application'] == 'SSDI_SINGLE_NODE_ONLY', 'not single-node SSDI')
require(profile['ssdi_node_contract'] == 'ssdi_first_node == ssdi_last_node', 'single-node invariant absent')
require(profile['minimum_interval_overlay'] is False, 'tcsfix/dayfix must remain excluded')
require(profile['solute_overirrigation'] is False, 'solute over-irrigation must remain excluded')
require(profile['depth_limits'] is False, 'depth limits must remain excluded')
require(profile['rainfall_reduction'] is False, 'rain reduction must remain excluded')
require(profile['external_availability_scaling'] is False, 'task=4 availability scaling must remain excluded')
require(contract['multi_node_ssdi_hold']['admitted_by_fpm04'] is False, 'multi-node scheduled SSDI accidentally admitted')
require(contract['multi_node_ssdi_hold']['status'] == 'HELD_UNRESOLVED_SOURCE_SEMANTIC_DIFFERENCE', 'multi-node hold weakened')
require(contract['legacy_dependency_cut']['migrate_into_tcs7_dcs2_seam'] is False, 'legacy tcs>1 prelude accidentally admitted')
require('later independent F-VQ' in contract['legacy_dependency_cut']['qualification_caveat'], 'incidental side-effect caveat missing')
require(contract['readiness_pass_decision'] == 'ADMITTED_FOR_STRUCTURAL_TCS7_DCS2_SINGLE_NODE_SSDI_MIGRATION', 'unexpected readiness decision')

selected = inventory['selected_smallest_seam']
require(selected['name'] == 'TCS7_DCS2_SINGLE_NODE_SSDI_REGULAR_RATE', 'inventory scope diverges from contract')
require('multi-node scheduled SSDI' in selected['excluded'], 'inventory does not exclude multi-node SSDI')
require(inventory['scheduled_ssdi_source_semantics']['required_condition'] == 'ssdi_first_node == ssdi_last_node', 'inventory single-node condition missing')
require(inventory['mass_ownership']['multi_node_scheduled_mass_admitted'] is False, 'inventory admits multi-node scheduled mass')
print('FPM04_RESTRICTED_PROFILE_LOCK PASS')

# Pin canonical B0/B1.10 source identity without reconstructing or modifying reference source.
source_identity = (ROOT / 'reference/swap-4.3.1/b0/SOURCE_IDENTITY.md').read_text(encoding='utf-8')
manifest = (ROOT / 'reference/swap-4.3.1/b0/file-manifest.sha256').read_text(encoding='utf-8')
b110 = (ROOT / 'reference/swap-4.3.1/snapshots/B1.10.yml').read_text(encoding='utf-8')
require('1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151' in source_identity, 'canonical nested B0 archive identity missing')
require(f'{FUNCTIONS_SHA256}     10557  SWAP/functions.f90' in manifest, 'functions.f90 B0 identity mismatch')
require(f'{IRRIGATION_SHA256}     33250  SWAP/irrigation.f90' in manifest, 'irrigation.f90 B0 identity mismatch')
require(f'member_manifest_sha256: "{B110_MANIFEST_SHA256}"' in b110, 'B1.10 manifest identity mismatch')
require('target: "SWAP/functions.f90"' not in b110, 'B1.10 unexpectedly patches functions.f90')
require('target: "SWAP/irrigation.f90"' not in b110, 'B1.10 unexpectedly patches irrigation.f90')
require(evidence['b110_identity']['functions_sha256'] == FUNCTIONS_SHA256, 'source evidence functions hash mismatch')
require(evidence['b110_identity']['irrigation_sha256'] == IRRIGATION_SHA256, 'source evidence irrigation hash mismatch')
require(evidence['b110_identity']['b110_patch_targets_functions_or_irrigation'] is False, 'source evidence patch-target guard weakened')
print('FPM04_B110_SOURCE_IDENTITY PASS')

# AFGEN must be represented without stale legacy SAVE-array tail state.
afgen = evidence['afgen']['restricted_target_contract']
require(afgen['pair_count'] == '2..7', 'AFGEN actual pair-count contract changed')
require(afgen['x_knots'] == 'finite and strictly increasing', 'AFGEN monotonicity guard changed')
require('must not exceed the last supplied knot' in afgen['evaluation'], 'partial-table above-last fail-closed guard missing')
require('explicit knot-count table' in afgen['implementation_form'], 'AFGEN explicit knot-count representation missing')
require(contract['afgen_admission_scope']['allow_above_last_knot_for_partial_table'] is False, 'partial AFGEN extrapolation accidentally admitted')
require(contract['afgen_admission_scope']['allow_duplicate_or_nonmonotone_knots'] is False, 'invalid AFGEN knots accidentally admitted')
require(contract['afgen_admission_scope']['allow_uninitialized_tail_sentinel_state'] is False, 'legacy stale table tail accidentally admitted')
print('FPM04_AFGEN_DETERMINISTIC_SUBSET PASS')

# Exact qualified owner contracts, read from their immutable source commits.
fsi = git_json(FSI17, 'integration/f-si/F-SI17_STATUS.json')
fmr = git_json(FMR07, 'integration/f-mr/F-MR07_STATUS.json')
fvq = git_json(FVQ18, 'integration/f-vq/F-VQ18_STATUS.json')
require(fsi['status'] == 'QUALIFIED' and fsi['source_blob'] == EXPECTED_BLOBS['src/solver/mod_process_hydraulic_view.f90'], 'F-SI17 qualification mismatch')
require('HeadCalc' in fsi['forbidden_dependencies_absent'], 'F-SI17 HeadCalc isolation evidence missing')
require(fmr['status'] == 'QUALIFIED', 'F-MR07 not qualified')
qc = fmr['qualified_contract']
require(qc['accepted_state'] == 'kernel_committed_state_t only', 'F-MR07 does not remain committed-only')
require(qc['candidate_state_accepted'] is False and qc['checkpoint_state_accepted'] is False, 'F-MR07 candidate/checkpoint view admitted')
require(qc['headcalc_internal_exposed'] is False and qc['solver_workspace_exposed'] is False, 'F-MR07 exposes solver internals')
require(fvq['status'] == 'QUALIFIED_FPM03_RESTRICTED_FIXED_EVENT_IRRIGATION_SCIENTIFIC_ADMISSION', 'F-VQ18 status mismatch')
cap = fvq['scientifically_admitted_capabilities']
require('authoritative SSDI external-inflow accounting exactly once' in cap, 'F-VQ18 SSDI mass route not admitted')
require('scheduled TCS1-TCS8 irrigation trigger equations' in fvq['not_admitted'], 'F-VQ18 scheduled trigger hold missing')
require('scheduled DCS1-DCS2 irrigation depth equations' in fvq['not_admitted'], 'F-VQ18 scheduled depth hold missing')
print('FPM04_OWNER_QUALIFICATION_LOCKS PASS')

# Existing provider must remain the precomputed source seam, not a process-to-HeadCalc shortcut.
provider = (ROOT / 'src/solver/mod_b110_source_sink_provider.f90').read_text(encoding='utf-8').lower()
require('subsurface_irrigation_source' in provider, 'SSDI source seam missing')
require('source = self%subsurface_irrigation_source' in provider, 'SSDI source not propagated by source/sink provider')
require('headcalc' not in provider, 'source/sink provider gained HeadCalc dependency')
print('FPM04_EXISTING_SSDI_SOURCE_SEAM PASS')

# Architectural holds must remain explicit.
require(contract['time_semantics']['kernel_one_day_interval_required'] is False, 'one-day kernel assumption introduced')
require(contract['time_semantics']['midnight_required'] is False, 'midnight kernel assumption introduced')
require(contract['after_pass']['independent_scientific_admission'].startswith('required in a later F-VQ'), 'independent scientific admission requirement missing')
require('surface scheduled application and gird-to-nird composition' in selected['excluded'], 'surface composition accidentally admitted')
print('FPM04_ARCHITECTURE_INVARIANTS PASS')

print('FPM04_READINESS_GATE PASS_ADMITTED_FOR_STRUCTURAL_TCS7_DCS2_SINGLE_NODE_SSDI_MIGRATION')
