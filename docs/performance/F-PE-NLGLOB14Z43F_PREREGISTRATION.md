# F-PE-NLGLOB14Z43F preregistration — canonical admission of non-default moving-interface manager

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_ADMISSION_WRITES`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Candidate authority:

- Z43E: `QUALIFIED_Z43E_PRODUCTION_ADMISSION_CANDIDATE_READY`;
- 4/4 reference-valid heterogeneous trajectory holdouts;
- 4/4 adaptive physical/operational passes;
- 100% reduced-route use in the frozen set;
- zero fallback/bypass incidence in the frozen set;
- geometric-mean trajectory wall ratio about 0.92158;
- geometric-mean deterministic work ratio about 0.76950;
- explicit non-default MAXIT16 test profile used only as admission evidence;
- `LEGACY_NUMERICS` remains production default.

## Purpose

Admit the already-qualified moving-interface manager seam to canonical as an explicit opt-in, default-off production capability.

Z43F is admission/reconciliation only.

Do not expand scientific scope or retune performance.

## Selective reconciliation rule

The Z43E research branch contains extensive historical research lineage and may not be merged wholesale.

Z43F must start from live canonical and admit only the qualified production-facing seam:

1. `src/runtime/mod_moving_interface_manager.f90`;
2. the minimal moving-interface profile extension to `src/runtime/mod_timestep_numerical_profile.f90`;
3. focused admission/readiness tests and documentation;
4. no historical research workflows or harnesses unless directly required for admission verification.

## Frozen production contract

Admission must preserve:

- full-column accepted state as sole physical authority;
- reduced state/request/workspace as reconstructible scratch;
- explicit full fallback and bypass routes;
- transaction/rollback authority outside the manager;
- no reduced candidate leak on failure;
- typed active-dimension/fallback diagnostics;
- explicit manager selection only;
- default/unset profile must not select moving-interface manager;
- `LEGACY_NUMERICS` remains production default.

## Numerical-profile boundary

Canonical admission does **not** establish a universal MAXIT16 policy.

MAXIT remains input/profile-owned per Z43B.

The MAXIT16 profile used by Z43E is evidence scope only.

## Focused admission verification

Require:

1. canonical compile with the admitted manager module;
2. profile smoke:
   - default invalid/unset does not select manager;
   - legacy profile remains execution-ready;
   - moving-interface profile requires explicit construction;
   - moving-interface profile is execution-ready only when explicitly marked admission-ready;
3. manager seam smoke:
   - full accepted state remains full-shaped;
   - reduced view uses fewer active nodes;
   - reduced candidate materializes to full shape;
   - forced fallback is exact and explicit;
   - failed reduced attempt does not mutate accepted origin;
4. no production-default change;
5. no unrelated source changes.

## Frozen classifications

### `QUALIFIED_Z43F_CANONICAL_ADMISSION_READY`

All focused verification passes and the canonical diff contains only the qualified admission seam.

### `Z43F_CANONICAL_RECONCILIATION_CONFLICT`

Live canonical changes materially conflict with the qualified seam and cannot be reconciled without new science.

### `Z43F_ADMISSION_SMOKE_FAILED`

Source reconciles, but focused compile/smoke verification fails.

### `Z43F_SCOPE_CONTAMINATION`

Admission diff includes unrelated research/history changes.

## Positive consequence

A positive result authorizes a focused PR to `integration/f-ci-canonical`.

The PR must remain explicit opt-in/default-off and must not claim whole-MultiSWAP speedup or broad BOFEK portability.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z43F

BASELINE: `ddd218085afd363d22ce0b632d3ac893c7c9f40b`

BRANCH: `work/f-pe-nlglob14z43f-canonical-admission-v2`

NEXT SAFE STEP: selectively materialize the manager module and minimal profile extension from Z43E onto live canonical, then run focused admission smoke.

## Production boundary

Admission target is a non-default production capability only.

`LEGACY_NUMERICS` remains production default.
