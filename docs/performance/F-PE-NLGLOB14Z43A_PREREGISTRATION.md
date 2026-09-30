# F-PE-NLGLOB14Z43A preregistration — heterogeneous holdout reference-solvability attribution

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Parent authority:

- Z43: `Z43_HOLDOUT_PHYSICAL_MISMATCH`;
- H1 O05/N64/T49 passed physically and performed well;
- H2 O14/N64/T49 failed in the full reference solve before adaptive-manager evaluation;
- manager configuration seam itself passed.

## Purpose

Determine whether the frozen heterogeneous Z43 holdouts are valid full-reference trajectories under the frozen Z43 numerical configuration.

This workunit attributes reference solvability only. It does not alter moving-interface physics or admission gates.

## Frozen cases

Exactly:

1. O14_N64_T49;
2. B12_N64_T49;
3. O05_N32_T25.

Common:

- dt = 0.00125 d;
- fixed top flux = -0.01 cm/d;
- qbot = 0;
- zero source/sink;
- conductivity implicit mode = 0;
- conductivity mean = 1;
- max iterations = 8;
- max backtracking = 8;
- same balance/head tolerances as Z43;
- 4,000 nominal intervals maximum.

## Frozen diagnostics

For each case record:

- first-step solver status;
- retry_advised;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- internal retries;
- diagnostics route;
- first failing interval, if any;
- failure solver status and diagnostics;
- last successfully accepted interval;
- max accepted per-interval physical ledger before failure;
- tail identity at origin and last accepted state.

## Frozen classifications

### `QUALIFIED_Z43A_REFERENCE_TRAJECTORIES_SOLVABLE`

All three full-reference trajectories complete 4,000 intervals.

### `QUALIFIED_Z43A_REFERENCE_FAILURE_LOCALIZED`

At least one case fails, and the exact first failing interval/status/diagnostics are captured.

### `Z43A_REFERENCE_EXECUTION_INVALID`

Harness/build/reporting invalid.

## Consequence

If all are solvable, revisit Z43 harness execution.

If failure is localized, use a separately preregistered successor to determine whether the failing holdout geometry is outside an already-admitted production numerical envelope or whether the frozen holdout should be replaced by a reference-solvable heterogeneous case.

Do not change max iterations, forcing, tail geometry, dt or tolerance inside Z43A.

## Stop rules

Do not:

- invoke the moving-interface manager;
- tune numerical parameters;
- repair state;
- change the frozen three cases;
- reinterpret Z43 negatively or positively.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z43A

BASELINE: `c703627a0b4754059ec9c6a13c6d75d6f38b42d7`

BRANCH: `research/f-pe-nlglob14z43a-holdout-reference-solvability`

NEXT SAFE STEP: execute full-reference-only 4,000-interval diagnostics for the three frozen cases.

## Production boundary

Research attribution only.

No production default change.
