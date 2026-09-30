# F-PE-PZG23-04 — nonlinear iteration-ceiling falsification

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH

Baseline:
`integration/f-ci-canonical@f133e47f8f7899f3d70db79f9ea63fbb730b2da0`

Parent authority:
- F-PE-PZG23-01 localized the blocker to origins 10 and 11;
- F-PE-PZG23-02 falsified temporal-history content and hidden solver scratch;
- F-PE-PZG23-03 attributed the blocker primarily to solver rejection.

## Purpose

Test whether the configured nonlinear iteration ceiling is causal for the two
localized pZg23 interval-B solver failures.

This is a bounded diagnostic falsification, not a production repair.

## Evidence motivating the test

PZG23-03 observed:

### Origin 10

- solver rejections = 14;
- total nonlinear iterations = 496.

With production `max_iterations=32`:

`14 * 32 = 448`.

Only 48 nonlinear iterations remain for all non-terminal attempts.

### Origin 11

- solver rejections = 20;
- total nonlinear iterations = 663.

`20 * 32 = 640`.

Only 23 nonlinear iterations remain for all non-terminal attempts.

This strongly suggests each rejected solver attempt is exhausting the configured
nonlinear iteration ceiling.

At the same time, mean backtracking usage is approximately 5.6--5.8 attempts
per nonlinear iteration, below the configured `max_backtracking=12`, so
backtracking-depth is not the first discriminator.

## Frozen cases

Profile:
`90210030 / pZg23`.

Origins:

- origin 10: h0=+2 cm, forcing delta=+0.035 cm/day;
- origin 11: h0=+2 cm, forcing delta=+0.050 cm/day.

Unchanged:

- exact frozen geometry and retention;
- GENERATED ELAS;
- bottom_mode=7;
- swkimpl=0;
- RICHARDS_TEMPORAL_HISTORY;
- caller-owned head budget=0.20 cm;
- max_backtracking=12;
- max retries=8;
- all balance/head tolerances;
- hard mass.

## Arms

For each origin, rerun interval A exactly as production authority and then
interval B from its accepted committed state.

Evaluate exactly:

### BASELINE

- max_iterations=32;
- max_backtracking=12.

Must reproduce failure.

### ITER64

- max_iterations=64;
- max_backtracking=12.

No other numerical or physical setting changes.

## Hypotheses

H1 — nonlinear iteration ceiling is causal:

Supported if BASELINE fails and ITER64 completes/commits both origins with
complete hard mass and without any tolerance/budget change.

H2 — iteration ceiling is not sufficient:

Supported if one or both ITER64 arms still fail.

Only if H2 is supported may a later workunit test a backtracking-specific
mechanism.

## Diagnostics

Record per origin and arm:

- completion/commit;
- kernel status;
- solver/temporal/mass rejection counts;
- transaction attempts/retries;
- accepted substeps;
- nonlinear iterations;
- internal retries;
- HeadCalc calls;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- accepted dt range;
- hard-mass completeness/residual.

## Stop rule

Close after this two-arm test.

Do not in PZG23-04:

- change max_backtracking;
- change retry count;
- change temporal budget;
- change any tolerance;
- change ELAS;
- admit max_iterations=64 to production.

A production change requires a separate admission workunit even if H1 is
supported.
