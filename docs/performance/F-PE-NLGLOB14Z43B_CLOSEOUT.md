# F-PE-NLGLOB14Z43B closeout — production/legacy nonlinear-iteration authority audit

Date: 2026-09-30

Final status:

`QUALIFIED_Z43B_MAXIT_INPUT_OWNED`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Closure

Z43B closes positively.

Production/legacy MAXIT is not a hardcoded repository constant.

The reference adapter propagates the legacy/runtime input value directly, and the typed legacy profile accepts an explicit positive MAXIT subject to its existing consistency checks.

The research value 8 used in Z43 is therefore not the production/default authority.

The historical MAXIT16 experiment remains research-only and did not admit a global production MAXIT change.

## Direct successor

Open:

`F-PE-NLGLOB14Z43C — revised explicit-profile admission holdout`.

The successor should freeze one explicit non-default legacy numerical test profile before execution.

A bounded candidate is MAXIT=16 because:

- it is an already-used historical research value;
- it is not a production default;
- it doubles the failed Z43 ceiling without introducing an adaptive/tuned iteration policy.

The successor must first require all full-reference holdouts to be solvable under the frozen profile before using them for adaptive performance admission.

If the reference preflight fails, stop the admission attempt rather than tuning another ceiling inside the same workunit.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z43B

BRANCH: `research/f-pe-nlglob14z43b-maxit-authority-audit`

RESULT POSTIMAGE BEFORE CLOSEOUT: `86f3c4f59a9c6472147aacf7e6f607555291bae9`

QUALIFICATION STATUS: `QUALIFIED_Z43B_MAXIT_INPUT_OWNED`

NEXT SAFE STEP: one explicitly frozen revised admission profile with reference preflight.

## Production boundary

No production default change.
