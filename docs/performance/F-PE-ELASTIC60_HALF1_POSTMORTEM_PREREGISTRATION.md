# F-PE-ELASTIC60 — persistent half1 failure postmortem preregistration

Date: 2026-09-30

Status: PREREGISTERED_OBSERVATION_ONLY

Parent authority:
`F-PE-ELASTIC59 — QUALIFIED_PERSISTENT_HALF1_ORACLE_SOLVABILITY_GAP`

Parent postimage:
`research/f-pe-elastic59-unpaired-oracle-attribution@57e2daff49929b8f2507c08d07b95d380d6b751a`

Canonical authority:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Question

What numerical mechanism prevents the verification half1 solve from converging
in the six ELASTIC59 cases even when the oracle-only iteration budget is raised
to 128?

## Frozen cases

Exactly the six ELASTIC59 cases:
- profile 8016;
- h0 = -20 cm;
- delta = +0.035 and +0.05 cm/day;
- OFF, FIXED_1E6 and GENERATED;
- accepted full-step dt = 0.0009765625 day.

Oracle half1 step duration:
`0.00048828125 day`.

The production-shaped full solve remains unchanged.

## Oracle budgets

Replay half1 with max_iterations:
- 16;
- 32;
- 64;
- 128.

All other numerical and physical settings remain unchanged.

## Postmortem observables

After every half1 solve record from the public Reference workspace and solve
result:

- solve status and route;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- alternative-solver calls;
- internal retries;
- maximum absolute final residual;
- node of maximum residual;
- sum of final residuals;
- L2 residual norm;
- maximum absolute last Newton head change
  `|h_final - old_head_last_iteration|`;
- node of that maximum change;
- final min/max pressure head;
- count of nodes with h >= 0;
- min/max constitutive capacity;
- min/max conductivity.

The final residual/head-change observables are diagnostic snapshots only and
must not be interpreted as an accepted physical state.

## Attribution classes

RESIDUAL_STAGNATION:
- residual remains materially above tolerance as max_iterations increases and
  does not improve by at least one order of magnitude from maxit16 to maxit128.

HEAD_CHANGE_STAGNATION:
- residual is near tolerance but last Newton head change remains above the
  configured head convergence criterion.

BACKTRACKING_DOMINATED:
- backtracking attempts scale materially faster than nonlinear iterations and
  remain active at maxit128.

ALTERNATIVE_SOLVER:
- alternative linear solver is invoked.

MIXED:
- more than one mechanism remains material.

## Hypotheses

H1. Half1 failure is residual/backtracking stagnation rather than insufficient
iteration count.

H2. The mechanism is regime-independent because the initial/trajectory state
remains unsaturated over the relevant part of the solve.

H3. No hidden alternative-solver or internal-retry path explains the failure.

## Gates

A1. Exactly 24 arms execute.

A2. Full solve semantics remain invariant across oracle-budget arms.

A3. O0/O2 postmortem outputs agree.

A4. Every half1 terminal diagnostic is finite.

A5. The persistent nonconvergence pattern from ELASTIC59 is reproduced exactly.

A6. Zero `src/**` production changes.

## Decision

ELASTIC60 is observational only.

No solver tolerance, line-search policy, constitutive law, iteration limit or
production acceptance policy is changed here.
