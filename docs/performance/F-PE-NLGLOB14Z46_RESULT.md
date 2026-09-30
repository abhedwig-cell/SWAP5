# F-PE-NLGLOB14Z46 result — explicit moving-interface eligibility guard

Date: 2026-09-30

Status:

`QUALIFIED_Z46_EXPLICIT_ELIGIBILITY_GUARD`

Qualification authority:

- workflow run: `36777867813`;
- workflow conclusion: SUCCESS;
- focused compiled contract smoke: PASS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research postimage before result persistence:

`research/f-pe-nlglob14z46-explicit-eligibility-guard@20671a4cc0d875367baaed148e737f45582c0a24`

## Result

The moving-interface manager now has a typed, fail-closed request-level eligibility guard.

The guard rejects reduced execution unless the currently supported narrow process/configuration contract is satisfied.

Frozen aggregate classification:

`QUALIFIED_Z46_EXPLICIT_ELIGIBILITY_GUARD`.

## Qualified eligibility contract

Reduced execution requires:

- explicit manager enablement;
- valid contiguous saturated lower-tail geometry;
- active guard dimension strictly smaller than full dimension;
- prescribed-flux bottom route;
- exact qbot = 0 within the admitted scope;
- explicit/fixed surface-flux top route;
- macropore physics inactive;
- zero source/sink values on the accepted origin;
- no root-sink process;
- no interface-sensitivity request;
- required constitutive/source-sink/top providers bound.

The guard evaluates the source/sink provider on the accepted origin and therefore does not rely on provider type identity to establish the zero-source/sink scope.

## Fail-closed reasons covered

The focused compiled smoke verifies explicit rejection for:

- `manager-disabled`;
- `invalid-tail-geometry`;
- `no-reduced-dimension`;
- `unsupported-bottom-boundary`;
- `nonzero-bottom-flux`;
- `unsupported-top-boundary`;
- `macropore-active`;
- `source-sink-scope-unsupported`;
- `root-sink-scope-unsupported`;
- `interface-sensitivity-unsupported`;
- `provider-binding-incomplete`.

Eligibility failure produces full bypass.

A forced reduced-solve failure after eligibility produces full fallback.

## Configuration seam

The default-off moving-interface timestep-profile seam from Z43 is carried forward:

- unset/default profile does not silently enable the manager;
- legacy profile behavior is unchanged;
- moving-interface profile requires explicit construction;
- moving-interface execution readiness requires explicit admission enablement.

Thus `LEGACY_NUMERICS` remains the production default.

## Test history

Two earlier workflow attempts failed only in the new smoke harness because custom Fortran provider overrides used incorrect dummy-argument declarations.

Those failures exposed no scientific result and did not require any runtime-guard change.

The final run `36777867813` compiles and passes the frozen contract matrix.

## Interpretation

Z45 identified an admission-layer scope gap.

Z46 closes that gap without changing the reduced physics, reconstruction semantics, mass authority, accepted-state ownership, or fallback model.

The moving-interface manager is now bounded enough to be prepared as a **narrow, non-default canonical admission candidate**.

This does not establish broad material/trajectory portability.

## Qualified claim boundary

Qualified:

- explicit process eligibility;
- fail-closed bypass outside scope;
- explicit fallback after reduced failure;
- default-off / opt-in configuration;
- no excluded frozen process reaches reduced-attempt state in the smoke matrix.

Not qualified:

- broad O14/B12 portability;
- source/sink/macropore/root-sink reduced semantics;
- nonzero qbot reduced semantics;
- dynamic-top reduced production scope;
- interface-sensitivity reduced semantics;
- manager as production default.

## Consequence

Open a focused canonical admission-candidate workunit for the exact narrow scope.

That successor should:

1. carry the manager/profile/eligibility changes onto current canonical;
2. preserve the default-off profile;
3. retain the Z46 contract smoke;
4. replay one already-qualified production-shaped O05/N64 trajectory rather than start a new broad campaign;
5. document the admitted scope and explicit exclusions;
6. seek canonical admission only if current canonical reconciliation is clean.

## Production boundary

Z46 itself is research qualification.

No default change is authorized.

`LEGACY_NUMERICS` remains production default.
