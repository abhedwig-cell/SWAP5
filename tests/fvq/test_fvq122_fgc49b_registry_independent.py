from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
src=(ROOT/'src/runtime/mod_fmr_groundwater_participant_registry.f90').read_text().lower()
owner=(ROOT/'tests/fgc/test_fgc49b_fmr_participant_registry.f90').read_text().lower()

def require(x,m):
    if not x:
        raise AssertionError(m)

require('type(kernel_committed_state_t), pointer :: committed' in src,
        'registry must reference, not copy, committed SWAP state')
require('type(fmr_serialized_reference_backend_t), pointer :: backend' in src,
        'registry must retain backend owner by reference')
require('type(fmr_b110_physical_parameters_t), pointer :: parameters' in src,
        'large immutable parameters should remain externally owned')
require('type(fmr_groundwater_head_forcing_materializer_t), pointer :: materializer' in src,
        'forcing materializer ownership must remain external')
for forbidden in [
    'kernel_executor_t',
    'modflow6_prepared_solve_session',
    'xmiwrapper',
    'finalize_time_step',
    'prepare_solve',
    'groundwater_interface_mass_ledger_t',
    'mod_groundwater_topology_composition',
    'bind(c',
]:
    require(forbidden not in src, f'forbidden ownership leaked into registry: {forbidden}')

for token in [
    '%participant%capture_origin',
    '%participant%trial_from_origin',
    '%participant%discard_candidate',
    '%participant%publication_ready',
    '%participant%commit_candidate',
]:
    require(token in src, f'missing delegation: {token}')

bind_block=src.split('subroutine registry_bind',1)[1].split('end subroutine registry_bind',1)[0]
require('if (.not. self%slots(i)%used)' in bind_block,'released slots must not be recycled')
require('self%slots(slot)%handle_id = self%next_handle' in bind_block,'opaque handle assignment missing')
require('self%next_handle = self%next_handle + 1_int64' in bind_block,'monotonic handle increment missing')

init_block=src.split('subroutine registry_initialize',1)[1].split('end subroutine registry_initialize',1)[0]
require('self%next_handle = 1_int64' not in init_block,'reinitialize resets handle generation')

release_block=src.split('subroutine registry_release',1)[1].split('end subroutine registry_release',1)[0]
require('participant%has_live_candidate()' in release_block,'release must test live candidate')
require('fmr_gw_registry_release_busy' in release_block,'busy release must fail closed')
require(release_block.index('participant%has_live_candidate()') < release_block.index('%active = .false.'),
        'release deactivates before live-candidate preflight')

resolve_block=src.split('subroutine resolve_handle_const',1)[1].split('end subroutine resolve_handle_const',1)[0]
require('if (.not. self%slots(i)%active) cycle' in resolve_block,'inactive handle must not resolve')
require('self%slots(i)%handle_id == handle' in resolve_block,'handle identity comparison missing')

for token in [
    'fgc49b_two_real_fmr_handles=pass',
    'fgc49b_handle_isolation=pass',
    'fgc49b_release_busy_fail_closed=pass',
    'fgc49b_stale_handle_fail_closed=pass',
    'fgc49b_monotonic_handle_across_reinitialize=pass',
    'fgc49b_kernel_remains_commit_owner=pass',
]:
    require(token in owner, f'missing real-owner oracle: {token}')

print('FVQ122_COMMITTED_STATE_REFERENCE_NOT_COPY=PASS')
print('FVQ122_BACKEND_AND_PARAMETERS_EXTERNALLY_OWNED=PASS')
print('FVQ122_DELEGATES_TO_ADMITTED_FMR_PARTICIPANT=PASS')
print('FVQ122_NO_MODFLOW_LEDGER_OR_SOLVER_OWNERSHIP=PASS')
print('FVQ122_NONRECYCLING_MONOTONIC_HANDLES=PASS')
print('FVQ122_RELEASE_PREFLIGHT_BEFORE_DEACTIVATION=PASS')
print('FVQ122_INACTIVE_STALE_HANDLE_CANNOT_RESOLVE=PASS')
print('FVQ122_REAL_TWO_HANDLE_OWNER_ORACLES_PRESENT=PASS')
