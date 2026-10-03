# F-PE-NLGLOB14Z47 result — narrow non-default canonical admission candidate

Date: 2026-10-01

Status:

`QUALIFIED_Z47_NARROW_ADMISSION_CANDIDATE_READY`

Qualification authority:

- focused admission workflow run: `36818047308`;
- smoke job: `110227325151`;
- workflow conclusion: SUCCESS.

Canonical authority rechecked before persistence:

`integration/f-ci-canonical@0b231d1669cf38d069f14c6d2f0f07cd3bb1c5b1`

Admission branch postimage before result persistence:

`work/f-pe-nlglob14z47-narrow-admission-candidate@2b3886205e19ce7c3a54f3bcfbf2bdd1f6efc6c2`

## Aggregate result

The selective eligibility admission candidate passes all frozen Z47 gates.

Classification:

`QUALIFIED_Z47_NARROW_ADMISSION_CANDIDATE_READY`.

## Selective diff

The branch contains only:

- Z47 preregistration/result/closeout documentation;
- the Z46 fail-closed eligibility additions in `src/runtime/mod_moving_interface_manager.f90`;
- one focused eligibility smoke;
- one focused runner/workflow.

`src/runtime/mod_timestep_numerical_profile.f90` is byte-identical to live canonical and is not modified.

No historical research lineage is carried into the admission candidate.

## Eligibility contract

Reduced execution is fail-closed unless all of the bounded scope is satisfied.

The focused smoke verifies explicit rejection for:

- manager-disabled;
- invalid-tail-geometry;
- no-reduced-dimension;
- unsupported-bottom-boundary;
- nonzero-bottom-flux;
- unsupported-top-boundary;
- macropore-active;
- source-sink-scope-unsupported;
- root-sink-scope-unsupported;
- interface-sensitivity-unsupported;
- provider-binding-incomplete.

One valid eligible request reaches reduced-attempt state.

Eligibility failure selects explicit full bypass.

A forced reduced solve failure after eligibility retains explicit full fallback.

## Default/configuration boundary

The current canonical numerical-profile seam remains unchanged.

Therefore:

- `LEGACY_NUMERICS` remains production default;
- manager selection remains explicit opt-in;
- no MAXIT default change is introduced;
- no universal moving-interface accuracy tolerance is introduced.

## Scope boundary

This candidate admits only the process/configuration class already supported by Z46 evidence.

It does not claim:

- nonzero qbot reduced semantics;
- dynamic-top reduced production scope;
- source/sink or root-sink reduced semantics;
- macropore reduced semantics;
- interface-sensitivity reduced semantics;
- broad O14/B12 trajectory portability;
- production-default replacement.

## Consequence

Z47 is ready for a focused PR to `integration/f-ci-canonical`.

The PR must remain narrow, explicit opt-in, fail-closed and default-off.

## Production boundary

No production default change.

`LEGACY_NUMERICS` remains production default.
