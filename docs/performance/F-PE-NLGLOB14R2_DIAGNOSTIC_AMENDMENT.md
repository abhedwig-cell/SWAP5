# F-PE-NLGLOB14R2 diagnostic amendment — nominal retry phase identity

Date: 2026-09-29

Status: `DIAGNOSTIC_AMENDMENT_AFTER_FIRST_EXPOSURE`

First exposed run:

- run `36592793921`;
- job `109489919762`;
- workflow conclusion: SUCCESS.

## Observed instrumentation defect

The frozen R2 execution did reproduce the nominal second-interval retry and entered the preregistered rollback/retry branch in all 12 fixtures.

However, the Python classifier identified the nominal retry through the generic inherited `F_PE_NLGLOB14R1_FAIL` stream and required exactly one such record.

The same inherited diagnostic also fires again when the first half-step retry attempt fails on the same logical loop step. Therefore record multiplicity does not identify the nominal phase.

This caused the first exposed aggregate label `NLGLOB14R2_RETRY_TRANSACTION_INCONSISTENT` even though:

- the explicit R2 rollback marker exists in every fixture;
- rollback diagnostics are exact;
- retry scale is exactly 0.5;
- every first half-step is explicitly logged and requests retry again;
- accepted physical mass before the rejected attempts remains clean.

## Amendment

Add one phase-specific observational marker immediately before the already-existing R2 rollback:

`F_PE_NLGLOB14R2_NOMINAL_RETRY`

It records only:

- step;
- retry=true;
- nominal dt;
- terminal reason.

The classifier will use this marker, rather than generic R1 diagnostic multiplicity, to establish the already-frozen requirement that the nominal second attempt reproduced retry-advised semantics.

## Frozen rules unchanged

Do not change:

- retry scale 0.5;
- one-retry limit;
- two-half nominal-window construction;
- rollback gate;
- half-step classifications;
- mass gates;
- aggregate classifications.

In particular, if the first half-step again reports retry-advised in all 12 cases, the preregistered result is:

`NLGLOB14R2_SINGLE_RETRY_INSUFFICIENT`.

No numerical result is reinterpreted by changing a threshold or policy.
