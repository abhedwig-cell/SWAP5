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
- A combined reactive transaction now executes exact-order chemical sorption/decay/pond transfer and AgeTracer transport/production on the same accepted carrier and commits or rolls back both together.
- Runtime now has a distinct reactive solute layout identity (`505005`) with a typed initializer and restart validator; existing mobile-only layouts reject reactive companion state.
- Aquifer mutation is fail-closed in the current solute transaction model.

## Source-bound operators present

- B1.11 fixation policy, separate from admitted WOFOST81 semantics.
- Shared Soil-N management-event binding for amendments and crop residues: persistent event id, once-only application, duplicate rejection, and restart-preserved event lineage.
- Coupled Soil-N/crop-N state now persists previous-day root/leaf residue DM+N and consumes that residue before the next-day Soil-N process, matching the B1.11 day ordering for ordinary senescence.
- Soil-N source rate factors plus source-coupled mineral reaction bridges: NH4 disappearance from aggregate transport is converted into equal NO3 production, while NO3 first-order disappearance is booked as explicit external denitrification loss. Both use the interval-average transported concentration and preserve whole-N accounting.
- Aggregate Soil-N transport plus a one-day B1.11 mineral exchange caller and an integrated Soil-N candidate composing organic turnover, Cdissi-dependent rates, NH4/NO3 transport, nitrification and denitrification on one owner.
- Amendments and crop residues, including distinct B1.11 OM activation
  thresholds (1e-6 and 1e-12 respectively).
- Freundlich sorption, solute decay, pond exchange and age production.

## Not yet canonical admission

These owners/operators and the new reactive carrier layout are not by themselves proof of application-level
production reachability. Census capabilities remain open until the relevant
runtime/application route, restart identity and persisted qualification are
bound and reviewed.

## Explicit decision boundaries

- `SW431-NUT-ORGANIC`: the exact-source inconsistency is resolved by an accepted mass-consistent reference correction; production qualification still has to admit the integrated daily route. See `MC_NUT01_ORGANIC_SOURCE_DECISION.md`.
- `SW431-SALT-AQUIFER`: exact B1.11 has a reproduced out-of-bounds SWBR
  coefficient access; see `MC_SOL01_AQUIFER_SOURCE_DECISION.md`.

An atomic B1.11 Soil-N/crop-N transaction candidate now prepares crop soil demand, runs the Soil-N day, feeds the accepted Soil-N supply into the separate B1.11 crop-N owner, books soil uptake once as an internal transfer, books biological fixation once as external N input, and persists accepted interval lineage. WOFOST81 remains unchanged and N-unlimited on its already admitted route.

## 2026-10-07 nonlinear reactive SOL qualification recovery

- Canonical CI fanout fix was merged independently via PR #1116, merge
  `7e35749e8348f6d4ef0b35b96c8b06cb216ea036`. This does not qualify SOL.
- The matrix reactive substep, the combined chemical/age transaction and
  the accepted water-carrier adapter predate this update on the binding branch.
- A previously uncovered nonlinear Freundlich conflict was found: the
  inverse partition used a 1e-3 relative iterate stopping criterion while
  whole-chemical mass closure requires roundoff-scale closure. This could
  reject otherwise physically valid nonlinear substeps as unbalanced.
- The nonlinear inversion now uses a monotone bracket/bisection, retains
  the linear fast path, and returns NOCONV rather than silently admitting a
  result outside the mass tolerance. Current code recovery commit:
  `31db12cb1ebd5e2de89e6cd1b55e7ab400665834`.
- The multi-node test now checks `frexp=2`, total chemical conservation,
  concentration-dependent sorbed storage and rejected overdraw rollback.
  Test recovery commit: `d9078c6ce88fbc36fd83d7f93b11b0934f124361`.
- Locally exercised the **isolated mathematical bisection algorithm** on
  10,000 nonlinear storage values, O0 and O2, with bounds/FPE checks. This
  is **not** a compile/test of the committed Fortran module or integrated
  transaction. The repository was accessed via the GitHub connector because
  local GitHub DNS access was unavailable.
- Existing qualification run `37644330458` remains queued and covers an
  outdated pre-binding postimage; do not count it as qualification for these
  commits. No new Actions run was started.
- Required next gate: run `tests/physics/run_b111_reactive_solute_substep.sh`
  and `tests/physics/run_fmr_b111_reactive_solute_transaction.sh` on the
  exact binding HEAD at O0/O2; retain restart/layout and accepted-water-carrier
  tests, then integrated qualification. Do not admit any SOL01 capability
  before that evidence is persisted.
