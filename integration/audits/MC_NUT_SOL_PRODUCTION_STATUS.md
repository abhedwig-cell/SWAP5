# MC-NUT01 / MC-SOL01 production successor

Status: **IN_PROGRESS**

Active binding branch: `work/swap431-nut-sol-binding-20261007`

Frozen qualification PR: **#1112** at `56c007c236a940b97c3e9aefa4d49a4aeb6634dc`.

## Transaction owners now present

- Soil-N owner: FOM, biomass OM, humus OM, NH4-N and NO3-N are one
  transaction state with whole-N storage accounting, candidate-only mutation,
  rejected-overdraw rollback, and restart reconstruction.
- Solute owner: dissolved mobile mass plus sorbed matrix, pond, aquifer storage
  and age amount are carried atomically. Chemical mass excludes age amount.
- Aquifer mutation is fail-closed in the current solute transaction model.

## Source-bound operators present

- B1.11 fixation policy, separate from admitted WOFOST81 semantics.
- Soil-N nitrification/denitrification transfers and source rate factors.
- Aggregate Soil-N transport.
- Amendments and crop residues, including distinct B1.11 OM activation
  thresholds (1e-6 and 1e-12 respectively).
- Freundlich sorption, solute decay, pond exchange and age production.

## Not yet canonical admission

These owners/operators are not by themselves proof of application-level
production reachability. Census capabilities remain open until the relevant
runtime/application route, restart identity and persisted qualification are
bound and reviewed.

## Explicit decision boundaries

- `SW431-NUT-ORGANIC`: exact B1.11 contains inconsistent organic-N
  mineralisation bookkeeping expressions; see
  `MC_NUT01_ORGANIC_SOURCE_DECISION.md`.
- `SW431-SALT-AQUIFER`: exact B1.11 has a reproduced out-of-bounds SWBR
  coefficient access; see `MC_SOL01_AQUIFER_SOURCE_DECISION.md`.

WOFOST81 remains unchanged and N-unlimited on its already admitted route.
