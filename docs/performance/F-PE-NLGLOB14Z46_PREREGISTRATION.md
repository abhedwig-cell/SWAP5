# F-PE-NLGLOB14Z46 preregistration — explicit moving-interface eligibility guard

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULT`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Baseline:

`research/f-pe-nlglob14z46-explicit-eligibility-guard@4077a365cedee32ab944e538283ccc18a4d17101`

## Parent authority

- Z45: `Z45_SCOPE_NOT_BOUNDED`;
- Z35: explicit fallback/bypass/no-leak semantics qualified;
- Z42: one production-shaped O05/N64 trajectory physically exact and faster;
- Z43: default-off profile seam demonstrated but heterogeneous holdout blocked by full-reference validity;
- Z44: synthetic O14/B12 reference holdouts unavailable.

## Purpose

Add a typed, fail-closed eligibility guard so the reduced moving-interface route cannot execute outside the currently supported narrow process/configuration scope.

Z46 is an admission-layer contract workunit, not a new physics workunit.

## Frozen supported scope

Reduced execution is eligible only if all are true:

1. manager is explicitly enabled by an opt-in numerical profile;
2. full accepted state has a valid contiguous saturated lower tail;
3. active guard dimension is >1 and < full dimension;
4. bottom boundary is prescribed flux mode and qbot is exactly 0 for this admission scope;
5. top boundary is the qualified explicit/fixed surface-flux route;
6. macropore physics is inactive;
7. no unsupported root-sink or nonzero source/sink process is admitted by the manager scope;
8. no interface-sensitivity request is active;
9. required constitutive/source-sink/top providers are bound consistently;
10. reduced solve/reconstruction subsequently satisfies normal physical/mass acceptance.

## Required fail-closed reasons

At minimum expose distinct reasons for:

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

Eligibility failure must produce full bypass, not reduced attempt.

Reduced execution failure after eligibility must retain full fallback.

## Configuration seam

Carry forward the Z43 default-off profile semantics:

- legacy profile remains unchanged and execution-ready;
- moving-interface profile is explicit opt-in;
- moving-interface profile is not execution-ready unless specifically admission-enabled;
- unset/default state must not silently select the manager.

## Frozen test matrix

One compiled contract smoke must cover:

- one eligible reduced request;
- each required ineligibility reason above;
- one reduced-failure -> full-fallback path;
- one geometry-ineligible -> full-bypass path;
- config default-off / explicit opt-in.

No long trajectory or timing benchmark is required.

## Frozen classification

### `QUALIFIED_Z46_EXPLICIT_ELIGIBILITY_GUARD`

Require all smoke cases pass and no excluded process can reach reduced-attempt state.

### `Z46_ELIGIBILITY_GUARD_INCOMPLETE`

Any frozen exclusion lacks a fail-closed guard.

### `Z46_CONFIG_SEAM_INVALID`

Default-off / opt-in profile semantics fail.

### `Z46_EXECUTION_INVALID`

Build or smoke harness invalid.

## Positive consequence

A positive result authorizes preparation of a narrow, non-default canonical admission candidate with the exact bounded scope above.

## Production boundary

No default change.

`LEGACY_NUMERICS` remains production default.
