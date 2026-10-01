# PPA-WU05-PERCH21 result — current-canonical perched production reconstruction

Date: 2026-10-01

Status: `QUALIFICATION_PENDING`

Canonical reconstruction baseline:
`integration/f-ci-canonical@59048478a7ddff4df90beb81a1f9c4ee99b0f5d0`.

Current reconstructed branch:
`work/ppa-wu05-perch21-current-canonical`.

## Reconstruction

PERCH21 was reconstructed from the current canonical head rather than merging the
historical pre-canonical perched ancestry.

The previously qualified PERCH21 production surface was carried selectively. The only
shared production path also changed since the earlier PERCH21 canonical base was:

- `src/runtime/mod_fmr_serialized_reference_backend.f90`.

Its current-canonical RFM additions and the qualified perched continuation/runtime changes
were three-way reconciled. The RFM optional-state runner was reconciled likewise.

The subsequent canonical delta from `f477f3fb...` to `59048478...` introduced A26J
initial-storage geometry without touching the perched production surface, so the branch was
rebased exactly and A26J preservation was added.

## Qualification gate

Current qualification run:

`36895719940`

Qualified code postimage under test:

`dbeb180544269e963fa2a73ebff4732b166e83d4`.

The gate requires:

- PERCH20 restart lifecycle;
- PERCH20 transaction continuation;
- PERCH19 source-faithful Andelst active retry;
- admitted A10 rapid-drain preservation;
- canonical RFM optional-state preservation;
- RFM A24 real-Richards split;
- RFM A24 matrix source provider;
- RFM A25 node sorptivity;
- RFM A25 runtime orchestrator;
- RFM A26H wall history;
- RFM A26J initial-storage geometry.

No production-admission conclusion is recorded until this exact gate completes green.

## Intended decision if green

`QUALIFIED_PERCHED_PRODUCTION_ADMISSION_CANDIDATE`.

Canonical admission remains a separate PR/merge/post-merge-preservation step.
