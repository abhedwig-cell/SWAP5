# TAB-HYD typed-provider integration boundary

Date: 2026-09-20

Status: **research architecture note; no production implementation or admission**

## Purpose

Record where a qualified tabulated-hydraulics acceleration could fit in current SWAP5 **if** the research evidence closes positively. This note does not select or admit such a provider.

## Current canonical authority

Reconciled against:

- `integration/f-ci-canonical@bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`;
- frozen Status-A scientific production baseline `50346642bd565f79134ea17d5462e544b354998c`;
- `docs/status-a/CURRENT_STATUS.md`;
- `docs/status-a/CURRENT_ARCHITECTURE.md`;
- `docs/status-a/TRACEABILITY.md`;
- `docs/science/soil-hydraulic-constitutive-relations.md`.

The frozen admitted default constitutive scope remains the analytical default-MvG, `SWSOPHY=0`, `SWKIMPL=0` route. Tabulated hydraulics and production `SWKIMPL=1` are outside that admitted denominator.

## Existing typed seam

The current solver contract already defines:

`constitutive_hydraulics_provider_t`

with one vector-valued `evaluate` operation that receives pressure head and returns:

- water content;
- conductivity;
- capacity;
- reserved `dconductivity_dhead`.

The admitted default implementation is:

`src/solver/mod_b110_default_mvg_provider.f90`.

The production Task-2 adapter currently constructs and binds that provider explicitly and assigns it to:

`request%evaluation%constitutive`.

Therefore the natural future ownership boundary for a table implementation is **another constitutive provider behind the existing typed seam**, not a change to Richards state ownership, transaction policy or solver acceptance semantics.

## Consequence for the legacy SWSOPHY route

The performance research uses the executable legacy-input table machinery because that is where the historical table semantics can be characterized. That does **not** imply that a production SWAP5 acceleration must restore the old table-file path.

Two future capabilities are distinct and must not be conflated:

1. **Generated acceleration provider**
   - receives the already admitted default-MvG parameter authority;
   - preprocesses an equivalent table representation internally;
   - evaluates theta/C/K through the typed constitutive seam;
   - exists only as an alternative numerical representation of the same admitted constitutive relation.

2. **Generic user-supplied tabulated hydraulics**
   - adds a typed table-data/input contract;
   - admits externally supplied theta(h)/K(h) data and validation rules;
   - necessarily has a broader scientific/input denominator than the generated acceleration provider.

The first can be investigated without reviving the second. This is especially important because current public typed SWAP does not supply the old legacy table state, while public development explicitly treats the old `SWSOPHY=1` route as dormant.

## Required admission slices if research closes positively

A future generated acceleration provider would still require separate authority for at least:

- immutable/preprocessed table state and ownership;
- deterministic table generation from the admitted MvG parameter set;
- exact handling of the qualified wet theta/C branch, dry guards and Ksat plateau;
- provider-selection policy outside solver internals;
- `SWKIMPL=0` scientific equivalence / accepted-fidelity qualification;
- independent performance qualification over a declared execution envelope;
- preservation of analytical MvG as the production reference route;
- failure-closed validation of table monotonicity, finiteness and bounds;
- restart / transaction proof that the provider carries no hidden mutable physical state.

If a later `SWKIMPL=1` table route is pursued, its derivative contract must be admitted separately. Existing F-SI09 deliberately does not admit production `SWKIMPL=1`, and the common provider interface currently returns zero in that reserved derivative slot for the admitted default route.

## Architectural invariants not to change

A table provider must not:

- own committed model state;
- decide accept/retry/rollback;
- change the Richards residual solely to make a benchmark pass;
- hide solver policy inside constitutive evaluation;
- make the analytical provider unavailable as the reference production path;
- turn research performance evidence into a portable/global speed guarantee.

## Current research implication

The raw-head/log(K) experiments should therefore be judged first as a **representation and evaluation strategy**. Only after bounds-safe fidelity, broad constitutive characterization and transfer-envelope performance close should a typed-provider work unit be preregistered.

No production code change is authorized by this note.
