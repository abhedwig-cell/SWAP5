from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[2]
pred=(ROOT/'src/runtime/mod_fmr_groundwater_predictor_service.f90').read_text().lower()
reg=(ROOT/'src/runtime/mod_fmr_groundwater_participant_registry.f90').read_text().lower()
owner=(ROOT/'tests/fgc/test_fgc49b_fmr_groundwater_participant_registry.f90').read_text().lower()

def require(x,m):
    if not x: raise AssertionError(m)

require('type(kernel_committed_state_t), pointer :: committed' in reg,'registry copies committed state instead of referencing external owner')
require('kernel_executor_t' not in reg,'registry acquired raw kernel executor ownership')
require('iso_c_binding' not in reg and 'bind(c' not in reg,'stage B1 leaked language-boundary ABI into registry')
require('xmiwrapper' not in reg and 'prepare_solve' not in reg and 'finalize_time_step' not in reg,'registry acquired MODFLOW ownership')
require('fmr_groundwater_swap_participant_t' in reg,'admitted F-GC43 participant not reused')
require('build_fmr_groundwater_predictor_response' in reg,'generic predictor service not reused')
require('self%entries(index)%committed%current_revision()' in reg,'predictor lineage not rooted in external committed revision')
require('participant%capture_origin' in reg,'corrector origin not captured through admitted participant')
require('participant%trial_from_origin' in reg,'corrector does not use admitted same-origin participant')
require('participant%discard_candidate' in reg,'nonfinal candidate rollback path absent')
require('participant%commit_candidate' in reg,'kernel-owned commit path absent')
require('weighted_exchange_m = area_fraction * self%entries(index)%last_trial%bottom_outward_exchange_cm * 0.01_real64' in reg,'ledger is not topology-area weighted')
require('prepared_ready_for_commit' in reg,'ledger preflight absent')
require('if (self%entries(index)%swap_committed) return' in reg,'post-publication abort/commit guard absent')
require('self%entries(index)%handle == handle' in reg,'opaque handle identity lookup absent')

require('capture_modflow6_swap_predictor_origin' in pred,'F-GC30 committed predictor origin not reused')
require('build_modflow6_swap_predictor_tangent_endpoint' in pred,'F-GC30 tangent endpoint not reused')
require('assemble_modflow6_swap_predictor_response' in pred,'F-GC30 candidate assembler not reused')
require('if (.not. same_real(origin_face%hydraulic_head_m, accepted_interface%h_swap_m)) return' in pred,'accepted lower-face head provenance not verified')
require('if (.not. same_real(q_swap_expected, accepted_interface%q_swap_m_per_s)) return' in pred,'accepted predictor flux provenance not verified')
require(pred.count('discard_trial_candidate') >= 5,'predictor failure/success paths do not consistently rollback noncommitting candidate')
require('commit_trial_candidate' not in pred,'predictor service can commit a trial')

for marker in [
 'fgc49b_real_fmr_predictor_service=pass',
 'fgc49b_same_origin_repeatable_correctors=pass',
 'fgc49b_prepublication_abort_and_rebegin=pass',
 'fgc49b_external_committed_state_kernel_owned=pass',
 'fgc49b_area_weighted_ledger_commit=pass',
 'fgc49b_stale_handle_fail_closed=pass'
]:
    require(marker.replace('=pass','') in owner,f'owner executable oracle missing: {marker}')

print('FVQ122_EXTERNAL_COMMITTED_STATE_OWNERSHIP=PASS')
print('FVQ122_NO_RAW_KERNEL_OR_XMI_OWNERSHIP=PASS')
print('FVQ122_FGC30_PREDICTOR_CHAIN_REUSED=PASS')
print('FVQ122_FGC43_CORRECTOR_COMMIT_CHAIN_REUSED=PASS')
print('FVQ122_NONCOMMITTING_PREDICTOR_ROLLBACK=PASS')
print('FVQ122_AREA_WEIGHTED_PREPARED_LEDGER=PASS')
print('FVQ122_OPAQUE_HANDLE_AND_POSTPUBLICATION_GUARDS=PASS')
print('FVQ122_OWNER_REAL_FMR_ORACLES_PRESENT=PASS')
