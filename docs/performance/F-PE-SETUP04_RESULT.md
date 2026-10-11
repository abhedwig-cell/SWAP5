# F-PE-SETUP04 result — scalable bootstrap production admission

Date: 2026-09-27

Status: `PRODUCTION_ADMISSION_QUALIFIED`

PR:
`#681 — F-PE-SETUP04: production admit scalable bootstrap identity binding`

Measured head:
`39b0566d101007fb5a07f1090162e83f356751d5`

Canonical base:
`integration/f-ci-canonical@4ee57d17a3793a58c792d5de9cdd0a38f9e7918a`

## Production change

The production candidate:
- replaces cumulative O(N^2) tile-ID and ledger-ID prefix scans with deterministic global sort-based uniqueness validation;
- adds a dedicated `bind_prevalidated_fresh` registry entry point;
- uses that path only from the production bootstrap after global tile-ID uniqueness has passed;
- preserves the ordinary generic registry bind API and behavior for all other callers;
- preserves fresh sequential handle/slot identity.

No physical, solver, coupling or transaction semantics change.

## Bounded source/caller surface

P0 source-boundary gate: PASS.

The dedicated fast bind entry point is referenced only by:
`src/runtime/mod_fmr_production_application_bootstrap.f90`.

No other production caller is authorized to bypass generic duplicate/slot validation.

## Semantic preservation

PASS:
- generic participant-registry qualification;
- PPA-WU01 production application bootstrap;
- duplicate tile-ID and ledger-ID fail-closed guards;
- production-shaped q/tangent identity;
- TEMPORAL08 production admission;
- MULTI04 application-context identity;
- MULTI04 production scaling;
- ZERO-WASTE01 poison workspace;
- F-CI110 reconstructed performance admission.

MULTI04 current-head scaling remains:
- 2 workers: 1.961024x;
- 4 workers: 2.608551x;
- q/tangent checksum identity exact.

## Paired canonical/candidate performance

### N=1,000

- canonical app initialize: 0.005701973 s;
- candidate: 0.003941166 s;
- speedup: 1.446773x;
- frozen no-regression gate: PASS.

### N=10,000

- canonical: 0.142992696 s;
- candidate: 0.022271320 s;
- speedup: 6.420486x;
- frozen >=3x gate: PASS.

### N=40,000

- canonical: 3.586634106 s;
- candidate: 0.112035141 s;
- speedup: 32.013474x;
- frozen >=8x gate: PASS.

This removes the measured large-N bootstrap pathology while preserving production-shaped physical results.

## Historical workflow failures outside scope

The full PR workflow surface also contains a number of historical/frozen jobs that are red on the moving modern branch.

These include older PUB, F-CI73/F-GC25, PPA-WU02/WU03/WU04 and older independent qualification surfaces.

They are not used as positive evidence for SETUP04 and are not reclassified as passing.

The bounded SETUP04 source delta is confined to:
- `src/runtime/mod_fmr_groundwater_participant_registry.f90`;
- `src/runtime/mod_fmr_production_application_bootstrap.f90`.

Current relevant production/performance authorities listed above are green.

The moving canonical qualification is awaited separately on the final documentation head before merge.

## Decision

The scalable bootstrap mechanism is production-qualified subject to final current-canonical qualification on the documentation closeout head.

Do not relax or reinterpret any unrelated historical red workflow as part of this admission.
