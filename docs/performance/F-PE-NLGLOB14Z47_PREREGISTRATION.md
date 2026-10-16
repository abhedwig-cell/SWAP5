# F-PE-NLGLOB14Z47 preregistration — narrow non-default canonical admission candidate

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_ADMISSION_WRITES`

Canonical authority:

`integration/f-ci-canonical@0b231d1669cf38d069f14c6d2f0f07cd3bb1c5b1`

Parent authority:

- Z46: `QUALIFIED_Z46_EXPLICIT_ELIGIBILITY_GUARD`;
- Z42: `QUALIFIED_Z42_TRAJECTORY_TIMING_GAIN`;
- Z43F/PR #920: moving-interface manager seam already admitted as explicit non-default capability;
- current canonical manager source is a strict subset of the Z46 manager source; Z46 adds only explicit fail-closed eligibility guarding to that seam.

## Purpose

Prepare the narrow production-admission candidate that adds explicit process/configuration eligibility to the already-canonical non-default moving-interface manager.

Z47 is selective reconciliation only.

It must not import research history or broaden the admitted physical scope.

## Frozen selective payload

Start from live canonical and admit only:

1. Z46 eligibility additions in `src/runtime/mod_moving_interface_manager.f90`;
2. one focused eligibility contract smoke;
3. one focused admission workflow;
4. Z47 result/closeout documentation.

`src/runtime/mod_timestep_numerical_profile.f90` is already identical between canonical and Z46 and must not change.

## Frozen admission scope

Reduced execution may be attempted only when:

- manager is explicitly enabled;
- accepted state has a valid contiguous saturated lower tail;
- active dimension is >1 and < full dimension;
- bottom boundary is prescribed-flux mode;
- qbot = 0 exactly within this admitted scope;
- top boundary is the explicit/fixed surface-flux route;
- macropore physics is inactive;
- source/sink provider evaluates to zero source and zero sink on the accepted origin;
- root-sink provider is absent;
- interface-sensitivity request is absent;
- required constitutive/source-sink/top providers are bound.

Any eligibility failure must select explicit full bypass with a typed reason.

Reduced solve failure after eligibility must retain explicit exact full fallback.

## Frozen default boundary

- `LEGACY_NUMERICS` remains production default;
- manager selection remains explicit opt-in;
- no universal MAXIT policy is introduced;
- no new accuracy tolerance is introduced.

## Focused verification

Require:

1. canonical compile with the guarded manager module;
2. one eligible request reaches reduced-attempt state;
3. every frozen exclusion reason is fail-closed and cannot reach reduced-attempt state:
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
   - provider-binding-incomplete;
4. forced reduced failure still selects full fallback;
5. accepted origin remains unchanged on rejected/failed reduced paths;
6. canonical numerical-profile file remains byte-identical to the live canonical baseline;
7. no unrelated source changes.

## Frozen classifications

### `QUALIFIED_Z47_NARROW_ADMISSION_CANDIDATE_READY`

All focused verification passes and the branch diff is confined to the bounded eligibility admission payload.

### `Z47_RECONCILIATION_CONFLICT`

Live canonical conflicts materially with the eligibility guard.

### `Z47_ELIGIBILITY_SMOKE_FAILED`

Source reconciles but focused compile/smoke fails.

### `Z47_SCOPE_CONTAMINATION`

Branch diff contains unrelated production/research payload.

## Positive consequence

A positive result authorizes a focused PR to `integration/f-ci-canonical`.

The PR must describe the capability as narrow, explicit opt-in, fail-closed, and default-off.

## Production boundary

No production default change.

`LEGACY_NUMERICS` remains production default.
