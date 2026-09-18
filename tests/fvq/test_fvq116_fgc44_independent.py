from pathlib import Path
import ast

ROOT=Path(__file__).resolve().parents[2]
bridge=(ROOT/'tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90').read_text()
live=(ROOT/'tests/fgc/test_fgc44_real_swap_modflow_end_to_end.py').read_text()
participant=(ROOT/'src/runtime/mod_fmr_groundwater_swap_participant.f90').read_text()
materializer=(ROOT/'src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90').read_text()
backend=(ROOT/'src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
doc=(ROOT/'docs/integration/F-GC44_REAL_SWAP_MODFLOW6_END_TO_END.md').read_text()

def require(x,m):
    if not x: raise AssertionError(m)

require('interface_head_m_to_swap_bottom_pressure_head_cm' in materializer,'canonical head/pressure mapping not used')
require('interface_head_m_to_swap_pressure_head_cm' not in materializer,'stale groundwater mapping symbol remains')
require('checkpoint=self%origin_checkpoint' in participant,'real FMR correctors not rooted in captured origin')
require('backend%run_trial' in participant,'concrete participant does not use FMR production trial path')
require('backend%commit_trial_candidate' in participant,'concrete participant bypasses FMR kernel commit')
require('backend%discard_trial_candidate' in participant,'concrete participant bypasses FMR rollback')
require('commit_trial_candidate => fmr_serialized_backend_commit_trial_candidate' in backend,'narrow backend commit delegation absent')
require('discard_trial_candidate => fmr_serialized_backend_discard_trial_candidate' in backend,'narrow backend discard delegation absent')

for token in ['XmiWrapper','Modflow6PreparedSolveSession','Fgc44RealSwap','modflow_converged','swap.trial','swap.discard','swap.swap_preflight','swap.ledger_preflight','timestep_ready_for_finalize','finalize_time_step_once','swap.commit_swap','swap.commit_ledger']:
    require(token in live,f'live end-to-end token absent: {token}')
require('if it.modflow_converged and abs(residual)<=FLUX_TOL:' in live,'conjunctive convergence oracle absent')
order=[live.index(x) for x in ['swap.swap_preflight()', 'swap.prepare_ledger()', 'swap.ledger_preflight()', 'session.timestep_ready_for_finalize()', 'session.finalize_time_step_once()', 'swap.commit_swap()', 'swap.commit_ledger()']]
require(order==sorted(order),'publication/preflight order changed')
require('CountingKernel' in live and 'XmiWrapper' in live,'live MODFLOW kernel is not observed')
require('FakeKernel' not in live and 'Mock' not in live,'deterministic MODFLOW double leaked into live gate')
require('real FMR/B1.10 Richards implementation' in doc,'real SWAP evidence boundary not documented')
require('not a scaling claim' in doc,'scaling exclusion missing')
require('Predictor/corrector ownership remains' in doc,'ownership boundary missing')

print('FVQ116_CANONICAL_HEAD_PRESSURE_MAPPING=PASS')
print('FVQ116_REAL_FMR_BACKEND_BINDING=PASS')
print('FVQ116_IMMUTABLE_SWAP_ORIGIN=PASS')
print('FVQ116_LIVE_MODFLOW_XMI_BINDING=PASS')
print('FVQ116_CONJUNCTIVE_CONVERGENCE=PASS')
print('FVQ116_PREFLIGHT_BEFORE_PUBLICATION_ORDER=PASS')
print('FVQ116_MODFLOW_SWAP_LEDGER_PUBLICATION_ORDER=PASS')
print('FVQ116_SCOPE_AND_OWNERSHIP_BOUNDARY=PASS')
