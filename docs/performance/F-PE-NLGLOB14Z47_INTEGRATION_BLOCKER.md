# F-PE-NLGLOB14Z47 integration blocker — unrelated canonical CI debt

Date: 2026-10-01

Status:

`Z47_CANONICAL_INTEGRATION_BLOCKED_BY_UNRELATED_CI`

Z47 scientific/admission status remains:

`QUALIFIED_Z47_NARROW_ADMISSION_CANDIDATE_READY`.

## PR authority

PR #921:

`Admit fail-closed eligibility guard for moving-interface manager`

Head:

`work/f-pe-nlglob14z47-narrow-admission-candidate@422bd7353672c829eb37794689fddfc88b2d286f`

Base:

`integration/f-ci-canonical@0b231d1669cf38d069f14c6d2f0f07cd3bb1c5b1`

GitHub reports the PR as mergeable, but merge state is `unstable` because repository-wide checks are red.

## Z47-owned verification

Focused Z47 admission smoke:

- workflow run `36818047308`;
- job `110227325151`;
- conclusion SUCCESS.

The selective PR diff is confined to:

- Z47 workflow/docs/tests;
- the eligibility additions in `src/runtime/mod_moving_interface_manager.f90`.

The canonical numerical-profile file is unchanged.

## Unrelated failing check 1 — ZERO-WASTE poisoned workspace

Workflow run:

`36818146491`

Failure:

`src/runtime/mod_fmr_serialized_reference_backend.f90`

cannot open:

`mod_fmr_mode7_temporal_head_envelope.mod`.

This FMR compile dependency is outside the Z47 diff and unrelated to the moving-interface eligibility guard.

## Unrelated failing check 2 — F-CI current-canonical preservation

Workflow run:

`36818146637`

Failing job:

`current-restricted-canonical-preservation`.

Reported drift:

`src/runtime/mod_a23bu_worker_execution_context.f90`

against historical baseline:

`a0fd7822ea5d7ecc0bb409fd9f0439c8fd1dca6a`.

The worker-context file is outside the Z47 diff.

Its blob already differs between the historical baseline and the current canonical:

- historical blob: `39eb8181cc3124251efc482fa779ca9c71e85337`;
- current canonical blob: `7861f062c5c7c3aa6bf386a9af793489d4a76f56`.

Therefore this preservation failure is pre-existing canonical drift, not introduced by Z47.

## Governance consequence

Do not force-merge PR #921 while repository-wide required checks are red.

Do not modify unrelated FMR/F-CI infrastructure inside Z47.

The safe recovery path is:

1. preserve PR #921 unchanged;
2. repair/requalify the unrelated canonical CI debt in its owning workstream;
3. re-run/re-evaluate PR #921 against the repaired live canonical;
4. merge only when repository governance permits.

## Production boundary

The moving-interface manager remains the already-admitted explicit non-default capability from PR #920.

The Z47 eligibility tightening is qualified and PR-ready but not yet merged.

`LEGACY_NUMERICS` remains production default.
