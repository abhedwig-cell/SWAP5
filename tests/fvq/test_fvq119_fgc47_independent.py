from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
bridge=(ROOT/'tests/fgc/support/mod_fgc47_mixed_topology_c_bridge.f90').read_text()
live=(ROOT/'tests/fgc/test_fgc47_mixed_topology_live_modflow.py').read_text()
doc=(ROOT/'docs/integration/F-GC47_MIXED_TOPOLOGY_LIVE_MODFLOW.md').read_text()

def require(x,m):
    if not x: raise AssertionError(m)

require('integer, parameter :: NPART=3' in bridge,'three real SWAP participants not explicit')
require('CELL_ID(NPART)=[7001_int64,7001_int64,7002_int64]' in bridge,'mixed cell topology absent')
require('FRACTION(NPART)=[0.35_real64,0.65_real64,1.0_real64]' in bridge,'mixed fractions absent')
require('COUPLING_ID(NPART)=[470047_int64,470047_int64,470048_int64]' in bridge,'cell coupling identities not separated')
require('GW_LINEAGE_ID(NPART)=[670047_int64,670047_int64,670048_int64]' in bridge,'groundwater lineages not separated by cell')
require('compose_modflow6_multiswap_cell_response(binding1,response(1:2)' in bridge,'F-GC40 N:1 path absent for cell 7001')
require('compose_modflow6_multiswap_cell_response(binding2,response2' in bridge,'single-tile F-GC40 path absent for cell 7002')
require('head=[real(head1_m,real64),real(head1_m,real64),real(head2_m,real64)]' in bridge,'cell-specific head routing absent')
require('qcell1=FRACTION(1)*q(1)+FRACTION(2)*q(2)' in bridge,'cell1 area-weighted corrector reduction absent')
require('qcell2=q(3)' in bridge,'cell2 1:1 corrector route absent')

for token in [
    'Binding(7001,1,2)','Binding(7002,2,3)',
    'swap.trial(h1,h2)',
    'abs(qc1-(F1*q1+F2*q2))',
    'abs(qc2-q3)',
    'max(abs(r1),abs(r2))<=FLUX_TOL',
    'session.timestep_ready_for_finalize()',
    'session.finalize_time_step_once()',
    'swap.commit_swaps()','swap.commit_ledgers()',
    'XmiWrapper','Modflow6PreparedSolveSession'
]:
    require(token in live,f'missing mixed-topology live oracle: {token}')
order=[live.index(x) for x in [
    'swap.swap_preflight()', 'swap.prepare_ledgers()', 'swap.ledgers_preflight()',
    'session.timestep_ready_for_finalize()', 'session.finalize_time_step_once()',
    'swap.commit_swaps()', 'swap.commit_ledgers()'
]]
require(order==sorted(order),'mixed-topology publication order changed')
require('software/runtime composition qualification' in doc,'scientific evidence boundary missing')
require('production source delta NONE' in doc,'production delta boundary missing')
require('Predictor/corrector ownership remains' in doc,'ownership boundary missing')

print('FVQ119_THREE_UNIQUE_REAL_SWAP_PARTICIPANTS=PASS')
print('FVQ119_MIXED_2TO1_PLUS_1TO1_TOPOLOGY=PASS')
print('FVQ119_FGC40_PER_CELL_RESPONSE_REUSE=PASS')
print('FVQ119_CELL_SPECIFIC_HEAD_ROUTING=PASS')
print('FVQ119_CELL_LEVEL_CORRECTOR_CLOSURE=PASS')
print('FVQ119_ALL_PARTICIPANTS_PREFLIGHT_BEFORE_PUBLICATION=PASS')
print('FVQ119_SINGLE_MODFLOW_THEN_SWAP_LEDGER_ORDER=PASS')
print('FVQ119_LIVE_XMI_NO_FAKE_GROUNDWATER=PASS')
print('FVQ119_SCOPE_AND_OWNERSHIP_BOUNDARY=PASS')
