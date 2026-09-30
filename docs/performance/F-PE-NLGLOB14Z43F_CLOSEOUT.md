# F-PE-NLGLOB14Z43F closeout — canonical admission of non-default moving-interface manager

Date: 2026-09-30

Final status:

`QUALIFIED_Z43F_CANONICAL_ADMISSION_READY`

Qualification authority:

- workflow run `36780284943`;
- admission-smoke job `110108520096`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

## Closure

Z43F closes positively as a canonical-admission-ready workunit.

The live-canonical reconciliation is selective and contains only the qualified production-facing seam.

Admitted capability contract:

- full-column accepted state remains sole physical authority;
- reduced request/state/workspace is reconstructible scratch;
- reduced candidate is rematerialized to full shape before publication;
- exact full fallback and full bypass remain explicit;
- failed reduced attempts do not mutate accepted authority;
- typed active-dimension/fallback diagnostics are available;
- manager selection is explicit opt-in;
- `LEGACY_NUMERICS` remains production default.

## Evidence

Focused canonical admission smoke passes:

- profile/default-off semantics;
- reduced active view/workspace;
- full candidate materialization;
- reduced route selection;
- forced exact fallback;
- explicit bypass;
- rollback/no-leak behavior.

The admission seam is backed by Z43E:

`QUALIFIED_Z43E_PRODUCTION_ADMISSION_CANDIDATE_READY`.

## Scope boundary

This closeout does not claim:

- default activation;
- universal MAXIT16 policy;
- universal manager accuracy envelope;
- whole-MultiSWAP speedup;
- BOFEK-wide portability.

The MAXIT16 candidate profile remains evidence scope only; MAXIT is input/profile-owned.

## Direct successor

Open a focused PR from:

`work/f-pe-nlglob14z43f-canonical-admission-v2`

to:

`integration/f-ci-canonical`.

The PR should be merged only if its head remains unchanged and live canonical remains compatible.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z43F

BRANCH: `work/f-pe-nlglob14z43f-canonical-admission-v2`

RESULT POSTIMAGE BEFORE CLOSEOUT: `5865366cb00a957b872b83d4475313ed407de886`

QUALIFICATION STATUS: `QUALIFIED_Z43F_CANONICAL_ADMISSION_READY`

NEXT SAFE STEP: focused canonical integration PR and merge.

## Production boundary

Moving-interface manager: explicit non-default capability.

`LEGACY_NUMERICS` remains production default.
