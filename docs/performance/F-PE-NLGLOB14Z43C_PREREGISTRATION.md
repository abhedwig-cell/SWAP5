# F-PE-NLGLOB14Z43C preregistration — revised explicit-profile production-admission holdout

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Parent authority:

- Z43: heterogeneous admission attempt blocked because H2 full reference exhausted frozen MAXIT=8;
- Z43A: O14/N64 fails at step 286 and B12/N64 at step 2276 exactly at NL/JAC/BACKTRACK=8; O05/N32 completes;
- Z43B: `QUALIFIED_Z43B_MAXIT_INPUT_OWNED`; MAXIT is an explicit legacy numerical-profile/input value, not a hardcoded production default;
- historical MAXIT16 remains research-only and is not a global default.

## Purpose

Re-run the compact Z43 admission holdout under one explicitly frozen, non-default legacy numerical test profile.

This workunit does not change the production default.

## Frozen numerical profile

Use exactly:

- max_iterations = 16;
- max_backtracking = 8;
- conductivity implicit mode = 0;
- conductivity mean = 1;
- min step duration = 1e-6 d;
- compartment and total balance tolerance = 1e-12;
- head absolute and relative tolerance = 1e-9;
- ponding tolerance = 1e-10.

All other Z43 forcing, geometry and manager semantics remain unchanged.

MAXIT=16 is a bounded test profile, not a production policy.

No alternate MAXIT may be tried inside Z43C.

## Frozen holdouts

Exactly the original four:

1. H1 O05_N64_T49;
2. H2 O14_N64_T49;
3. H3 B12_N64_T49;
4. H4 O05_N32_T25.

Each:

- dt = 0.00125 d;
- fixed top flux = -0.01 cm/d;
- qbot = 0;
- 4,000 nominal intervals.

## Phase A — mandatory full-reference preflight

Before any adaptive timing decision, require the full reference trajectory for all H1-H4 to complete 4,000 intervals under the frozen MAXIT16 profile.

Record first failure diagnostics exactly as Z43A if any.

If any full-reference holdout fails:

`Z43C_REFERENCE_PROFILE_NOT_VIABLE`

and do not interpret adaptive performance as admission evidence.

## Phase B — adaptive manager holdout

Only after 4/4 reference preflight passes, execute full/adaptive independent trajectories for H1-H4 under the same frozen numerical profile.

Use the Z43 physical, manager-route and performance gates unchanged.

### Physical gates

For every holdout:

- both trajectories complete;
- finite state;
- adaptive per-interval ledger <=5e-8 cm;
- no origin/rollback leak;
- contiguous tail;
- ownership changes <=1 face;
- max |h adaptive-full| <=5e-3 cm;
- max |theta adaptive-full| <=5e-6;
- final tails equal or within one face with identical ordered event directions.

### Manager-route gates

- diagnostics present;
- no silent fallback;
- fallback+bypass <=5% intervals;
- fallback reason must belong to declared manager contract.

### Performance gates

- no wall ratio >1.05;
- geometric-mean wall ratio <0.98;
- at least 2/4 holdouts wall ratio <0.95;
- geometric-mean work ratio <0.90.

## Configuration seam

Replay the Z43 profile smoke:

- default/unset does not select manager;
- legacy profile remains ready;
- manager route requires explicit construction;
- manager route remains non-default.

## Frozen classifications

### `QUALIFIED_Z43C_PRODUCTION_ADMISSION_CANDIDATE`

Require:

- configuration smoke pass;
- 4/4 full-reference preflight pass;
- 4/4 adaptive physical gates pass;
- manager-route gates pass;
- performance gates pass.

### `Z43C_REFERENCE_PROFILE_NOT_VIABLE`

Any full-reference preflight fails.

### `Z43C_HOLDOUT_PHYSICAL_MISMATCH`

Preflight passes but adaptive physical gate fails.

### `Z43C_HOLDOUT_PERFORMANCE_NOT_READY`

Physics/configuration pass but performance gates fail without major regression.

### `Z43C_HOLDOUT_PERFORMANCE_REGRESSION`

Any wall ratio >1.10 or aggregate geometric mean >1.05.

### `Z43C_CONFIGURATION_OR_FALLBACK_FAILED`

Configuration/fallback contract fails.

### `Z43C_EXECUTION_INVALID`

Build/report/timing invalid.

## Positive consequence

A positive result authorizes a separate canonical production-admission workunit/PR.

Canonical admission remains separate and `LEGACY_NUMERICS` remains default.

## Stop rules

Do not:

- test another MAXIT in this workunit;
- change tolerances;
- change forcing or geometry;
- tune manager physics;
- repair adaptive state from full;
- change default selection.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z43C

BASELINE: `6614a75a66555f8d12c5706c497deab8067c3656`

BRANCH: `research/f-pe-nlglob14z43c-explicit-profile-admission`

NEXT SAFE STEP: MAXIT16 full-reference preflight followed conditionally by the frozen H1-H4 adaptive holdout.

## Production boundary

Admission-candidate test profile only.

No production default change.
