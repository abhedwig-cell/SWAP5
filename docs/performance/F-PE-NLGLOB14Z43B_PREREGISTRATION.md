# F-PE-NLGLOB14Z43B preregistration — production/legacy nonlinear-iteration authority audit

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Parent authority:

- Z43A: `QUALIFIED_Z43A_REFERENCE_FAILURE_LOCALIZED`;
- O14/N64 and B12/N64 fail exactly at the frozen Z43 `max_iterations=8` ceiling;
- O05/N32 completes.

## Purpose

Determine whether the value 8 used in the Z43 research holdout is an admitted production/legacy MAXIT authority or merely a research fixture choice.

This is a static repository-authority audit only.

## Frozen evidence sources

Read only:

1. `src/adapter/mod_reference_richards_legacy_binding.f90`;
2. `src/runtime/mod_timestep_numerical_profile.f90`;
3. legacy timestep decision/timecontrol binding;
4. historical NLGLOB12B MAXIT16 result/closeout.

## Frozen questions

Q1. Does the Heritage/reference adapter bind a hardcoded nonlinear iteration ceiling, or does it bind the legacy runtime/input variable `maxit`?

Q2. Does the typed legacy numerical profile prescribe one universal numeric MAXIT, or validate a supplied positive value?

Q3. Did NLGLOB12B admit MAXIT16 as production policy?

## Frozen classifications

### `QUALIFIED_Z43B_MAXIT_INPUT_OWNED`

Require:

- reference binding sources max_iterations from legacy `maxit`;
- legacy numerical profile stores supplied maxit and does not hardcode 8;
- NLGLOB12B explicitly did not admit a global production MAXIT change.

### `Z43B_MAXIT_FIXED_PRODUCTION_AUTHORITY`

A single hardcoded production MAXIT is established.

### `Z43B_AUTHORITY_AMBIGUOUS`

Repository evidence is insufficient or conflicting.

## Consequence

If input-owned, a revised admission holdout must explicitly state its chosen legacy numerical profile; it may not describe research maxit=8 as the production default.

No new ceiling may be inferred solely from Z43A.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z43B

BASELINE: `29107eaea74ca74e49513aaae284a1500f6403d5`

BRANCH: `research/f-pe-nlglob14z43b-maxit-authority-audit`

NEXT SAFE STEP: persist static authority result.

## Production boundary

Documentation/audit only. No runtime change.
