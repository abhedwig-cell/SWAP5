# F-PE-NLGLOB14Z43E preregistration — revised heterogeneous production-admission candidate

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Parent authorities:

- Z42: `QUALIFIED_Z42_TRAJECTORY_TIMING_GAIN`;
- Z43B: `QUALIFIED_Z43B_MAXIT_INPUT_OWNED`;
- Z43C: `Z43C_REFERENCE_PROFILE_NOT_VIABLE`, with O05/N64, B12/N64 and O05/N32 reference-solvable under the explicit MAXIT16 test profile;
- Z43D: `QUALIFIED_Z43D_REFERENCE_REPLACEMENT_SELECTED`, selecting B01_N64_T49 by reference-only deterministic preflight.

## Purpose

Evaluate the moving-interface manager as a production-admission candidate on one frozen, reference-solvable, heterogeneous four-trajectory set.

Z43E is candidate qualification only. Canonical admission remains a separate governance workunit.

## Frozen explicit numerical test profile

Use exactly the Z43C non-default profile:

- max_iterations = 16;
- max_backtracking = 8;
- conductivity implicit mode = 0;
- conductivity mean = 1;
- min step duration = 1e-6 d;
- compartment and total balance tolerance = 1e-12;
- head absolute and relative tolerance = 1e-9;
- ponding tolerance = 1e-10.

This is not a production default.

No alternative MAXIT or tolerance may be tested in Z43E.

## Frozen holdout set

Exactly:

1. `O05_N64_T49`;
2. `B12_N64_T49`;
3. `O05_N32_T25`;
4. `B01_N64_T49`.

Common trajectory contract:

- dz = 10 cm;
- dt = 0.00125 d;
- fixed top flux = -0.01 cm/d;
- qbot = 0;
- zero sources/sinks;
- 4,000 nominal intervals;
- independent full and adaptive trajectories;
- actual compiled Heritage/reference HeadCalc on both paths;
- no full-state repair of adaptive state.

## Reference authority

The reference-only solvability of all four frozen fixtures is already established by Z43C/Z43D.

Z43E must still fail closed if a full-reference route unexpectedly fails in the integrated holdout execution.

No holdout replacement is allowed after result exposure.

## Frozen physical gates

For every holdout require:

- both full and adaptive trajectories complete;
- finite state;
- adaptive per-interval physical ledger <= 5e-8 cm;
- no accepted-origin/rollback leak;
- contiguous saturated tail;
- ownership change <= 1 face per interval;
- valid provider route;
- max |h adaptive-full| <= 5e-3 cm;
- max |theta adaptive-full| <= 5e-6;
- final tails equal or differ by at most one face with identical ordered ownership directions.

Historical Z30/Z31 strict-reference results remain unchanged.

## Frozen manager-route gates

Per holdout report:

- reduced-route fraction;
- fallback count;
- bypass count;
- fallback reasons;
- active-dimension histogram;
- mean active dimension;
- request/candidate reallocations.

Require:

- explicit route diagnostics;
- no silent fallback;
- reduced-route use >=95%;
- fallback + bypass <=5%;
- all fallback/bypass reasons declared by the manager contract.

## Frozen performance gates

Per holdout report:

- full trajectory wall time;
- adaptive trajectory wall time;
- adaptive/full wall ratio;
- deterministic work ratio.

Admission-candidate aggregate requires:

- no holdout wall ratio >1.05;
- geometric-mean wall ratio <0.98;
- at least 2/4 holdouts wall ratio <0.95;
- geometric-mean deterministic work ratio <0.90.

This is production-shaped solver/trajectory evidence, not whole-MultiSWAP runtime.

## Configuration seam

Replay the explicit manager profile/configuration smoke.

Require:

- default/unset does not select manager;
- legacy profile remains execution-ready;
- manager route requires explicit construction/selection;
- manager route remains non-default;
- fallback remains explicit;
- diagnostics expose manager enabled/used/fallback state.

`LEGACY_NUMERICS` remains production default.

## Frozen classifications

### `QUALIFIED_Z43E_PRODUCTION_ADMISSION_CANDIDATE_READY`

Require:

- configuration seam pass;
- 4/4 full/adaptive physical holdouts pass;
- manager-route gates pass;
- performance aggregate gates pass.

### `Z43E_REFERENCE_FAILURE`

Any full reference unexpectedly fails.

### `Z43E_HOLDOUT_PHYSICAL_MISMATCH`

Reference completes but adaptive physical gate fails.

### `Z43E_OPERATIONAL_FALLBACK_FAILURE`

Manager route/fallback/bypass contract fails.

### `Z43E_PERFORMANCE_NOT_READY`

Physics/configuration pass but performance gates fail without major regression.

### `Z43E_PERFORMANCE_REGRESSION`

Any holdout wall ratio >1.10 or aggregate geometric mean >1.05.

### `Z43E_EXECUTION_INVALID`

Build/timer/reporting invalid.

## Positive consequence

A positive result authorizes a separate canonical production-admission workunit/PR.

Canonical admission must:

1. reconcile to current canonical;
2. keep manager explicit opt-in/default-off;
3. preserve exact full fallback;
4. preserve full-column accepted-state authority;
5. document qualified scope and explicit numerical-profile boundary;
6. keep `LEGACY_NUMERICS` as production default.

## Stop rules

Do not:

- replace any frozen holdout;
- tune MAXIT/tolerances;
- alter forcing/geometry;
- repair adaptive state from full;
- add fitted corrections;
- add mass redistribution;
- change production default;
- infer whole-MultiSWAP speedup.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z43E

BASELINE: `088e09932e33fcb9e2605bed0c7567c2790d7942`

BRANCH: `research/f-pe-nlglob14z43e-revised-admission-candidate`

NEXT SAFE STEP: parameterize the existing Z43C/Z42 compiled holdout harness for the frozen O05/B12/B01 set and execute one compact candidate qualification run.

## Production boundary

Admission-candidate qualification only.

No production default change.

`LEGACY_NUMERICS` remains production default.
