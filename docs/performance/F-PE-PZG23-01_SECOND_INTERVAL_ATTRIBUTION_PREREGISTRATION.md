# F-PE-PZG23-01 — pZg23 second-interval solvability attribution

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH

Baseline:
`integration/f-ci-canonical@ebb7a9da9f2a2f31dae0b049d88d8bee8b2b89a2`

Parent blocker:
F-PE-SCHED02.

## Purpose

Attribute the exact second-interval failure that blocks the SCHED02 five-profile
lagged-work selector domain.

This workunit is not a scheduler study and does not change worker-count policy.

## Frozen physical case

Profile:

- normalsoilprofile_id = 90210030;
- soil unit = pZg23;
- exact frozen BRO/BOFEK geometry;
- exact Staringreeks retention;
- GENERATED ELAS;
- bottom_mode = 7;
- swkimpl = 0;
- RICHARDS_TEMPORAL_HISTORY;
- explicit caller-owned head budget = 0.20 cm.

Interval duration:

`0.015625 day`.

Maximum retries:
8.

Use exactly the sixteen unique origin combinations:

- h0 = -75, -20, +2, +10 cm;
- forcing delta = -0.05, -0.035, +0.035, +0.05 cm/day.

Each case runs two consecutive accepted-state intervals:

- interval A: t = 0 -> dt;
- interval B: t = dt -> 2*dt.

Worker count:
1 only.

## Diagnostics

For every origin record separately for A and B:

- kernel status;
- completed/committed;
- attempts;
- retries;
- admission/rejection classification;
- accepted substeps;
- nonlinear iterations;
- internal retries;
- HeadCalc calls;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- final committed time/revision;
- mass completeness and residual.

Also record the aggregate list of failing B origins.

## Hypotheses

H1:
the blocker is localized to a strict subset of the sixteen origins.

H2:
the B failure is solver/solvability dominated rather than hard-mass rejection.

H3:
the failure occurs after a valid interval-A commit and is therefore a
continuation-state/domain issue, not an invalid initial-state construction.

## Stop rule

This workunit ends after attribution.

Do not:

- change 0.20 cm;
- increase retry count;
- relax hard mass;
- change compartment/total-balance tolerances;
- remove pZg23;
- attempt a numerical repair in the same workunit.

A repair, if justified, must be preregistered separately after the failure
mechanism is known.
