from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
bridge=(ROOT/'tests/fgc/support/mod_fgc45_real_multiswap_c_bridge.f90').read_text()
live=(ROOT/'tests/fgc/test_fgc45_real_multiswap_n1_live_modflow.py').read_text()
doc=(ROOT/'docs/integration/F-GC45_REAL_MULTISWAP_N1_LIVE_MODFLOW.md').read_text()

def require(x,m):
    if not x: raise AssertionError(m)

for token in ['integer, parameter :: NTILE=2','TILE_IDS(NTILE)=[550045_int64,550046_int64]','FRACTIONS(NTILE)=[0.375_real64,0.625_real64]','KSAT_SCALES(NTILE)=[1.0_real64,0.82_real64]']:
    require(token in bridge,f'missing explicit two-tile topology/heterogeneity: {token}')
require('compose_modflow6_multiswap_cell_response(bindings,responses,href,cell,status)' in bridge,'F-GC40 is not authoritative N:1 predictor reducer')
require('q_area_weighted_m_per_s=q_area_weighted_m_per_s+FRACTIONS(i)*tiles(i)%last_trial%q_swap_m_per_s' in bridge,'corrector aggregation is not area weighted')
require('real(head_m,real64)' in bridge and 'do i=1,NTILE' in bridge,'common MODFLOW head is not supplied to all real SWAP tiles')
require('participant%publication_ready' in bridge,'tile publication preflight absent')
require('prepared_ready_for_commit' in bridge,'tile ledger preflight absent')
require("error stop 'F-GC45 late SWAP tile commit failed after prior tile publication'" in bridge,'late partial tile publication is not fail-hard')

for token in ['XmiWrapper','Modflow6PreparedSolveSession','Fgc45RealMultiSwap','swap.predictor_meta()','direct_qref','swap.trial(head)','swap.discard()','session.timestep_ready_for_finalize()','swap.commit_swap()','swap.commit_ledgers()']:
    require(token in live,f'live N:1 oracle missing: {token}')
require('if it.modflow_converged and abs(residual)<=FLUX_TOL:' in live,'conjunctive N:1 convergence absent')
order=[live.index(x) for x in ['swap.swap_preflight()', 'swap.prepare_ledgers()', 'swap.ledger_preflight()', 'session.timestep_ready_for_finalize()', 'session.finalize_time_step_once()', 'swap.commit_swap()', 'swap.commit_ledgers()']]
require(order==sorted(order),'N:1 preflight/publication order changed')
require('FakeKernel' not in live and 'Mock' not in live,'fake MODFLOW leaked into live N:1 gate')
require('not a scientific claim that arbitrary spatial aggregation is valid' in doc,'scientific scaling boundary missing')
require('Predictor/corrector ownership remains' in doc,'ownership boundary missing')

print('FVQ117_TWO_UNIQUE_REAL_SWAP_LINEAGES=PASS')
print('FVQ117_FGC40_AUTHORITATIVE_N1_REDUCTION=PASS')
print('FVQ117_AREA_WEIGHTED_REAL_CORRECTORS=PASS')
print('FVQ117_COMMON_LIVE_MODFLOW_HEAD=PASS')
print('FVQ117_ALL_TILE_PREFLIGHTS_BEFORE_PUBLICATION=PASS')
print('FVQ117_LIVE_XMI_NO_FAKE_GROUNDWATER=PASS')
print('FVQ117_SCOPE_AND_OWNERSHIP_BOUNDARY=PASS')
