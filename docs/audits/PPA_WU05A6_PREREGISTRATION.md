# PPA-WU05-A6 preregistration — source-rate migration

Date: 2026-09-30

Status: PREREGISTERED / RESEARCH_ONLY / PRODUCTION_HELD

Baseline: PPA-WU05-A5@8ff58acaf8049042b662aeb56708ddd9e0fc9321

Canonical source dependency surface reconciled through integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b.

## Purpose

Replace A5 research/precomputed process receipts with typed Fortran generators derived directly from exact B1.11 source, without changing the qualified A1-A5 ownership contracts.

## Fixed architecture

A6 may change process-rate implementation only.

It may not change:

- seven-field continuation-state surface;
- outer coupling-controller ownership;
- restart payload semantics;
- top/surface ownership;
- internal matrix/macropore cancellation;
- rapid-drain single external ownership;
- transaction/accept/retry semantics.

## Migration phases

### A6-R1 unsaturated absorption

Migrate exact source-bound unsaturated matrix/macropore absorption for the qualified SWABS=1 path first, including event memory and source caps.

### A6-R2 saturated exchange

Migrate SATFLOW source-rate generation and its sign/geometry contracts.

### A6-R3 inter-domain saturated exchange

Migrate internal catchment-domain saturated exchange and prove it remains internal.

### A6-R4 rapid drainage

Replace precomputed rapid-drain receipts with typed multi-compartment source-rate generation.

### A6-R5 top limitation/redistribution

Generate accepted vertical/lateral top receipts from source-bound capacity logic rather than precomputed A5 inputs.

### A6-R6 accepted vertical flux reconstruction

Compose accepted local vertical macropore fluxes using the A3 locally conservative reconstruction policy.

## Qualification policy

Each rate generator must be qualified first against exact/local source oracles before being connected to the full typed A5 compositor.

Broad parameter sweeps run locally. GitHub Actions is used only for focused persisted qualification.

## Hard holds

- no production activation;
- no canonical admission;
- no new state fields without explicit falsification of A2 sufficiency;
- no weakening of mass conservation;
- no preservation of undefined icgwl behaviour;
- no calibration/tuning to legacy outputs;
- no fully implicit Newton coupling unless new evidence requires it.

## Exit

A6 may close as QUALIFIED_SOURCE_RATE_MIGRATION_COMPLETE_SINGLE_COLUMN when all R1-R6 generators are typed, source-bound, composed, and replay-qualified.