# F-PE-NLGLOB14Z43B result — production/legacy nonlinear-iteration authority audit

Date: 2026-09-30

Status:

`QUALIFIED_Z43B_MAXIT_INPUT_OWNED`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research postimage before result persistence:

`research/f-pe-nlglob14z43b-maxit-authority-audit@58af7cda43b3eeaf78e634232bc6b3be61398da1`

## Q1 — Reference binding

Qualified answer: MAXIT is input/runtime-owned.

`mod_reference_richards_legacy_binding` imports the legacy variable `maxit` and binds:

`request%numerical%max_iterations = maxit`.

There is no hardcoded production value 8 in that binding.

## Q2 — Typed legacy numerical profile

Qualified answer: no universal numeric MAXIT is prescribed.

`legacy_numerics_profile_t` stores a supplied integer `maxit`.

`make_legacy_numerics_profile(..., maxit, ...)` copies the supplied value into the profile.

Validation requires only:

- `maxit > 0`;
- `numbit_crit <= maxit`.

Therefore the typed production/runtime contract preserves MAXIT as an explicit numerical-profile/input quantity.

## Q3 — Historical MAXIT16 experiment

NLGLOB12B did not admit MAXIT16 as production policy.

Its closeout explicitly states:

- the MAXIT=8-only hypothesis was falsified;
- MAXIT16 recovered only 2/6 of that separate frozen set;
- do not apply or further tune a global MAXIT increase;
- no production continuation/MAXIT policy was admitted.

## Consequence for Z43

The value `max_iterations=8` in the Z43 holdout is a frozen research-harness choice, not the production/legacy default authority.

Therefore the Z43 H2/H3 failures at the eight-iteration ceiling cannot be interpreted as proving those materials are outside the production legacy solver envelope.

A revised admission holdout must state its explicit numerical profile and must keep that profile distinct from the production default.

## Qualified claim boundary

Qualified:

- MAXIT is legacy-input/profile-owned;
- reference binding propagates that value directly;
- no repository authority hardcodes production MAXIT=8;
- MAXIT16 is historical research evidence only, not production policy.

Not qualified:

- a universally preferred MAXIT;
- a new global MAXIT default;
- whether a particular higher explicit profile makes all Z43 holdouts reference-solvable.

## Production boundary

Static authority audit only.

No source/default change.
