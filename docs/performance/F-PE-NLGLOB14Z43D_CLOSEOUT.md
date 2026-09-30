# F-PE-NLGLOB14Z43D closeout — reference-only heterogeneous holdout replacement selection

Date: 2026-09-30

Final status:

`QUALIFIED_Z43D_REFERENCE_REPLACEMENT_SELECTED`

Qualification authority:

- workflow run `36778334241`;
- job `110101790895`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Closure

Z43D closes positively.

The deterministic reference-only selection chose:

`B01_N64_T49`.

The fixture completes 4,000 full-reference intervals under the unchanged explicit MAXIT16 test profile with clean mass and no retry.

The second frozen candidate is not evaluated because the selection rule stops at the first passing fixture.

## Direct successor

Open:

`F-PE-NLGLOB14Z43E — revised heterogeneous production-admission candidate`.

Freeze exactly:

- O05_N64_T49;
- B12_N64_T49;
- O05_N32_T25;
- B01_N64_T49.

Use the same explicit non-default MAXIT16 test profile.

The successor must replay the default-off configuration seam, then execute the four independent full/adaptive trajectory holdouts and evaluate the frozen physical, operational and performance gates.

No further material replacement or MAXIT tuning is authorized inside that workunit.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z43D

BRANCH: `research/f-pe-nlglob14z43d-reference-holdout-replacement`

RESULT POSTIMAGE BEFORE CLOSEOUT: `3294878adf95146837cf190dddaf0db7a54c7404`

QUALIFICATION STATUS: `QUALIFIED_Z43D_REFERENCE_REPLACEMENT_SELECTED`

NEXT SAFE STEP: Z43E revised admission candidate.

## Production boundary

No production admission yet.

`LEGACY_NUMERICS` remains production default.
