# MC-NUT01 / MC-SOL01 production successor

Status: **IN_PROGRESS**

Active binding branch: `work/swap431-nut-sol-binding-recovery-20261007`

Frozen qualification PR: **#1112** at `56c007c236a940b97c3e9aefa4d49a4aeb6634dc`.

## Transaction owners now present

- Soil-N owner: FOM, biomass OM, humus OM, NH4-N and NO3-N are one
  transaction state with whole-N storage accounting, candidate-only mutation,
  rejected-overdraw rollback, and restart reconstruction.
- Solute owner: dissolved mobile mass plus sorbed matrix, pond, aquifer storage
  and age amount are carried atomically. Chemical mass excludes age amount.
- Runtime now has a distinct reactive solute layout identity (`505005`) with a typed initializer and restart validator; existing mobile-only layouts reject reactive companion state.
- Aquifer mutation is fail-closed in the current solute transaction model.

## Source-bound operators present

- B1.11 fixation policy is now consumed by a separate atomic Soil-Crop N transaction; WOFOST81 remains untouched.
- Shared Soil-N management-event binding: grouped legacy-date amendments apply exactly once with restart-preserved event lineage; crop root and configured leaf residue N can return internally from the crop owner to Soil-N.
- Soil-N source rate factors plus source-coupled mineral reaction bridges: NH4 disappearance from aggregate transport is converted into equal NO3 production, while NO3 first-order disappearance is booked as explicit external denitrification loss. Both use the interval-average transported concentration and preserve whole-N accounting.
- Aggregate Soil-N transport plus a one-day B1.11 mineral exchange caller and an integrated Soil-N candidate composing organic turnover, Cdissi-dependent rates, NH4/NO3 transport, nitrification and denitrification on one owner.
- Amendments and crop residues, including distinct B1.11 OM activation
  thresholds (1e-6 and 1e-12 respectively).
- Freundlich sorption, solute decay and pond exchange are composed in one source-order reactive chemical transaction. AgeTracer has a separate transaction over pond age + matrix age amount with chemical-state isolation.

## Not yet canonical admission

MC-NUT01 now has transaction/event reachability candidates for all nine listed capabilities, including atomic Soil-Crop uptake/fixation, grouped amendments and internal crop-residue return. MC-SOL01 now has transaction-reachable matrix candidates for sorption, decay, pond exchange and AgeTracer (pond+matrix infiltration envelope); aquifer remains decision-blocked. None of these are canonical admissions until persisted integrated qualification is green and reviewed.

## Explicit decision boundaries

- `SW431-NUT-ORGANIC`: the exact-source inconsistency is resolved by an accepted mass-consistent reference correction; production qualification still has to admit the integrated daily route. See `MC_NUT01_ORGANIC_SOURCE_DECISION.md`.
- `SW431-SALT-AQUIFER`: exact B1.11 has a reproduced out-of-bounds SWBR
  coefficient access; see `MC_SOL01_AQUIFER_SOURCE_DECISION.md`.

An atomic B1.11 Soil-N/crop-N transaction candidate now prepares crop soil demand, runs the Soil-N day, feeds the accepted Soil-N supply into the separate B1.11 crop-N owner, books soil uptake once as an internal transfer, books biological fixation once as external N input, and persists accepted interval lineage. WOFOST81 remains unchanged and N-unlimited on its already admitted route.
