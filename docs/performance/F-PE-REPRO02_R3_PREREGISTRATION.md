# F-PE-REPRO02 R3 — minimum-step sensitivity

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

R2 showed that raising nonlinear/backtracking caps through 48/16 does not restore difficult-origin nonzero corrector convergence.

The remaining known numerical difference from the successful P0 direct-solver route is:

- participant: `min_step_duration = 1e-8 day`;
- P0 direct solver: `min_step_duration = 1e-10 day`.

Failed participant solves report one internal retry.

## Question

Does lowering only `min_step_duration` restore exact participant convergence for +/-0.001 cm correctors?

## Fixed controls

Use:

- max nonlinear iterations = 48;
- max backtracking = 16;
- exact tolerances unchanged;
- same material/state/forcing;
- same temporal budget and transaction policy.

Test:

- 1e-8 day;
- 1e-9 day;
- 1e-10 day;
- 1e-11 day;
- 1e-12 day.

## Cases

All six difficult PROFILE06 origins.

Offsets:

- -0.001 cm;
- +0.001 cm.

Three fresh-process repetitions per point.

## Decision

If 1e-10 or below restores the same cases that P0 can solve, minimum-step policy is the controlling difference and must be studied separately before any production change.

If failures persist to 1e-12, the cause is not the minimum-step floor and REPRO02 proceeds to a direct request-state comparison between the participant and P0 solver calls.
