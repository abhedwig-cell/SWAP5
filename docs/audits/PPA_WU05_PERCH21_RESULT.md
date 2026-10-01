# PPA-WU05-PERCH21 result — current-canonical perched production reconstruction

Date: 2026-10-01

Status: `QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE`

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

Qualified current-canonical reconstruction run:

`36906093634`

Qualified code postimage:

`708af277cecdcb40432256d55be15139d9e507e7`.

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

Run `36906093634` completed SUCCESS. All declared PERCH20, PERCH19, A10 and current RFM preservation steps passed on the same postimage.

Decision:

`QUALIFIED_PERCHED_PRODUCTION_ADMISSION_CANDIDATE`.

The later canonical delta through `42bb867e1da993fe2127d23fe3e449e5244f7407` adds only the independently admitted RFM A26K hydrostatic-head files and does not touch the PERCH21 dependency surface. Its evidence is therefore inherited under the repository's unchanged-dependency rule. Canonical admission remains a separate PR/merge/post-merge-preservation step.

## Canonical admission and closeout

Canonical admission completed through PR #963 and PR #964.

Post-merge preservation run `36907018287` completed SUCCESS on canonical head
`8bb835a065248aad06b18a3b563234b20033ba0d`.

The post-merge gate passed PERCH20 restart and transaction continuation, PERCH19 Andelst active retry,
A10 rapid drainage, and the canonical RFM preservation surface including A26K hydrostatic IC head.

Final decision:

`CANONICALLY_ADMITTED_PERCHED_INNER_RICHARDS_PRODUCTION_ROUTE`.

PERCH21 is closed.
