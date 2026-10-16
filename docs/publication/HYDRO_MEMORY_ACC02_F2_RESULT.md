# HYDRO-MEMORY ACC02-F2 result

**Decision:** `ACC02_F2_PASS_FOUR_CONSECUTIVE_LIVE_ROOT_ACTIVE_WINDOWS`

Four consecutive live root-active SWAP-MODFLOW6 coupling windows pass under the unchanged HYDRO-MEMORY accuracy contract.

Authority:

- qualified head: `5e80554fe8d3f03471a823e81b3bf327141169be`
- workflow: **35459607211**
- job: **105940970075**
- live MODFLOW6: **6.8.0**, pinned asset hash verified

All four windows used the same 0.02 cm d-1 prescribed root sink, 0.1 cm temporal budget, 0.001 m interface-head tolerance, 1e-15 m s-1 fixed-point flux criterion and six-iteration ceiling.

| window | revision | time d | ledger count | coupled iterations | max temporal indicator | final head residual m | final flux residual |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1 | 0.0001 | 1 | 2 | 8.9539e-3 | 1.55e-15 | 6.11e-21 |
| 2 | 2 | 0.0002 | 2 | 2 | 9.5090e-5 | 9.99e-16 | 3.86e-21 |
| 3 | 3 | 0.0003 | 3 | 2 | 1.5723e-4 | 1.59e-11 | 6.26e-17 |
| 4 | 4 | 0.0004 | 4 | 2 | 2.6620e-4 | 2.54e-11 | 9.99e-17 |

The next-window predictor was not reconstructed from the initial hydrostatic fixture. After every accepted window it was rebuilt from the current committed SWAP state and the actual previously accepted SWAP-groundwater interface state, with dynamic revision and window lineage.

Revision, committed time and interface-ledger count advanced exactly once per window. Rejected/intermediate correctors remained nonmutating. The cumulative ledger matched the accepted per-window bottom exchanges. O0/O2 behavior remained equivalent.

## Consequence

The single-window result was not a lifecycle artifact. The restricted root-active coupling composition survives repeated live publication and recapture.

This still does not constitute a drought-recovery experiment. The remaining scientific prerequisite is no longer basic groundwater transaction persistence. It is the **dynamic research composition** needed by Stage 0: changing atmospheric forcing plus accepted-state-dependent restricted Feddes root uptake, followed by freezing the hydraulic soil sets and diagnostics.
