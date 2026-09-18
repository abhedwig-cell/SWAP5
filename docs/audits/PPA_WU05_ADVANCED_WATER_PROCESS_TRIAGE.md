# PPA-WU05 Advanced water-process triage

Date: 2026-09-18

Status: `TRIAGE_AUTHORITY_FREEZE_PENDING_QUALIFICATION`

## Purpose

PPA-WU05 orders three advanced water-process families without migrating physics:

- macropore flow;
- frost-related hydraulic effects;
- advanced root-water-uptake stress and alternative uptake routes.

The workunit is deliberately review-only. It may freeze source authority, ownership questions,
dependency order and acceptance criteria, but it may not add production process code.

## Authority

The corrected reference is SWAP 4.3.1 B1.11 with member-manifest SHA-256

`24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`.

Relevant exact source identities are pinned in
`integration/audits/PPA_WU05_DEPENDENCY_GRAPH.json`.

Two corrected-reference differences matter directly:

- SWAP-001 repairs a macropore array-shape defect without changing macropore physics;
- SWAP-007 repairs an oxygen-stress Newton quotient overflow without changing the ordinary-path oxygen formulation.

Current SWAP5 authority is intentionally narrower:

- F-CI31 admits drought-only macro-Feddes root uptake;
- F-CI37 admits a restricted parallel form of that root sink;
- F-CI43/F-CI45 admit sensible soil temperature but explicitly exclude frost, latent heat and phase change;
- the serialized Reference runtime fails closed on active macropore and frost profiles.

Presence in B1.11 is therefore reference authority, not SWAP5 production admission.

## Repository-authority correction during review

The initial dependency graph referred to historical labels `S12o`, `A23au`, `S12r`,
F-PM05/F-PM07 readiness and F-PE15/F-PE16 evidence. Those labels were not recoverable as
current canonical files or searchable repository commits during WU05 reconciliation.

They are not used as decision authority.

Consequently, WU05 does not freeze:

- specific macropore committed-state field names;
- specific macropore scratch arrays;
- hidden oxygen continuation variables;
- a claim that legacy frost fields are purely recomputable.

Those questions move into exact source-trace workunits.

## Family 1: macropore

### What is known

B1.11 contains a corrected macropore source lineage. SWAP-001 is mandatory reference authority
and must not be undone for compatibility.

The production gap is large: current SWAP5 has no typed macropore state, no macropore runtime
route and no macropore restart/parallel admission.

### What must be recovered before implementation

The next source-bound review must classify every relevant mutable value as one of:

- committed physical/history state;
- trial candidate state;
- accepted process result;
- internal mass transfer;
- external mass transfer;
- recomputable worker scratch;
- reporting-only state.

It must also identify every mutation that can occur before hydraulic acceptance.

### Acceptance architecture

A future implementation may proceed only after it can prove:

1. complete rollback of every trial-mutable persistent field;
2. exact restart of every non-reconstructible persistent field;
3. exactly-once external mass accounting;
4. no double booking of internal matrix/macropore transfers;
5. worker-local scratch independent of physical rollback;
6. disjoint per-column state under MultiSWAP;
7. explicit fail-closed handling of macropore-specific root uptake until separately admitted.

## Family 2: advanced root stress

The existing root-water-uptake owner remains the only admitted root-water mass sink.
Advanced stress diagnostics or reduction factors may not become a second sink owner.

The family must be decomposed. It includes at least:

- oxygen stress;
- salinity stress;
- frost-related root stress;
- compensated uptake;
- MICRO/Jong-van-Lier uptake;
- macropore-related uptake;
- SWKIMPL=1 dynamic root-sink reevaluation.

These are not one migration slice.

### Oxygen

Oxygen is the strongest reference-bound advanced-root candidate because B1.11 pins the corrected
`oxygenstress.f90` through SWAP-007. That does not yet establish its minimal typed state or prove
that it is merely an algebraic modifier around the current Feddes owner.

A later source review must recover:

- all required external views;
- continuation state, if any;
- root/crop timing semantics;
- the exact relation to the existing nodewise root sink;
- transaction/retry behavior;
- preservation of the SWAP-007 representability guard.

### Other advanced root routes

Salinity remains blocked on a production-authoritative solute/osmotic state owner.
Frost stress remains blocked on a frost authority.
Macropore-related root uptake remains blocked on a macropore owner.
MICRO/Jong-van-Lier requires its own source/state authority.
SWKIMPL=1 is numerical coupling policy and requires a separate nonlinear/sensitivity workunit.

## Family 3: frost

Current sensible-temperature production is not frost production.

The exact B1.11 identities of `frozencond.f90` and `temperature.f90` establish provenance only.
A later source review must recover whether legacy frost fields are persistent or recomputable and
how frost affects:

- hydraulic conductivity;
- drainage;
- bottom-boundary behavior;
- root stress;
- time ordering relative to the accepted temperature profile.

WU05 explicitly does not interpret the legacy frost route as authority for a new thermodynamic
ice-content or latent-heat model. Any new phase-change formulation is model development and needs
separate scientific authority.

## Dependency order

The frozen dependency graph gives the following bounded order.

### First target: PPA-WU05-A

**Macropore source/state/mass/transaction authority.**

This is not a production migration. It is the first high-use prerequisite because macropore
support is important for structured soils and blocks later restart, parallel and
macropore-related uptake work. The exact corrected source identity is already pinned, while the
remaining uncertainty is chiefly ownership and transaction topology.

Exit for WU05-A:

- exact B1.11 macropore/macrorate source trace;
- complete state/scratch/result classification;
- mass-transfer graph;
- restart schema;
- rollback contract;
- bounded candidate slices for later production work.

### Second target: PPA-WU05-C

Oxygen-stress source/state/owner decomposition.

### Third target: PPA-WU05-B

Legacy frost hydraulic-boundary source trace.

Compensation, salinity, frost-root stress, MICRO/Jong-van-Lier, macropore-root uptake,
SWKIMPL=1 and any new phase-change model remain later or blocked targets as recorded in the
machine-readable graph.

## Safe parallelism

The following review work may proceed in parallel because ownership is disjoint:

- macropore source/state trace and oxygen source/state review;
- frost source trace and compensated-uptake source trace;
- future solute-owner work and macropore authority work.

Implementation must serialize where one owner is prerequisite to another, especially macropore
before macropore-related uptake, frost before frost-root stress, and solute ownership before
salinity stress.

## Qualification requirements for WU05 itself

WU05 closes only when an independent repository gate confirms:

- the corrected B1.11 hashes and SWAP-001/SWAP-007 authority are pinned;
- current root and sensible-temperature nonclaim boundaries are preserved;
- unsupported historical labels do not appear as decision authority;
- no `src/` or `reference/` production/reference mutation exists;
- macropore-first means review authority, not production admission;
- narrative and machine-readable graph agree.

## Verdict target

`ADVANCED_WATER_TRIAGE_AUTHORITY_FROZEN_FIRST_TARGET_MACROPORE_SOURCE_STATE_MASS_TRANSACTION_REVIEW`
