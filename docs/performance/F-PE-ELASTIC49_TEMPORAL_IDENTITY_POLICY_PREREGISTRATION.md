# F-PE-ELASTIC49 — Reference temporal identity-policy attribution preregistration

Date: 2026-09-29

Status: PREREGISTERED_OBSERVATION_ONLY

Parent:
`F-PE-ELASTIC48 — QUALIFIED_ELAS_SOLVER_TO_TEMPORAL_LIMITER_TRANSITION`

Parent postimage:
`research/f-pe-elastic48-failure-attribution@c8d6c4a998164924adf6a5cd16a0cfa144a9e641`

## Question

What does the active `TX_TEMPORAL_EXTERNAL_FULL_HALF` gate actually measure on
the admitted serialized Reference route?

## Scope

Audit the current canonical source only.

Authority:
- `src/runtime/mod_fmr_serialized_reference_backend.f90`;
- `src/transaction/mod_transaction_reference.f90`.

No runtime or solver modification is allowed.

## Hypothesis

H1. The Reference temporal metric is identity-only rather than a continuous
scaled error: exact full/two-half state equality returns zero, any mismatch
returns `huge()`.

H2. The transaction core then applies
`temporal_ok = terr <= temporal_tolerance`.

If H1 and H2 both hold, the configured `1e-6` tolerance is not functioning as
a conventional physical error tolerance on this route.

## Required checks

A1. Pressure head, water content, ponding depth and groundwater level are
compared by exact equality in the Reference temporal metric.

A2. Equal states return exactly `0.0_real64`.

A3. Any mismatch retains `huge(0.0_real64)`.

A4. Transaction acceptance compares this value against
`policy%temporal_tolerance`.

A5. Temporal rejection precedes commit and causes retry/rollback.

A6. No `src/**` change.

## Non-claims

This workunit does not claim:
- the current policy is scientifically invalid in every use case;
- a particular replacement norm or tolerance;
- that no sufficiently small timestep can ever become bit-identical;
- any production change.

## Decision

If H1-H2 qualify, route the next workunit to measuring actual full-versus-half
state discrepancies and designing a physically scaled temporal metric before
any policy replacement is proposed.
