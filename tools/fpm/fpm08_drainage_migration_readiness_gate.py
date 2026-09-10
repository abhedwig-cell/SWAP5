#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path

ROOT = Path('.')
BASE = 'df435824de175e3f868b680aab2cd0a395aa19ff'
DECISION = 'QUALIFIED_DRAINAGE_MIGRATION_READINESS_READY_FOR_RESTRICTED_STRUCTURAL_CANDIDATE'

LEGACY_ARCHIVE_SHA = '1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
DRAINAGE_SHA = '48e4792acd0a129a6939008bd51e82f9fed4668fcf8d28d03da0bc6efe6944cc'
MOD_DRAINAGE_SHA = 'cb354ea13a099422c9f3b9c87a60ccbe440c0dd3c83ba0502108da8ca70ff255'
DIVDRA_SHA = 'd5917c80dde091f8264f875997ee7105d8b5f9b88e9d091ce162860930de8c91'
HEADCALC_SHA = 'db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5'
SURFACEWATER_SHA = 'd38e25da1b71cf3d7872df294b1de6080e070a314f9168b8a4e4d3ff1526089e'

SOURCE_SINK_BLOB = 'd6c57add72387e5c0022a44319fff08046194aac'
SOLVER_CONTRACT_BLOB = 'dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0'
HYDRAULIC_VIEW_BLOB = 'd7d85fe71ced0d94b29c8d9395859ae1834f7dd6'
COMMITTED_VIEW_BINDING_BLOB = '37f5968ffe00b1ff56f824f77ab94d3825171acf'


def blob(path: str) -> str:
    return subprocess.check_output(['git', 'hash-object', path], text=True).strip()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


status = json.loads((ROOT / 'integration/f-pm/F-PM08_STATUS.json').read_text())
inventory = json.loads((ROOT / 'integration/f-pm/F-PM08_DRAINAGE_INVENTORY.json').read_text())
contract = json.loads((ROOT / 'integration/f-pm/F-PM08_READINESS_CONTRACT.json').read_text())
doc = (ROOT / 'integration/f-pm/F-PM08_DRAINAGE_MIGRATION_READINESS.md').read_text()
manifest = (ROOT / 'reference/swap-4.3.1/b0/file-manifest.sha256').read_text()

require(status['source_authority']['exact_branch_base'] == BASE, 'status base mismatch')
require(inventory['exact_branch_base'] == BASE, 'inventory base mismatch')
require(contract['exact_branch_base'] == BASE, 'contract base mismatch')
require(contract['required_decision'] == DECISION, 'contract decision mismatch')
require(inventory['decision'] == DECISION, 'inventory decision mismatch')
require(DECISION in doc, 'human-readable decision missing')
print('FPM08_READINESS_CONTRACT PASS')

subprocess.run(['git', 'merge-base', '--is-ancestor', BASE, 'HEAD'], check=True)
changed = subprocess.check_output(
    ['git', 'diff', '--name-only', BASE, 'HEAD', '--', 'src', 'reference'], text=True
).splitlines()
require(changed == [], f'F-PM08 readiness changed production/reference source: {changed}')
require(not (ROOT / 'src/process/mod_drainage_process.f90').exists(), 'F-PM08 must not implement drainage production process')
print('FPM08_NO_PRODUCTION_OR_REFERENCE_CHANGE PASS')

for sha, path in [
    (DRAINAGE_SHA, 'SWAP/drainage.f90'),
    (MOD_DRAINAGE_SHA, 'SWAP/MOD_drainage.f90'),
    (DIVDRA_SHA, 'SWAP/divdra.f90'),
    (HEADCALC_SHA, 'SWAP/headcalc.f90'),
    (SURFACEWATER_SHA, 'SWAP/surfacewater.f90'),
]:
    require(sha in manifest and path in manifest, f'legacy source lock missing: {path}')
require(LEGACY_ARCHIVE_SHA in manifest, 'canonical legacy archive identity missing')
locks = contract['source_locks']
require(locks['legacy_archive_sha256'] == LEGACY_ARCHIVE_SHA, 'archive lock mismatch')
require(locks['drainage_f90_sha256'] == DRAINAGE_SHA, 'drainage source lock mismatch')
require(locks['mod_drainage_f90_sha256'] == MOD_DRAINAGE_SHA, 'MOD_drainage source lock mismatch')
require(locks['divdra_f90_sha256'] == DIVDRA_SHA, 'DIVDRA source lock mismatch')
print('FPM08_B110_DRAINAGE_SOURCE_LOCK PASS')

require(blob('src/solver/mod_b110_source_sink_provider.f90') == SOURCE_SINK_BLOB, 'source/sink provider drift')
require(blob('src/solver/mod_soil_water_solver_contract.f90') == SOLVER_CONTRACT_BLOB, 'solver contract drift')
require(blob('src/solver/mod_process_hydraulic_view.f90') == HYDRAULIC_VIEW_BLOB, 'hydraulic view drift')
require(blob('src/runtime/mod_fmr_process_hydraulic_view_binding.f90') == COMMITTED_VIEW_BINDING_BLOB, 'committed view binding drift')

