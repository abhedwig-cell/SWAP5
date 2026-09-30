# F-PE-NLGLOB14Z44A preregistration — canonical admission of non-default moving-interface manager

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_ADMISSION`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Admission-candidate authority:

- Z43E: `QUALIFIED_Z43E_PRODUCTION_ADMISSION_CANDIDATE_READY`;
- workflow run `36779179196`, job `110104641032`;
- four frozen heterogeneous trajectories pass;
- geometric-mean trajectory wall ratio about 0.9216;
- geometric-mean deterministic work ratio about 0.7695;
- manager remains explicit opt-in/default-off.

## Purpose

Admit only the already-qualified production/runtime seam for the moving-interface manager into canonical as an explicit non-default capability.

Z44A is admission/integration only.

It must not reopen moving-interface science, tune timing, broaden holdouts, or change numerical defaults.

## Selective-admission rule

Do **not** merge or cherry-pick the accumulated research branch history.

Start from live canonical and selectively admit only:

1. `src/runtime/mod_moving_interface_manager.f90`;
2. the explicit moving-interface profile seam in `src/runtime/mod_timestep_numerical_profile.f90`;
3. minimal focused admission tests for:
   - default-off / explicit-opt-in profile behavior;
   - reduced-view / fallback / bypass / rollback-no-leak manager behavior;
4. admission documentation.

Research-only workflows, long trajectory harnesses, generated fixtures and MAXIT16 holdout materializers are not production payload.

## Frozen production semantics

### Default behavior

- `LEGACY_NUMERICS` remains production default.
- An unset profile must not select the manager.
- Manager execution requires explicit profile construction and explicit admission-ready selection.

### Physical authority

- Full-column accepted state remains the sole committed physical authority.
- Reduced request/state/workspace remains reconstructible scratch.
- Manager code does not commit state.

### Fallback and bypass

- Full fallback remains exact and explicit.
- Ineligible reduced views bypass explicitly.
- Fallback/bypass reason remains typed diagnostic evidence.
- No silent repair of a failed reduced candidate.

### Transaction / mass

- Existing commit/rollback authority remains outside the manager.
- Failed reduced attempts may not mutate accepted h/theta.
- No mass redistribution or correction term is admitted.

### Numerical-profile boundary

Z43E used an explicit non-default MAXIT16 test profile to establish reference-solvable admission evidence.

Z44A must **not** set MAXIT16 as a repository default.

MAXIT remains input/profile-owned under Z43B authority.

## Frozen admission tests

### Profile smoke

Require:

- default/unset invalid/not execution-ready;
- legacy profile execution-ready;
- moving-interface profile valid but not execution-ready unless explicitly admission-ready;
- explicit admission-ready manager profile execution-ready.

### Manager seam smoke

Require:

- full accepted state remains full-shaped;
- eligible reduced view has active_nodes < full_nodes;
- reduced request/workspace shape is reduced;
- reduced candidate rematerializes to full shape;
- reduced route is selected when valid;
- forced reduced failure selects exact full fallback;
- failed reduced route leaves accepted h/theta byte-equivalent to origin;
- ineligible full-dimension view selects explicit bypass;
- active dimension and fallback reason diagnostics are unambiguous.

## Frozen admission classifications

### `QUALIFIED_Z44A_CANONICAL_ADMISSION_READY`

Require:

- selective source payload compiles;
- both focused smokes pass;
- default-off semantics pass;
- no production default changes;
- branch is cleanly based on current canonical;
- admission documentation records qualified scope and Z43E evidence boundary.

### `Z44A_CANONICAL_ADMISSION_BLOCKED`

Use for compile/test/integration conflict or any ownership/default regression.

## Positive consequence

A positive result authorizes a PR from this branch to `integration/f-ci-canonical`.

Canonical merge remains subject to live branch reconciliation and repository governance.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z44A

BASELINE: `ddd218085afd363d22ce0b632d3ac893c7c9f40b`

BRANCH: `work/f-pe-nlglob14z44a-canonical-admission`

NEXT SAFE STEP: selectively materialize the two qualified runtime/configuration files and focused admission tests.

## Production boundary

Admission target is an explicit non-default manager capability only.

`LEGACY_NUMERICS` remains production default.
