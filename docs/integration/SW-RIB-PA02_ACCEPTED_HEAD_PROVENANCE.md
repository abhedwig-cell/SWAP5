# SW-RIB-PA02 accepted-head provenance design

**Date:** 2026-09-23  
**Status:** preregistered design only, no production mutation  
**Parent candidate:** `SW-RIB-PA01@0a33c6d96e1f8f76c1794e3ac690e6b641de369a`

PA01 deliberately establishes a narrow SWAP-side boundary: an already accepted external surface-water head can drive the signed drainage/infiltration process without introducing a second SWAP surface-water state. That is the correct low-level boundary, but it is not yet an end-to-end coupling authority because a plain numeric head carries no accepted-state provenance.

PA02 closes exactly that gap. It does not change the physical ownership split and it does not introduce a second transaction system.

## Receipt

The coupler owns a typed accepted surface-water head receipt containing:

```text
coupler lineage
Ribasim origin id
Ribasim accepted revision
accepted boundary time
coupling interval [t0,t1]
surface-water mapping id
ordered Ribasim water-body/node ids
ordered accepted head vector
unit identity
Ribasim release identity
```

The receipt is provenance metadata. Ribasim remains the owner of the physical surface-water state.

## Causal boundary

```text
accepted Ribasim state
    -> coupler constructs immutable accepted-head receipt
    -> validate origin/revision/time/mapping
    -> extract ordered head vector
    -> PA01 binds call-local external controls
    -> SWAP evaluates signed exchange trial
    -> coupled feasibility / recomposition
    -> joint acceptance
```

A trial Ribasim state may never directly manufacture a receipt that is acceptable as production forcing.

## Reuse of existing authority

PA02 follows the RM10 pattern: provenance is part of the type contract rather than a set of detached scalars. RM10 itself remains irrigation-specific and is not reused as a surface-water-state object.

Time ownership remains RM11/RM12. PA02 verifies that its receipt belongs to the accepted coupling boundary; it does not calculate the next allocation boundary itself.

## Fail-closed cases

The full coupled route must reject before SWAP physical solve when any of these is true:

- receipt not marked/constructed from accepted origin;
- stale or future Ribasim revision;
- wrong Ribasim origin id;
- wrong coupling interval or accepted-state time;
- mapping identity mismatch;
- node identity/order mismatch;
- head vector shape mismatch;
- non-finite head;
- release provenance mismatch;
- raw detached head supplied through the end-to-end orchestration route.

## Transaction semantics

The receipt is immutable over a trial. Rejection or timestep retry cannot advance its revision, alter its head vector or replace its origin. A newly accepted Ribasim state creates a new receipt/revision.

The same accepted origins, mapping and interval must reproduce the same receipt and the same PA01 head vector.

## Admission order

1. Finish PA01 independent qualification on the frozen candidate.
2. Freeze PA02 candidate source surface prospectively.
3. Implement the smallest typed receipt/binding layer, preferably without modifying PA01 physical source.
4. Qualify accepted/stale/restart/replay cases.
5. Independently qualify exact candidate blobs.
6. Only then compose with the real Ribasim state publication path and pursue canonical admission.

PA02 therefore strengthens provenance without reopening the closed SW-RIB-SWM01 physics research.


## Dependency admission boundary

RM10, RM11 and RM12 are qualified research authorities on `work/ribasim-management-coupling-closeout`, but their production modules are not present on the current canonical parent of PA01. PA02 must therefore not import those work-branch modules directly.

The semantics are reusable, the source dependency is not yet admitted.

Before PA02 production implementation, choose exactly one route:

1. depend on an independently admitted RM10/RM11 provenance/scheduler component after it reaches canonical; or
2. preregister and admit one generic accepted-external-state provenance component that both management realization and accepted surface-water heads can use.

Creating a second PA02-specific lineage/revision system by copying RM10 behavior is explicitly forbidden. That would solve the local type problem while recreating ambiguous provenance ownership at the architecture level.
