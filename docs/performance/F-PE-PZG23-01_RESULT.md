# F-PE-PZG23-01 — pZg23 second-interval solvability attribution result

Date: 2026-09-30

Status: QUALIFIED_LOCALIZED_SOLVABILITY_ATTRIBUTION

Branch:
`research/f-pe-pzg23-01-second-interval-attribution`

Qualified postimage:
`cb1163645440e897081baaed05c87e63c2f7bb49`

Canonical baseline:
`integration/f-ci-canonical@ebb7a9da9f2a2f31dae0b049d88d8bee8b2b89a2`

Workflow run:
`36760892904`

Job:
`110042844371`

Conclusion:
SUCCESS.

## Question

Which exact pZg23 origins cause the SCHED02 second-interval blocker, and is the
failure dominated by nonlinear solvability or hard-mass acceptance?

## Frozen case

Profile:

- 90210030 / pZg23;
- exact frozen BRO/BOFEK geometry;
- exact Staringreeks retention;
- GENERATED ELAS;
- bottom_mode=7;
- swkimpl=0;
- RICHARDS_TEMPORAL_HISTORY;
- explicit caller-owned head budget=0.20 cm;
- interval duration=0.015625 day;
- max retries=8;
- worker_count=1.

The sixteen unique combinations of four initial heads and four forcing
perturbations were tested over two consecutive intervals.

## Interval A

All 16/16 origins:

- completed;
- committed;
- advanced to revision 1;
- reached t=0.015625 day;
- published complete mass accounting.

Aggregate interval-A retry count:
`27`.

Thus the interval-B blocker does not originate from an invalid initial
construction or failed first commit.

## Interval B

14/16 origins complete and commit normally.

Exactly two origins fail:

### Origin 10

- h0 = +2 cm;
- forcing delta = +0.035 cm/day;
- kernel status = 2 / transaction failed;
- completed = false;
- committed = false;
- attempts = 20;
- transaction retries = 16;
- accepted substeps before failure = 3;
- nonlinear iterations = 496;
- internal solver retries = 14;
- HeadCalc calls = 20;
- Jacobian builds = 496;
- linear solves = 502;
- backtracking attempts = 2899;
- final committed revision remains 1;
- final committed time remains 0.015625 day;
- failed result has no complete mass publication.

### Origin 11

- h0 = +2 cm;
- forcing delta = +0.05 cm/day;
- kernel status = 2 / transaction failed;
- completed = false;
- committed = false;
- attempts = 22;
- transaction retries = 19;
- accepted substeps before failure = 2;
- nonlinear iterations = 663;
- internal solver retries = 20;
- HeadCalc calls = 22;
- Jacobian builds = 663;
- linear solves = 665;
- backtracking attempts = 3698;
- final committed revision remains 1;
- final committed time remains 0.015625 day;
- failed result has no complete mass publication.

All other h0/forcing combinations complete interval B.

## Attribution

H1:
the blocker is localized to a strict subset of the sixteen origins.

Result:
SUPPORTED.

Only the two positive-forcing h0=+2 cm cases fail.

H2:
the failure is solver/solvability dominated rather than hard-mass rejection.

Result:
SUPPORTED.

Evidence:

- both failing cases consume very large nonlinear/backtracking work;
- they never reach a complete candidate for interval-B publication;
- committed revision/time remain exactly at the valid interval-A origin;
- the failed result has incomplete mass publication because the requested
  interval never completes, not because an otherwise complete candidate is
  rejected by a demonstrated hard-mass exceedance.

H3:
the failure occurs after a valid interval-A commit and is a continuation-domain
issue rather than invalid initial-state construction.

Result:
SUPPORTED.

## Important interpretation

The pZg23 blocker is not broad:

- all h0=-75 cases pass;
- all h0=-20 cases pass;
- the h0=+2 negative-forcing cases pass;
- all h0=+10 cases pass;
- only h0=+2 with +0.035/+0.05 cm/day fail in the second interval.

The pattern is therefore a localized wet/positive-forcing continuation
solvability problem.

This workunit does not establish the exact solver-internal criterion that
finally terminates the two failures. It establishes the failure location and
work signature needed for a separate repair/falsification study.

## Decision

Classification:

`QUALIFIED_PZG23_WET_POSITIVE_FORCING_SECOND_INTERVAL_SOLVABILITY_BLOCKER`.

SCHED02 remains correctly blocked.

No scheduler or temporal-budget change follows from this result.

## Successor boundary

A repair study, if pursued, must focus only on the two frozen failing origins.

It must not:

- widen the 0.20 cm temporal budget;
- relax hard mass;
- relax solver balance tolerances without independent causal evidence;
- change the fourteen passing origins;
- reinterpret the failure as a parallel-runtime defect.

The next useful question is whether the two failures are caused by a bounded
solver-local continuation mechanism that can be repaired without changing
accepted physics.
