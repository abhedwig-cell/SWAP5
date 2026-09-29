# F-PE-TIMEINT17B preregistration — dynamic-top endpoint failure versus route-event attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

Parent authorities:

- TIMEINT16: `QUALIFIED_PROVIDER_CONSISTENT_TG_KPRED_STAGE`.
- TIMEINT17A: `BLOCKED_TIMEINT17A_BANK_NOT_SAME_ROUTE`.
- TIMEINT17A2: `BLOCKED_TIMEINT17A2_ROUTE_MARGIN_INSUFFICIENT`.

## Purpose

TIMEINT17A and A2 both fail the same-route bank denominator.

The current harness does not uniquely distinguish:

- physical route transition;
- endpoint nonlinear solve failure;
- retention-domain failure;
- negative predicted or accepted ponding;
- unavailable endpoint dynamic-top result.

TIMEINT17B is diagnostic only.

It determines whether the dominant obstacle occurs **before** route-event semantics can be meaningfully tested, or whether genuine route events dominate the frozen banks.

It does not qualify event localization.

## Numerical mechanism

Hold fixed exactly the TIMEINT17A/A2 TG mechanism and numerical settings.

No changes to:

- current-step provider-consistent predicted K;
- TG moisture update;
- TG ponding update;
- dynamic-top provider;
- MAXIT=8;
- backtracking envelope;
- balance tolerances;
- constitutive inverse;
- mass ledger.

No rescue arm.

## Banks

Run both already frozen banks:

### A bank

Original TIMEINT17A fixtures and dt ladder.

### A2 bank

Formula-derived TIMEINT17A2 fixtures and dt ladder.

Do not add cases.

## Explicit terminal-reason contract

Every requested TG run must terminate with exactly one of:

- `COMPLETE_SAME_ROUTE`;
- `ORIGIN_ROUTE_MISMATCH`;
- `FORWARD_PREDICTOR_ROUTE_MISMATCH`;
- `ENDPOINT_SOLVE_FAILED`;
- `ENDPOINT_TOP_UNAVAILABLE`;
- `ENDPOINT_PROVIDER_ROUTE_MISMATCH`;
- `ENDPOINT_INSTANTANEOUS_ROUTE_MISMATCH`;
- `ACCEPTED_ROUTE_MISMATCH`;
- `PREDICTED_RETENTION_DOMAIN_FAILED`;
- `PREDICTED_PONDING_NEGATIVE`;
- `ACCEPTED_RETENTION_DOMAIN_FAILED`;
- `ACCEPTED_PONDING_NEGATIVE`;
- `OTHER_EXPLICIT_FAILURE`.

A run may report earlier successful accepted steps, but the first terminal reason owns the run.

A nonlinear solve failure must never be reported as a route mismatch.

## Failure-step diagnostics

At the terminal requested interval record:

- step index;
- solver status;
- nonlinear iterations;
- backtracking attempts;
- origin route;
- forward predictor route;
- endpoint provider route, when available;
- endpoint instantaneous route, when available;
- accepted route, when available;
- origin top head and ponding;
- forward-predictor top head and ponding;
- endpoint top head and ponding, when available;
- accepted TG top head and ponding, when available;
- predicted top-node K;
- native balance residual when available.

## KLAG comparator

For the same frozen fixture, run KLAG BE with the identical requested dt.

Comparator classifications:

- KLAG completes same route;
- KLAG route mismatch;
- KLAG solve failure.

This is attribution only.

If TG endpoint solve fails while KLAG completes the identical route/fixture, record `TG_SPECIFIC_ENDPOINT_ROBUSTNESS_SIGNAL`.

If both fail before a route transition is established, record `SHARED_DYNAMIC_TOP_SOLVER_SIGNAL`.

No comparator result changes the TG classification automatically.

## Aggregate frozen classifications

Let ineligible TG runs be all runs not ending `COMPLETE_SAME_ROUTE`.

### Solver dominated

If >=50% of ineligible runs terminate `ENDPOINT_SOLVE_FAILED`:

`TIMEINT17_BLOCKER_ENDPOINT_SOLVER_DOMINATED`

### Route-event dominated

If >=75% of ineligible runs terminate on one of:

- ORIGIN_ROUTE_MISMATCH;
- FORWARD_PREDICTOR_ROUTE_MISMATCH;
- ENDPOINT_PROVIDER_ROUTE_MISMATCH;
- ENDPOINT_INSTANTANEOUS_ROUTE_MISMATCH;
- ACCEPTED_ROUTE_MISMATCH;

then:

`TIMEINT17_BLOCKER_ROUTE_EVENT_DOMINATED`

### Mixed

Otherwise:

`TIMEINT17_BLOCKER_MIXED_ENDPOINT_AND_EVENT`

## Decision consequences

### Endpoint-solver dominated

Do not open P1/P2 event localization.

Open a separate dynamic-top endpoint-robustness work unit. It may investigate composition/solver architecture but must not tune temporal error control or weaken physics.

### Route-event dominated

The parent P0 smooth-bank gate remains unqualified, but the evidence establishes that smooth-bank construction is structurally incompatible with these physically relevant dynamic trajectories.

TIMEINT17 may then open an **event-semantics research work unit**, not an admission work unit, to test whether exact known-time or endogenous splitting can recover correct physical transactions.

Any later event qualification still requires a separately preregistered rule for how the parent P0 prerequisite is replaced.

### Mixed

Stop TIMEINT17 admission.

Separate solver robustness from event semantics into distinct successors.

## Stop rules

TIMEINT17B does not:

- alter the A/A2 fixtures;
- alter dt/horizon;
- increase MAXIT;
- loosen balance/head/ponding tolerances;
- add retries beyond existing solver semantics;
- localize events;
- change production code;
- tune DTMIN/DTMAX;
- introduce variable-step TG;
- claim second-order dynamic-top qualification.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No default change.

`LEGACY_NUMERICS` remains production default.
