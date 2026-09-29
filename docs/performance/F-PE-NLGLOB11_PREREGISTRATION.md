# F-PE-NLGLOB11 preregistration — half-step provider-consistent TG coefficient predictor

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@6ce07b5578c0c1193d2d21a2449a1b7788714f40`

Parent authority:

- TIMEINT16C: `QUALIFIED_PROVIDER_CONSISTENT_TG_KPRED_STAGE`;
- NLGLOB08: S0-stationary replay states are physically tail-inert;
- NLGLOB09: first S0 replay recovered 75/96, physically safe but below the frozen 80% gate;
- NLGLOB10 Arm B: `NLGLOB10_TG_FORWARD_PREDICTOR_DOMAIN_OVERSHOOT`.

## Purpose

NLGLOB10 established that the 7 TG-only retention-domain failures are not invalid accepted states.

They are small overshoots of the auxiliary first-order moisture predictor used only to evaluate the hydraulic coefficient stage.

NLGLOB11 tests one fixed, literature-consistent alternative:

`theta_tilde = theta_n + 0.5 h theta_dot_n`.

The accepted TG update remains unchanged:

`theta_(n+1) = theta_n + 0.5 h (theta_dot_n + theta_dot_p)`.

No accepted-state clipping or retention projection is introduced.

## Rationale

The existing TIMEINT16C authority is based on evaluating nonlinear coefficients on a current-step forward predictor rather than mixing constitutive authorities.

The recorded Thomas-Gladwell/Kavetski mechanism permits coefficient evaluation on a fixed within-step forward prediction `u_(n+phi)` with fixed `phi`, provided the coefficient stage remains sufficiently accurate and the complete method reproduces second-order behavior.

NLGLOB11 freezes:

`phi = 0.5`.

No adaptive phi and no outcome-conditioned shortening are allowed.

## Candidate

For TG only:

1. evaluate accepted-origin physical derivative `theta_dot_n`;
2. form coefficient predictor:
   `theta_tilde = theta_n + 0.5 h theta_dot_n`;
3. require theta_tilde to remain strictly inside the constitutive retention domain;
4. invert exactly to `h_tilde`;
5. evaluate the same constitutive provider on `h_tilde` to obtain `K_tilde`;
6. hold `K_tilde` fixed during the endpoint solve;
7. retain the unchanged TG accepted moisture/head update and physical mass contract.

KLAG is unchanged.

S0 replay is unchanged and remains test-only.

## Qualification has two mandatory banks

### Bank S — smooth TIMEINT16C regression

Reuse the original four smooth fixed-flux ladders.

Frozen gates:

- 4/4 complete;
- median refined top-head order >= 1.6;
- median refined top-theta order >= 1.6;
- at least 3/4 individual head orders >= 1.5;
- physical interval and cumulative ledgers <= 5e-8 cm;
- theta roundtrip <= 1e-12;
- endpoint native balance residual <= 5e-8 cm/d;
- no predictor-domain failure;
- median work per step <= 1.15x KLAG BE.

This gate protects the TIMEINT16 second-order authority.

### Bank D — NLGLOB09 dynamic-top replay

Reuse the exact 96-case replay bank with unchanged S0 termination.

Frozen gates:

1. 96/96 execute;
2. zero `PREDICTED_RETENTION_DOMAIN_FAILED`;
3. complete requested horizon in at least 80% of cases;
4. completed cases span TG and KLAG, all 3 routes and at least 3 materials;
5. max accepted-interval ledger <= 5e-8 cm;
6. max cumulative ledger <= 5e-8 cm;
7. all completed states finite and route-consistent;
8. all S0 replay acceptances retain explicit diagnostics;
9. no extra Newton/backtracking evaluations are introduced by the half-step predictor itself.

## Frozen classifications

If both Bank S and Bank D pass:

`QUALIFIED_TG_HALFSTEP_PROVIDER_PREDICTOR_RESEARCH`.

If predictor-domain exits persist:

`CLOSED_TG_HALFSTEP_PREDICTOR_DOMAIN_NOT_RESOLVED`.

If Bank S loses second-order behavior:

`CLOSED_TG_HALFSTEP_PREDICTOR_ORDER_REGRESSION`.

If smooth authority passes but dynamic recovery remains below 80%:

`CLOSED_TG_HALFSTEP_PREDICTOR_INSUFFICIENT_DYNAMIC_RECOVERY`.

If mass/state safety fails:

`CLOSED_TG_HALFSTEP_PREDICTOR_PHYSICAL_ADMISSIBILITY_FAILED`.

## Stop rules

Do not tune phi after result exposure.

Do not try phi=0.25, 0.75 or adaptive phi within NLGLOB11.

Do not clip theta_tilde.

Do not alter S0, BALTOL02, MAXIT, backtracking, timestep, K staging ownership or route physics.

A different predictor requires a separately preregistered successor.

## Consequence

A positive result removes the NLGLOB10 Arm-B blocker and may bring the combined replay recovery above the original NLGLOB09 80% gate.

The 14 NLGLOB10 Arm-A above-floor endpoint failures remain a separate blocker and are not reclassified by this workunit.

## Architecture invariants

Affected invariants: 7, 13, 23, 24, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB11

BASELINE: `6ce07b5578c0c1193d2d21a2449a1b7788714f40`

BRANCH: `research/f-pe-nlglob11-halfstep-predictor`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: materialize fixed phi=0.5 predictor in smooth and dynamic research harnesses

RECOVERY POINT: this preregistration commit

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
