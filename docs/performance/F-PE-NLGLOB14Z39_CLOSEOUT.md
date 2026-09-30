# F-PE-NLGLOB14Z39 closeout — compiled Richards solve-service manager-overhead amortization

Date: 2026-09-30

Final status:

`QUALIFIED_Z39_MANAGER_OVERHEAD_AMORTIZED`

Qualification authority:

- workflow run `36772207395`;
- job `110081142691`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Closure

Z39 closes positively.

The remaining Z38 persistent-manager fixed overhead is below 0.3% of actual compiled Heritage Richards solve-service time in all four frozen materials.

Further manager-seam micro-optimization is therefore not justified before binding the real reduced nonlinear solve.

## Direct successor

Open:

`F-PE-NLGLOB14Z40 — real reduced Heritage solve-service binding and focused A/B timing`.

Z40 must:

- keep full accepted state authoritative;
- bind active n=12/13 reduced solving to the Heritage/reference service;
- reconstruct a full candidate through the qualified manager seam;
- preserve explicit fallback/bypass and rollback semantics;
- compare physical outputs to the full service;
- measure compiled full/reduced solve-service timing on a small fixed case set.

No broad trajectory or BOFEK-wide campaign is needed yet.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z39

BRANCH: `research/f-pe-nlglob14z39-richards-amortization`

RESULT POSTIMAGE BEFORE CLOSEOUT: `6568ed82dfc1acb0c2401f3a0c322c4a75e918ba`

QUALIFICATION STATUS: `QUALIFIED_Z39_MANAGER_OVERHEAD_AMORTIZED`

NEXT SAFE STEP: Z40 real reduced Heritage solve-service binding and focused A/B timing.

## Production boundary

No production default change.

`LEGACY_NUMERICS` remains production default.
