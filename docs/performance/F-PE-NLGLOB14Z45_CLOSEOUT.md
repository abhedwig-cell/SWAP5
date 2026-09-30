# F-PE-NLGLOB14Z45 closeout — narrow admission scope and eligibility contract

Date: 2026-09-30

Final status:

`Z45_SCOPE_NOT_BOUNDED`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Closure

Z45 closes negatively on admission-layer scope enforcement, not on moving-interface physics.

The intended narrow scope is supported by existing evidence, but the current manager seam does not itself enforce all excluded process classes.

Geometry-only eligibility is insufficient for production admission.

## Direct successor

Open:

`F-PE-NLGLOB14Z46 — explicit moving-interface eligibility guard and non-default admission seam`.

Z46 should remain focused:

- add a typed fail-closed eligibility guard;
- cover qbot/bottom route, top route, macropores, source/sink scope, interface sensitivity and tail geometry;
- verify every excluded condition gives explicit full bypass;
- retain explicit full fallback after a reduced solve failure;
- retain default-off manager configuration;
- use compiled smoke/contract tests only.

No long trajectory campaign is required.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z45

BRANCH: `research/f-pe-nlglob14z45-admission-scope-eligibility`

RESULT POSTIMAGE BEFORE CLOSEOUT: `2347a01247e2fce8c3f8e09fac67797bab797c2b`

QUALIFICATION STATUS: `Z45_SCOPE_NOT_BOUNDED`

NEXT SAFE STEP: Z46 explicit eligibility guard.

## Production boundary

No production admission.

`LEGACY_NUMERICS` remains production default.
