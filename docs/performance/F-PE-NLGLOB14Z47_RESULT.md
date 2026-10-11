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

## 2026-10-11 current-canonical reconciliation

The eight-commit Z47 candidate was replayed without conflict on:

`integration/f-ci-canonical@e3b9685470639355e1899b95c25f9a7ddee15fe6`

The preimage of `src/runtime/mod_moving_interface_manager.f90` remains byte-identical
between the original admission base and this current canonical base:

`27c710e61706a585c359811bee04b60cb14ffec4`

The qualified production postimage remains:

`fc3805e1f106b5de1ee3a492920d0c21eba7bd1d`

The focused owner runner now compiles and executes the eligibility matrix at both
`-O0` and `-O2` and requires byte-identical output. The moving F-CI preservation
runner recognizes only the exact production postimage above and invokes that same
O0/O2 owner runner. This is admission hardening only. No production physics or
default-selection behavior was added.

## Production boundary

No production default change.

`LEGACY_NUMERICS` remains production default.
