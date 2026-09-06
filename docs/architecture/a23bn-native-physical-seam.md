# A23BN native physical seam contract

## Purpose

Provide the first in-process physical execution adapter between the A23BL transaction kernel and provenance-qualified B1.6 Hupsel physics.

## Ownership

A23BL owns checkpoint, trial cloning, accept/reject, retry and commit. The adapter owns translation between an A23BL state object and the current legacy B1.6 module state. Legacy files and parsing are adapter initialization concerns only.

## Trial contract

For every `advance(state,t0,t1)` the adapter:

1. restores the supplied state into legacy modules;
2. establishes the requested legacy time window;
3. runs B1.6 in the same process;
4. captures the resulting state back into the supplied state object;
5. returns independent water input/output totals and nonlinear-iteration cost.

No restart file or subprocess may be used for steps 1-5.

## Explicit replay capsule

Exact Hupsel replay requires the meteorological cursor (`meteo_rec`, `rain_rec`, `i_metdetail`, `fl_update_meteo`) and active `cmsy(:)` in addition to the continuation fields represented in the B1.6 restart state. These values are a legacy replay requirement and must not automatically be treated as final SWAP5 persistent physical state.

## Mass gate

Water input/output is obtained from differences in B1.6 cumulative integration counters, making multi-day full trials independently auditable. Legacy cumulative output counters are not canonical transaction state and may not be used as committed SWAP5 results.

## Time restriction

The A23BN Hupsel bridge accepts integer-day boundaries because it still enters B1.6 through its legacy reinitialization seam. This is a bridge restriction, not an A23BL kernel restriction and not a target SWAP5 time contract.

## Production exclusions

The adapter is not thread-safe or MultiSWAP-ready because B1.6 physics remains module-global. It is a verification bridge used to qualify subsequent extraction to explicit per-column state and worker-owned scratch.
