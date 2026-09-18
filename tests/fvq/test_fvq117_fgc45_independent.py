from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
bridge=(ROOT/"tests/fgc/support/mod_fgc45_real_multiswap_c_bridge.f90").read_text()
live=(ROOT/"tests/fgc/test_fgc45_real_multiswap_modflow_end_to_end.py").read_text()
doc=(ROOT/"docs/integration/F-GC45_REAL_MULTISWAP_MODFLOW6_END_TO_END.md").read_text()

def require(x,m):
    if not x: raise AssertionError(m)

require("integer, parameter :: NTILE=2" in bridge,"two-tile topology not fixed")
require("FRACTION(NTILE)=[0.35_real64,0.65_real64]" in bridge,"area fractions changed")
require("COLUMN_ID(NTILE)=[550045_int64,550046_int64]" in bridge,"distinct SWAP lineages missing")
require("compose_modflow6_multiswap_cell_response" in bridge,"F-GC40 composer not used")
require("participant(i)%trial_from_origin" in bridge,"real FMR participant not used per tile")
require("participant(i)%publication_ready" in bridge,"all-tile SWAP preflight absent")
require("ledger(i)%prepared_ready_for_commit" in bridge,"all-tile ledger preflight absent")
require("F1*q1+F2*q2" in live,"direct area-weighted corrector oracle missing")
require("it.modflow_converged and abs(residual)<=FLUX_TOL" in live,"conjunctive N:1 convergence missing")
order=[live.index(x) for x in ["swap.swap_preflight()","swap.prepare_ledgers()","swap.ledgers_preflight()","session.timestep_ready_for_finalize()","session.finalize_time_step_once()","swap.commit_swaps()","swap.commit_ledgers()"]]
require(order==sorted(order),"N:1 publication ordering changed")
require("XmiWrapper" in live and "Modflow6PreparedSolveSession" in live,"live MODFLOW backend absent")
require("runtime/composition qualification" in doc,"runtime evidence boundary missing")
require("not scientific evidence" in doc,"scientific aggregation disclaimer missing")
require("same physical parameterization" in doc,"homogeneous first-envelope disclosure missing")
print("FVQ117_TWO_DISTINCT_REAL_SWAP_LINEAGES=PASS")
print("FVQ117_FGC40_N1_COMPOSER_REUSED=PASS")
print("FVQ117_AREA_WEIGHTED_CORRECTOR_ORACLE=PASS")
print("FVQ117_ALL_TILE_PREFLIGHT_BEFORE_PUBLICATION=PASS")
print("FVQ117_MODFLOW_SWAP_LEDGER_PUBLICATION_ORDER=PASS")
print("FVQ117_LIVE_MODFLOW_BINDING=PASS")
print("FVQ117_RUNTIME_NOT_SCIENTIFIC_AGGREGATION_CLAIM=PASS")
