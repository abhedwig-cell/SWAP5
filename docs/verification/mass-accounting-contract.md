# VQ mass-accounting contract

**Status:** Proposed verification contract  
**Workstream:** VQ  
**First use:** VQ-1b -> VQ-1e handoff  
**Production interface changed:** no  
**Primary invariants:** 7, 9, 10, 11, 12, 13, 17, 18, 19, 23, 24, 25, 26, 28, 29, 30

## Purpose

Legacy `.BAL` and `.BLC` output is useful for regression but is rounded to `0.01 cm`. It cannot be the hard mass-conservation oracle for SWAP5.

VQ therefore needs an unrounded, transaction-aware accounting record that can be produced by B2 reference mode and normalized by adapters for later optimized, fallback and coupled execution paths.

This document defines the **verification contract**, not a production API implementation. TX/HY/runtime remain responsible for deciding how the production result types expose equivalent information.

## Accounting domain

Every record applies to one explicitly named component domain over one interval `[t0,t1]`.

For a SWAP soil-plant-atmosphere column, the accounting domain contains every water storage that belongs physically to that SWAP component and is active for the column, including optional storage only when the corresponding physics is active.

Examples include:

- soil-water storage;
- surface ponding where owned by SWAP;
- interception storage where owned by SWAP;
- snow storage where active;
- macropore storage where active;
- any other physically persistent SWAP-owned water store.

Internal transfers between these stores are **not** external mass terms and must not affect the net residual.

A deep-vadose transfer zone is a separate component and therefore has its own accounting record. Runtime/coupler composition must conserve mass when water moves between the SWAP record and the transfer-zone record.

## Canonical sign convention

For VQ normalization:

```text
positive signed amount = water entering the accounting domain
negative signed amount = water leaving the accounting domain
```

Examples:

```text
precipitation entering SWAP       positive
irrigation entering SWAP          positive
runon entering SWAP               positive
runoff leaving SWAP               negative
transpiration leaving SWAP        negative
soil/surface evaporation          negative
drainage leaving SWAP             negative
bottom flux upward into SWAP      positive
bottom flux downward out of SWAP  negative
```

Adapters may translate legacy or implementation-specific signs, but ambiguity is a qualification failure.

## Canonical amount basis

VQ compares water **amounts integrated over the interval**, not instantaneous rates.

The preferred normalized column basis is water-equivalent depth over the column area. A volume basis is also valid if the adapter provides the area/basis metadata needed for exact normalization. A single record may not mix bases or units.

Runtime tile aggregation remains outside SWAP. When several tiles represent one groundwater cell, runtime applies the tile fractions after each component record is internally mass-conservative.

## Minimum logical record

A normalized accounting record contains at least:

```text
schema_version
component_id
column_or_tile_id
interval.t0
interval.t1
amount_unit
area_basis
accounting_scope
storage.start_total
storage.end_total
boundary_terms[]
reported_residual        optional implementation diagnostic
execution_class
accepted_trial_id        when transactional execution is used
qualification_context
```

Each `boundary_terms[]` entry contains at least:

```text
term_id
interface_id
signed_amount
classification
```

`classification` distinguishes externally crossing water from diagnostic/internal transfers. Only external terms enter the hard residual.

Stable term IDs are required. VQ must not infer physical meaning from output-column position.

## Hard residual

VQ recomputes the interval residual independently from the unrounded values:

```text
delta_storage = storage.end_total - storage.start_total
net_external  = sum(signed_amount for all external boundary/source terms)
residual      = delta_storage - net_external
```

A production-reported residual may be supplied as a diagnostic, but VQ does not use it as a substitute for recomputation.

If storage components are exposed individually, VQ may additionally verify that their unrounded sum equals the reported total storage within representation precision.

## Tolerance policy

Mass conservation is not a performance knob.

The gate may use a qualified numerical accounting tolerance, but that tolerance:

- must have a named qualification/provenance record;
- must reflect numerical representation/accounting accuracy, not desired throughput;
- may not silently widen for `balanced`, `throughput`, `relaxed` or `fallback` execution;
- applies to the same physical accounting identity for reference and optimized paths;
- must be recorded with the result used for qualification.

