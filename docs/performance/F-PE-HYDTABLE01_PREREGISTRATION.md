# F-PE-HYDTABLE01 — bounded tabulated conductivity and directional derivative representation

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Parent:
`F-PE-PROFILE07 / PR #658`

Parent head:
`680d973178bc5eb15b6300a1186214fb9f8d22f5`

Branch:
`work/f-pe-hydtable01-conductivity-representation`

## Motivation

PROFILE07 finds that:

- the Reference / transaction route still owns roughly 85-91% of the clean repeated application fixture;
- accepted internal solves already converge in one nonlinear iteration in that fixture;
- raw tridiagonal work is small relative to constitutive evaluation;
- A2C already qualifies the practical tolerance frontier;
- c=0.65 already removes half the repeated temporal retries relative to c=0.50;
- the qualified direct-retention representation still yields material repeated-solver gain;
- direct-retention accelerates water-content-only and capacity-only requests, but conductivity-containing requests still use the analytical MvG provider;
- smooth-branch directional dK/dh also remains analytical.

This leaves a specific, complementary target: reduce the cost of K(h) and the smooth directional conductivity derivative without changing physical meaning or solve ownership.

## Question

Can a bounded shared lookup representation of MvG conductivity and smooth-branch dK/dh reduce accepted-solve and directional cost while preserving the solver trajectory closely enough that total solve effort does not increase?

## Research boundary

HYDTABLE01 begins research-only.

No production selection, default change or `src/**` admission is authorized by P0.

Initial implementation belongs under tests/research or tests/fpe support.

Production code may only be touched in a later explicitly preregistered admission phase after the representation and solver-level gates pass.

## Candidate representation

The initial candidate must:

- tabulate conductivity `K(h)`;
- provide a consistent smooth-branch `dK/dh` from the same local representation when requested;
- use a transformed head coordinate suitable for the many-decade dry range rather than a naive uniform h grid;
- preserve nonnegative conductivity;
- preserve monotonic K with wetting on qualified smooth branches;
- fall back to the analytical provider:
  - outside the qualified table domain;
  - at or sufficiently near constitutive branch boundaries;
  - where interpolation validity cannot be established;
- share immutable table state by hydraulic material rather than construct it per column.

The first candidate is piecewise interpolation in a monotone transformed coordinate. P0 must compare at least linear and a smooth monotonic option if the latter can be implemented without hidden overshoot.

## Scope relationship to direct-retention

HYDTABLE01 is complementary to direct-retention.

It must explicitly benchmark:

1. analytical baseline;
2. conductivity table without direct-retention;
3. qualified direct-retention plus analytical K;
4. qualified direct-retention plus conductivity table.

Do not claim the gain from (2) and the historical AHL gain are additive without same-head combined measurement.

## P0 offline matrix

Materials:

- B01;
- B12;
- O05;
- O14.

State coverage:

- wet;
- mid;
- dry;
- logarithmically distributed interior head points;
- dense points around every relevant branch/fallback boundary;
- extreme-dry and near-saturated guards.

For each valid smooth point measure:

- analytical K;
- table K;
- absolute K error;
- relative K error, with an explicit small-K denominator policy;
- analytical dK/dh;
- table dK/dh;
- absolute and relative derivative error;
- positivity;
- monotonicity;
- continuity between interpolation cells;
- analytical fallback activation.

## P0 performance measurements

Measure separately:

- K-only point evaluation;
- K+dK/dh evaluation;
- full constitutive request where K participates;
- table construction cost;
- amortized evaluation at 1, 1,000 and 10,000 logical columns under shared ownership.

Use replicated medians. Table construction time is setup cost and must not be mixed into repeated runtime.

## Initial acceptance envelope

P0 is exploratory. It must produce a Pareto frontier rather than tune to one hidden test set.

A representation may proceed to solver qualification only when all of the following hold on a frozen holdout set:

- no negative K;
- no monotonicity violation on smooth branches;
- no branch-boundary interpolation across analytically distinct regimes;
- bounded K and dK/dh error with thresholds frozen before holdout;
- repeated K-containing evaluation is measurably faster than analytical evaluation;
- setup cost is demonstrably amortizable under shared ownership.

The numerical error thresholds themselves are to be frozen after calibration and before holdout, not selected retrospectively from holdout performance.

## P1 solver qualification

Only after P0 freeze.

Use at minimum the existing B01/B12/O05/O14 wet/mid/dry matrix and compare:

- convergence/completion;
- nonlinear iterations;
- backtracking;
- accepted substeps;
- retries;
- mass residual;
- pressure-head trajectory;
- water-content trajectory;
- bottom flux;
- cumulative bottom exchange;
- runtime.

A table that is faster per evaluation but causes enough extra nonlinear work to erase the wall-clock gain fails the performance objective.

## P2 combined practical stack

If P1 passes, evaluate the same frozen table with:

- direct-retention enabled where qualified;
- A2C enabled where qualified;
- temporal c=0.65 enabled in the bounded production-shaped groundwater profile;
- tangent cache unchanged.

This is the first stage allowed to estimate the incremental gain over the fastest already qualified stack.

## P3 coupled qualification

Only after P2 passes.

Use the live SWAP + MODFLOW6 authority route and require:

- no new SWAP trial-failure class;
- per-cell conjunctive convergence;
- mass/publication preservation;
- exactly-once publication;
- bounded endpoint and cumulative exchange deviation under a separately frozen practical acceptance envelope;
- replicated wall-clock improvement.

## Non-targets

HYDTABLE01 does not:

- retune c=0.65;
- loosen A2C beyond 1e-8;
- replace Richards with a surrogate or ROM;
- change transaction ownership;
- change MODFLOW coupling equations;
- change water-balance semantics;
- reopen the rejected APPROX04 same-origin response surrogate;
- optimize raw tridiagonal algebra.

## Decision rule

HYDTABLE01 proceeds in order:

`CALIBRATE -> FREEZE -> HOLDOUT -> SOLVER -> COMBINED -> COUPLED -> ADMIT`

Failure at any gate closes or redirects the workunit. It does not silently relax the gate.

## Closure

HYDTABLE01 closes with one of:

- `CLOSED_REJECTED`;
- `CLOSED_RESEARCH_QUALIFIED_NO_PRODUCTION_ADMISSION`;
- `CLOSED_PRODUCTION_ADMITTED_BOUNDED_K_TABLE`.

No production admission is implied by preregistration.
