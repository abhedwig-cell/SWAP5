# F-PE-NLGLOB12C preregistration — representation-aware endpoint convergence replay

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@15e5fa2738a889700dc4b8ed792e823652b38dd3`

Parent authority:

- NLGLOB08: post-S0 physical tail drift is inert;
- NLGLOB09: unchanged S0 replay is physically clean but recovers 75/96;
- NLGLOB12A: all 8 above-floor stagnation trajectories satisfy both local and aggregate storage-representation bounds at terminal failure;
- BALTOL02 remains unchanged production authority.

## Purpose

NLGLOB12C tests whether a test-only representation-aware convergence certificate can safely complement the existing S0 replay and recover the stagnation subset without relaxing any configured balance tolerance.

The representation certificate is derived only from the finite arithmetic resolution of the stored moisture state.

## Test-only replay composition

Start from the unchanged NLGLOB09 S0 replay.

Add a second acceptance route:

`R0_REPRESENTATION_FLOOR`.

R0 may terminate a nonlinear endpoint iteration only when all of the following hold.

### R0.1 Node-local representation bound

For every active node i:

`|R_i| <= U_i`

with

`U_i = (ulp(theta_i)+ulp(theta_m1_i))*f_i*dz_i/dt`.

No multiplicative factor above 1 is allowed.

### R0.2 Aggregate representation bound

`|sum_i R_i| <= U_total`

with

`U_total = sum_i |U_i|`.

No multiplicative factor above 1 is allowed.

### R0.3 Existing state guards

The unchanged head-update convergence contract passes.

Where applicable, the unchanged ponding convergence contract passes.

### R0.4 State and route safety

All relevant state and residual quantities are finite.

The dynamic-top provider route remains equal to the active route.

### R0.5 No physics reconstruction

No external flux is reconstructed from storage.

The accepted candidate and later physical mass ledger are evaluated exactly as in the existing TIMEINT17/NLGLOB09 bank.

## Frozen bank

Use the complete 96-case NLGLOB09 replay bank:

- B01, B12, O05, O14;
- FLUX, HEAD, RUNOFF;
- TG and KLAG;
- four dt levels;
- unchanged dynamic-top provider;
- unchanged TG coefficient staging;
- unchanged BALTOL02;
- unchanged head and ponding tolerances;
- MAXIT=8;
- MaxBackTr=8.

The original S0 route remains unchanged.

## Frozen diagnostics

Every representation-floor acceptance must emit:

`F_PE_NLGLOB12C_ACCEPT|REASON=REPRESENTATION_FLOOR`.

Record:

- iteration;
- route;
- max local normalized representation ratio;
- aggregate normalized representation ratio;
- head ratio;
- ponding ratio where applicable.

S0 acceptances retain their existing diagnostic identity.

## Frozen qualification gates

Classify:

`QUALIFIED_REPRESENTATION_AWARE_ENDPOINT_REPLAY_RESEARCH`

only if all hold:

1. 96/96 bank cases execute without process failure except previously identified TG predictor-domain failures outside this endpoint certificate scope;
2. completed requested horizon in at least 80% of the full 96-case bank;
3. completed cases span TG and KLAG, all 3 routes and at least 3 materials;
4. all 8 NLGLOB12A stagnation trajectories are recovered or cease to terminate as above-floor stagnation failures;
5. max accepted-interval physical ledger <= `5e-8 cm`;
6. max cumulative physical ledger <= `5e-8 cm`;
7. every representation-floor acceptance satisfies R0 with both normalized ratios <=1;
8. no nonfinite state is accepted;
9. no route-mismatch state is accepted;
10. no extra Newton or backtracking evaluation is introduced by R0.

If any accepted representation-floor state violates physical mass:

`CLOSED_REPRESENTATION_REPLAY_PHYSICAL_MASS_FAILED`.

If any unsafe route/nonfinite state is accepted:

`CLOSED_REPRESENTATION_REPLAY_STATE_UNSAFE`.

If safety passes but full-bank recovery remains below 80%:

`CLOSED_REPRESENTATION_REPLAY_INSUFFICIENT_RECOVERY`.

If R0 cannot be implemented exactly from current state/residual authority:

`BLOCKED_REPRESENTATION_REPLAY_IMPLEMENTATION`.

## Interpretation boundary

A positive NLGLOB12C result would qualify a research numerical-policy certificate.

It would not itself change BALTOL02 or production convergence.

It would establish that some endpoint failures can be terminated because further residual reduction is impossible within the stored moisture representation, not because a looser physical tolerance was chosen.

## Stop rules

Do not:

- multiply U_i or U_total by a fitted factor;
- alter BALTOL02;
- weaken head or ponding guards;
- increase MAXIT or backtracking;
- alter timestep or K staging;
- accept above-representation residuals.

## Architecture invariants

Affected invariants: 7, 13, 23, 24, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB12C

BASELINE: `15e5fa2738a889700dc4b8ed792e823652b38dd3`

BRANCH: `research/f-pe-nlglob12c-representation-replay`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: materialize exact R0 alongside unchanged S0 replay and execute the full 96-case bank

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
