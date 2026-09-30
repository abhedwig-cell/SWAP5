# F-PE-NLGLOB14Z43A result — heterogeneous holdout reference-solvability attribution

Date: 2026-09-30

Status:

`QUALIFIED_Z43A_REFERENCE_FAILURE_LOCALIZED`

Qualification authority:

- workflow run: `36776407351`;
- job: `110095310444`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research postimage before result persistence:

`research/f-pe-nlglob14z43a-holdout-reference-solvability@3cd527b7cb43e037cfda9a7de87a250a5c825463`

## Aggregate result

The Z43 heterogeneous holdout failure is localized to the frozen full-reference iteration ceiling.

Two N=64 material trajectories eventually return `SW_SOLVE_RETRY_ADVISED` exactly when the full reference reaches the frozen `max_iterations=8` limit.

The N=32 O05 trajectory completes all 4,000 frozen intervals.

## O14_N64_T49

- completes 285 accepted intervals;
- first failing interval: 286;
- solver status: 2 / retry advised;
- nonlinear iterations: 8;
- Jacobian builds: 8;
- linear solves: 8;
- backtracking attempts: 8;
- internal retries: 1;
- diagnostics route: `legacy-reference-retry`;
- max accepted physical ledger before failure: about `1.19e-15 cm`;
- saturated-tail identity remains 49.

This is not a first-step geometry or constitutive-domain failure.

## B12_N64_T49

- completes 2,275 accepted intervals;
- first failing interval: 2,276;
- solver status: 2 / retry advised;
- nonlinear iterations: 8;
- Jacobian builds: 8;
- linear solves: 8;
- backtracking attempts: 8;
- internal retries: 1;
- diagnostics route: `legacy-reference-retry`;
- max accepted physical ledger before failure: about `1.19e-15 cm`;
- saturated-tail identity remains 49.

Again the failure lands exactly on the frozen eight-iteration ceiling.

## O05_N32_T25

PASS through all 4,000 intervals.

At final interval:

- status: converged;
- retry advised: false;
- nonlinear iterations: 3;
- Jacobian builds: 3;
- linear solves: 3;
- backtracking attempts: 3;
- internal retries: 0;
- route: `legacy-reference-bound`;
- max physical ledger: about `1.96e-16 cm`;
- final tail: 25.

## Interpretation

Z43A establishes that the failed Z43 heterogeneous holdouts were not invalid at their origin.

Both failed N=64 fixtures remain physically clean for substantial trajectories and fail only when the full reference route exhausts the frozen research limit of eight nonlinear iterations.

The coincidence:

`NL = JAC = LINEAR = BACKTRACK = 8`

with retry advice is strong evidence that the Z43 blocker is a numerical-ceiling/holdout-configuration issue rather than a moving-interface manager failure.

Z43A does not itself authorize increasing `max_iterations`.

## Qualified claim boundary

Qualified:

- exact first failure intervals for O14/N64 and B12/N64;
- failures are full-reference retries;
- failures occur exactly at the frozen maxit=8 ceiling;
- physical mass remains clean before failure;
- O05/N32 is reference-solvable for 4,000 intervals.

Not qualified:

- what higher iteration ceiling should be used;
- whether the actual production/legacy configuration already uses a different ceiling;
- revised production-admission holdouts;
- moving-interface admission.

## Consequence

The next workunit must identify the already-admitted production/legacy nonlinear iteration policy and compare the Z43 frozen `maxit=8` choice against that authority.

Only after that comparison may a revised heterogeneous admission holdout be preregistered.

Do not empirically tune an iteration ceiling from these three fixtures.

## Production boundary

Research attribution only.

No production default change.
