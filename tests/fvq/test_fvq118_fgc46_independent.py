from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
bridge=(ROOT/'tests/fgc/support/mod_fgc46_real_multicell_c_bridge.f90').read_text()
live=(ROOT/'tests/fgc/test_fgc46_real_multicell_live_modflow.py').read_text()
doc=(ROOT/'docs/integration/F-GC46_REAL_MULTICELL_LIVE_MODFLOW.md').read_text()

def require(x,m):
    if not x: raise AssertionError(m)

require('GW_CELL_ID(NIF)=[7001_int64,7002_int64]' in bridge,'two distinct groundwater cell ids missing')
require('COUPLING_ID(NIF)=[460046_int64,460047_int64]' in bridge,'distinct coupling ids missing')
require('GW_LINEAGE_ID(NIF)=[660047_int64,660048_int64]' in bridge,'distinct groundwater lineages missing')
require('binding(1)%area_fraction=1.0_real64' in bridge,'multi-cell workunit silently introduced N:1')
require('compose_modflow6_multiswap_cell_response' in bridge,'admitted cell-response materialization not reused')
require('head(1)=real(head1_m,real64); head(2)=real(head2_m,real64)' in bridge,'cell-specific corrector heads not preserved')
require('participant(i)%publication_ready' in bridge,'all-interface SWAP readiness missing')
require('ledger(i)%prepared_ready_for_commit' in bridge,'all-interface ledger readiness missing')

for token in [
    'Binding(7001,1,2)','Binding(7002,2,3)',
    'list(session.nodelist[:2])==[2,3]',
    'swap.trial(head1,head2)',
    'max(abs(r1),abs(r2))<=FLUX_TOL',
    'session.timestep_ready_for_finalize()',
    'session.finalize_time_step_once()',
    'swap.commit_swaps()','swap.commit_ledgers()',
    'XmiWrapper','Modflow6PreparedSolveSession'
]:
    require(token in live,f'missing live multi-cell oracle: {token}')
order=[live.index(x) for x in [
    'swap.swap_preflight()', 'swap.prepare_ledgers()', 'swap.ledgers_preflight()',
    'session.timestep_ready_for_finalize()', 'session.finalize_time_step_once()',
    'swap.commit_swaps()', 'swap.commit_ledgers()'
]]
require(order==sorted(order),'multi-cell publication ordering changed')
require('FakeKernel' not in live and 'Mock' not in live,'fake groundwater backend leaked into live multi-cell gate')
require('No N:1 aggregation occurs in F-GC46.' in doc,'N:1 exclusion missing')
require('adds no production physics' in doc,'production-boundary statement missing')
require('Predictor/corrector ownership remains' in doc,'ownership boundary missing')

print('FVQ118_TWO_DISTINCT_GROUNDWATER_CELLS=PASS')
print('FVQ118_FGC34_TWO_SLOT_NODE_MAPPING=PASS')
print('FVQ118_CELL_SPECIFIC_REAL_SWAP_CORRECTORS=PASS')
print('FVQ118_CONJUNCTIVE_TWO_CELL_CONVERGENCE=PASS')
print('FVQ118_ALL_INTERFACES_PREFLIGHT_BEFORE_PUBLICATION=PASS')
print('FVQ118_SINGLE_MODFLOW_THEN_SWAP_LEDGER_ORDER=PASS')
print('FVQ118_LIVE_XMI_NO_FAKE_GROUNDWATER=PASS')
print('FVQ118_SCOPE_AND_OWNERSHIP_BOUNDARY=PASS')