source_sink = (ROOT / 'src/solver/mod_b110_source_sink_provider.f90').read_text().lower()
solver_contract = (ROOT / 'src/solver/mod_soil_water_solver_contract.f90').read_text().lower()
hydraulic_view = (ROOT / 'src/solver/mod_process_hydraulic_view.f90').read_text().lower()
view_binding = (ROOT / 'src/runtime/mod_fmr_process_hydraulic_view_binding.f90').read_text().lower()

require('drainage_flux_by_level(:,:)' in source_sink, 'current precomputed drainage seam missing')
require('sink = sink + self%drainage_flux_by_level(level,:)' in source_sink, 'current drainage sink consumption changed')
require('subroutine source_sink_evaluate_ifc(self, pressure_head, water_content, source, sink)' in solver_contract,
        'generic source/sink callback signature changed')
require('groundwater_level' in hydraulic_view, 'process hydraulic view lacks groundwater level')
require('kernel_committed_state_t' in view_binding and '%snapshot' in view_binding,
        'committed hydraulic view binding changed')
print('FPM08_CURRENT_HYDRAULIC_AND_SINK_SEAMS_LOCKED PASS')

require(inventory['architectural_decomposition']['single_legacy_process_family'] is False,
        'legacy drainage incorrectly classified as one migration object')
families = {f['id'] for f in inventory['architectural_decomposition']['families']}
require(families == {'DRAINAGE_EXCHANGE_LAW', 'DRAINAGE_SPATIAL_DISTRIBUTION', 'SURFACE_WATER_STORAGE_AND_CONTROL'},
        'architectural family decomposition changed')
require(contract['boundary_rules']['runtime_coupler_owns_system_composition'] is True,
        'runtime/coupler ownership missing')
require(contract['boundary_rules']['headcalc_internal_access_allowed'] is False,
        'HeadCalc internals accidentally admitted')
require(contract['boundary_rules']['process_jacobian_mutation_allowed'] is False,
        'process Jacobian mutation accidentally admitted')
print('FPM08_PROCESS_BOUNDARY_DECOMPOSITION PASS')

mass = contract['mass_rules']
require(mass['positive_exchange_means_out_of_soil'] is True, 'mass sign convention missing')
require(mass['single_transfer_object_for_state_and_ledger'] is True, 'single transfer identity missing')
require(mass['rejected_trial_committed_booking_allowed'] is False, 'rejected trial mass booking admitted')
require(mass['double_booking_allowed'] is False, 'double mass booking admitted')
require(mass['configurable_mass_tolerance_allowed'] is False, 'mass tolerance concession admitted')
print('FPM08_TRANSACTIONAL_MASS_CONTRACT PASS')

derivative = contract['derivative_rules']
require(derivative['process_owns_physical_response_derivative'] is True, 'physical derivative ownership missing')
require(derivative['solver_owns_jacobian_assembly'] is True, 'solver Jacobian ownership missing')
require(derivative['solver_owns_chain_rule_to_solver_unknowns'] is True, 'solver chain-rule ownership missing')
require(derivative['nonsmooth_branch_must_be_diagnostic'] is True, 'nonsmooth branch diagnostics missing')
require(derivative['fully_implicit_drainage_admitted_now'] is False, 'fully implicit drainage prematurely admitted')
print('FPM08_DERIVATIVE_OWNERSHIP PASS')

time = contract['time_rules']
require(time['fundamental_daily_step'] is False, 'daily time step assumption admitted')
require(time['kernel_interval_is_generic_t0_t1'] is True, 'generic interval contract missing')
require(time['calendar_and_file_table_resolution_outside_kernel'] is True, 'calendar/I-O leaked into kernel')
require(time['control_event_may_force_runtime_subdivision'] is True, 'control-event subdivision contract missing')
print('FPM08_GENERIC_TIME_CONTRACT PASS')

candidate = contract['selected_candidate']
require(candidate['child'] == 'F-PM08A', 'wrong first child candidate')
require(candidate['frozen_within_soil_water_solve'] is True, 'legacy-faithful frozen flux policy missing')
require(candidate['persistent_process_state'] is False, 'selected candidate gained persistent state')
require(candidate['required_hydraulic_field'] == 'groundwater_level', 'selected candidate hydraulic field changed')
require(candidate['required_external_control'] == 'drain_head', 'selected candidate control changed')
required_tokens = ['SWDRA=1', 'DRAMET=3', 'NRLEVS=1', 'drainage-only', 'no interflow', 'no DIVDRA', 'no surface-water storage', 'no macropore', 'no solute']
for token in required_tokens:
    require(token in candidate['scope'], f'selected scope lost restriction: {token}')
print('FPM08_RESTRICTED_FIRST_CANDIDATE PASS')

children = contract['child_workunits_required']
require(children == ['F-PM08A', 'F-PM08B', 'F-PM08C', 'F-PM08D'], 'child workunit decomposition changed')
inv_children = [c['id'] for c in inventory['child_workunits']]
require(inv_children == children, 'inventory/contract child mismatch')
require(len(contract['hard_holds']) >= 8, 'hard hold set unexpectedly weakened')
print('FPM08_CHILD_WORKUNITS_AND_HOLDS PASS')

for invariant in range(1, 31):
    require(f'| {invariant} |' in doc or f'| {invariant} |' in doc.replace(':', ''),
            f'invariant {invariant} missing from human audit')
print('FPM08_30_INVARIANT_AUDIT_PRESENT PASS')

print(f'FPM08_DRAINAGE_MIGRATION_READINESS {DECISION}')
