# F-PE-NLGLOB14Z47 closeout — narrow non-default canonical admission candidate

Date: 2026-10-01

Final status:

`QUALIFIED_Z47_NARROW_ADMISSION_CANDIDATE_READY`

Qualification authority:

- workflow run `36818047308`;
- smoke job `110227325151`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@0b231d1669cf38d069f14c6d2f0f07cd3bb1c5b1`

## Closure

Z47 closes positively.

The current canonical moving-interface manager seam can be tightened with the Z46 fail-closed process eligibility guard without changing the numerical-profile default seam or importing research history.

The focused admission smoke passes the complete bounded exclusion matrix and preserves:

- explicit reduced eligibility;
- explicit full bypass outside scope;
- explicit full fallback after reduced failure;
- full-column accepted-state authority;
- unchanged legacy/default behavior.

## Canonical payload

Admission candidate payload is limited to:

- eligibility additions in `src/runtime/mod_moving_interface_manager.f90`;
- focused eligibility smoke/runner/workflow;
- Z47 admission documentation.

The canonical numerical-profile file is intentionally unchanged.

## Direct successor

Open a focused PR from:

`work/f-pe-nlglob14z47-narrow-admission-candidate`

to:

`integration/f-ci-canonical`.

Merge only if:

- branch head remains unchanged;
- live canonical remains compatible;
- required repository checks are green.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z47

BRANCH: `work/f-pe-nlglob14z47-narrow-admission-candidate`

RESULT POSTIMAGE BEFORE CLOSEOUT: `3cfea0d0cde80f33a9fa9ccfb952e5c064e116a1`

QUALIFICATION STATUS: `QUALIFIED_Z47_NARROW_ADMISSION_CANDIDATE_READY`

NEXT SAFE STEP: focused canonical integration PR and merge.

## Production boundary

Explicit non-default moving-interface manager capability only.

`LEGACY_NUMERICS` remains production default.
