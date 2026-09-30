# F-PE-ELASTIC65 — mode-7 C-SAFE certificate binding preregistration

Date: 2026-09-30

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Canonical baseline:
`integration/f-ci-canonical@6d7687900551e3bcd2497972acf002423ed9171c`

Production authorities:
- F-PE-ELASTIC59 — mode-7 typed mass publication admitted;
- F-PE-ELASTIC60 — mode-7/swKimpl=0 Richards defect indicator admitted;
- F-PE-ELASTIC61 — mode-7 conservative head-error envelope admitted.

Research authority:
- F-PE-ELASTIC56 — local Binf nonmonotonicity, global envelope preserved;
- F-PE-ELASTIC57 — nonmonotonicity-robust refine-and-recheck controller pattern.

## Purpose

Bind the admitted mode-7 defect indicator and ELASTIC61 head-error envelope into
the already existing `TX_TEMPORAL_MODEL_CERTIFICATE` transaction path.

No new retry algorithm is introduced.

The existing transaction path already:
- evaluates each attempted dt independently;
- retries with `retry_scale`;
- never assumes temporal-indicator monotonicity;
- requires hard mass acceptance before temporal acceptance;
- fails closed when the model certificate is unavailable.

## Existing generic budget carrier

`canonical_numerical_config_t%model_temporal_indicator_budget` is deliberately
model-owned and unitless at canonical runtime level.

Existing modes 2 and 5 use it as a native Binf budget.

ELASTIC65 must preserve those semantics exactly.

For **bottom mode 7 only**, within the admitted swkimpl=0 indicator envelope,
the selected serialized Reference model interprets this model-owned scalar as an
explicit caller-owned physical pressure-head budget in cm and composes:

`Binf`
-> ELASTIC61 `estimated_head_error = alpha * Binf`
-> `normalized_error = estimated_head_error / head_budget`
-> dimensionless model certificate.

No default budget is introduced.

## Production delta

Expected production source change:
- `src/runtime/mod_fmr_serialized_reference_backend.f90` only.

The module may import the admitted ELASTIC61 stateless adapter.

No transaction, solver, HeadCalc, canonical-config, constitutive, mass, retry,
or boundary source is changed.

## Mode-specific semantics

For bottom modes 2 and 5:
- preserve existing native normalization exactly:
  `temporal_indicator = Binf / model_temporal_indicator_budget`.

For bottom mode 7:
- call `assess_fmr_mode7_temporal_head_envelope(Binf, budget, assessment)`;
- certificate is available only if the assessment is complete/valid;
- publish `assessment%normalized_error` as the model certificate;
- preserve raw Binf in diagnostics;
- preserve explicit budget supplied/valid diagnostics.

For any still-unowned bottom mode:
- preserve existing fail-closed indicator behavior.

## Qualification

A1. Qualified mode-7 case with seeded temporal history and explicit positive
physical head budget returns a model certificate equal to the ELASTIC61
assessment exactly.

A2. Mode-7 transaction with
`TX_TEMPORAL_MODEL_CERTIFICATE`
accepts the first attempted dt whose newly evaluated normalized certificate is
<=1, without assuming monotonicity.

A3. Mode-7 missing/invalid budget remains fail closed and increments the
existing certificate-unavailable/temporal-rejection path.

A4. Hard mass acceptance remains independently required; temporal acceptance
cannot override a mass failure.

A5. Mode-2 existing model-certificate normalization is bit-identical before and
after the patch.

A6. Mode-5 existing live-production temporal-certificate path is preserved.

A7. Mode-7 swkimpl=1 remains fail closed through the admitted indicator envelope.

A8. O0/O2 semantic identity.

A9. Exact production source scope:
`src/runtime/mod_fmr_serialized_reference_backend.f90` only.

## Admission boundary

A green ELASTIC65 admits only:

`mode7 + swkimpl=0 + temporal-history state + explicit caller model budget`
-> ELASTIC61-normalized model certificate
-> existing transaction refine/recheck path.

It does not admit:
- a default physical head budget;
- a complete F-CI14 eight-metric profile;
- default-on temporal control;
- swkimpl=1;
- any mass tolerance relaxation;
- any change to mode-2/mode-5 budget semantics.