VQ-1 does **not** invent a universal numerical value. Until a tolerance is justified and pinned, a result is `UNQUALIFIED`, not implicitly accepted.

## Transaction semantics

Trial accounting and committed accounting are different scopes.

### Trial result

A trial may return provisional storage and flux integrals for diagnosis and error control. The record is marked `accounting_scope = trial` and is associated with a `trial_id`.

### Commit

Exactly one accepted trial may contribute the committed accounting for an accepted interval. The committed record references the accepted trial and is marked `accounting_scope = committed`.

### Rejection and rollback

A rejected trial may leave numerical warm-start information, but:

- it does not change committed storage;
- its flux/source integrals are not added to committed totals;
- retry history cannot create duplicate committed accounting.

This is the accounting basis for `TX-ROLLBACK-01`, `TX-COMMIT-01` and `TX-ACCOUNT-01`.

## Rerun and warm-start requirements

For `TX-RERUN-01` and `TX-WARM-01`, two advances from the identical committed physical state and identical forcing/boundaries must have physically equivalent accepted accounting within the qualified reference tolerances.

Warm-start differences may alter iterations, retries or wall-clock cost. They may not alter the physical starting storage, duplicate fluxes or change the accepted mass balance outside qualification tolerance.

## Generic-time requirements

The record is defined on `[t0,t1]`; it has no inherent day, month or year semantics.

VQ must support:

- non-midnight `t0`;
- sub-day intervals;
- intervals crossing midnight or calendar boundaries;
- multi-day intervals;
- split versus unsplit interval comparisons where no physical event changes the solution contract.

For a valid split at `tmid`:

```text
storage_end(t0,tmid) = storage_start(tmid,t1)
external(t0,t1)      = external(t0,tmid) + external(tmid,t1)
```

up to the qualified representation/numerical tolerance and documented event semantics.

## Coupling boundary

For direct SWAP-MODFLOW coupling, the bottom-water accounting term is the mass counterpart of the coupling flux.

The coupler may use rates such as `q_SWAP` and `q_MF` during iteration, but final accepted interval accounting must satisfy the shared-interface conservation identity. Head residual tolerance never permits water to disappear.

A coupling record therefore needs enough identity metadata to prove that the SWAP bottom term and the groundwater-side term refer to the same accepted coupling window and interface.

## Optional components and composition

Inactive physics must not invent zero-filled persistent state merely to satisfy the accounting contract. The normalized record may omit inactive storage components and inactive interfaces, while the total storage and external-term set remain complete for the active model topology.

For composed systems, VQ distinguishes:

1. component-local balance;
2. interface pair balance between components;
3. system balance after cancellation of internal component-to-component transfers.

This prevents a locally balanced component from hiding a coupling leak.

## Execution classes and fallback

`normal`, `relaxed`, `fallback` and future execution classes all use the same physical accounting identity.

A fallback result is not accepted merely because it returns a state. It must expose the same minimum unrounded accounting data and pass the hard mass gate. Diagnostic fields should identify the execution class, attempts/retries and fallback route without changing the accounting convention.

## Reference-mode role

B2 reference mode is the first production target required to expose this information. Later performance modes are qualified against the same contract.

B0/B1 legacy adapters may provide lower-resolution comparison records where possible, but a rounded legacy record must be tagged with its resolution and cannot satisfy the B2 hard mass gate.

## Machine-readable normalization

The first VQ-side JSON schema is:

```text
tools/vq/contracts/mass-accounting-record.schema.json
```

This schema is an adapter/verification interchange format. It deliberately does not prescribe the internal Fortran/C/Python object layout of SWAP5.

## Required integration handoff

Before a production API is changed, the owning TX/HY/runtime workstream should map its proposed result objects onto this logical contract and explicitly resolve:

- authoritative start/end storage source;
- authoritative unrounded interval-integrated flux/source terms;
- bottom-interface identity and sign;
- trial versus committed accounting ownership;
- optional-module storage registration;
- tolerance provenance and qualification mode;
- exactly-once commit semantics.

Any missing item is a VQ integration blocker, not a reason to weaken invariant 13.
