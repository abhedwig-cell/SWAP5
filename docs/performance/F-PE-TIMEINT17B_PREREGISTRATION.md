# F-PE-TIMEINT17B preregistration — dynamic-top endpoint failure versus route-event attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent authority:

- TIMEINT17A: `BLOCKED_TIMEINT17A_BANK_NOT_SAME_ROUTE`;
- TIMEINT17A2: `BLOCKED_TIMEINT17A2_ROUTE_MARGIN_INSUFFICIENT`.

Canonical base:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

## Purpose

Resolve the ambiguity left by TIMEINT17A/A2.

The current shared harness maps several distinct terminal mechanisms onto:

- `ELIGIBLE=0`;
- `TRANSITION_STEP=n`.

TIMEINT17B determines whether the dominant blocker is:

1. a genuine dynamic-top route transition; or
2. endpoint nonlinear-solve failure before route semantics can be assessed.

TIMEINT17B is attribution only.

It does not qualify event localization, same-route order, or production behavior.

## Frozen numerical mechanism

No numerical mechanism changes.

Reuse exactly the TIMEINT17A/TIMEINT17A2 candidate:

- TIMEINT16C current-step provider-consistent TG staging;
- exact benchmark theta/head projection;
- predicted K fixed inside the endpoint solve;
- current dynamic-top endpoint provider;
- MAXIT = 8;
- max backtracking = 8;
- identical balance/head/ponding tolerances;
- zero bottom flux;
- no source/sink;
- no macropores.

No timestep or forcing tuning.

## Primary bank

Use the exact frozen TIMEINT17A2 route-margin bank.

Materials:

- B01;
- B12;
- O05;
- O14.

Routes:

- FLUX;
- HEAD;
- RUNOFF.

Horizon and dt ladder remain:

- H = 0.001 d;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d.

Fixture derivation remains exactly TIMEINT17A2.

No new bank is introduced.

## Required terminal classes

Every candidate trial must terminate into exactly one explicit attribution class.

### COMPLETE_SAME_ROUTE

All requested intervals complete and all origin/predictor/endpoint/accepted routes remain the frozen target route.

### ORIGIN_ROUTE_MISMATCH

The accepted origin is already not on the frozen target route.

### FORWARD_PREDICTOR_ROUTE_MISMATCH

The explicit current-step theta/P predictor lies on another physical route before the endpoint solve is attempted.

### ENDPOINT_SOLVE_FAILURE

The BE-like endpoint nonlinear solve does not converge under the frozen numerical envelope.

Record:

- solve status;
- nonlinear iterations;
- backtracking attempts;
- Jacobian builds;
- linear solves;
- accepted-origin route;
- forward-predictor route;
- accepted physical state before the failed trial.

No route transition may be inferred from a failed endpoint solve.

### ENDPOINT_ROUTE_MISMATCH

The endpoint solve converges, but the dynamic-top provider classifies the converged BE predictor endpoint on another route.

### ENDPOINT_SURFACE_RATE_MISMATCH

The endpoint route is the target route, but the instantaneous surface-rate reconstruction disagrees with the BE predictor ponding derivative beyond the existing 5e-8 cm/d authority.

### ACCEPTED_TG_ROUTE_MISMATCH

The endpoint predictor is same-route, but the final accepted TG theta/P state lies on another route.

### NEGATIVE_SURFACE_STORAGE

The predicted or accepted TG ponding storage becomes negative beyond the existing tolerance.

### CONSTITUTIVE_FAILURE

Theta/head projection or predicted K becomes invalid/nonfinite.

No generic `ELIGIBLE=0` is sufficient authority in TIMEINT17B.

## Comparator

Run the identical TIMEINT17A2 fixtures with KLAG Backward Euler.

Record the same explicit route and solve outcome classes where applicable.

Comparator questions:

1. Does KLAG complete where TG endpoint solve fails?
2. Does KLAG exhibit the same route change at comparable accepted time?
3. Is failure candidate-specific or a shared dynamic-top fixture/property?

KLAG remains diagnostic only.

## Metrics

For every material/route/dt run record:

- terminal class;
- first terminal step;
- origin route;
- forward-predictor route;
- BE endpoint route if solved;
- accepted TG route if formed;
- endpoint solve status;
- NL/BACK/JAC/LIN counts on terminal trial;
- maximum accepted physical ledger before termination;
- cumulative accepted physical ledger;
- last accepted top head/theta/P;
- predicted K min/max;
- surface-rate residual where available.

Aggregate:

- class counts by route family;
- class counts by material;
- class counts by dt;
- TG versus KLAG completion matrix;
- TG-only endpoint failures;
- shared endpoint failures;
- genuine route-mismatch counts with converged endpoint;
- accepted-TG-only route changes.

## Frozen attribution decisions

### EVENT_DOMINANT

Classify:

`TIMEINT17B_EVENT_DOMINANT`

only if:

1. >=75% of non-complete candidate runs terminate through an explicit route-mismatch class with a converged endpoint or accepted TG state;
2. endpoint-solve failure is <=25% of non-complete runs;
3. at least one onset and one release/runoff route transition is represented by converged states.

Consequence:

event localization becomes scientifically reachable and may be preregistered separately.

### ENDPOINT_SOLVER_DOMINANT

Classify:

`TIMEINT17B_ENDPOINT_SOLVER_DOMINANT`

if endpoint-solve failure is >50% of non-complete candidate runs.

Consequence:

do not open event localization. Route the work to endpoint nonlinear-path attribution/repair first.

### MIXED_BLOCKER

Classify:

`TIMEINT17B_MIXED_ENDPOINT_AND_EVENT_BLOCKER`

if neither mechanism meets the dominance thresholds.

Consequence:

preserve both blocker classes and do not claim event qualification.

### SHARED_DYNAMIC_TOP_BLOCKER

If TG and KLAG fail the same fixtures at comparable first terminal steps in >=75% of TG endpoint failures:

`TIMEINT17B_SHARED_DYNAMIC_TOP_BLOCKER`.

This may be combined with endpoint-solver dominance as a secondary attribution label, not as a replacement for the primary classification.

## Mass rule

Only accepted physical intervals contribute to the mass diagnostics.

Failed/rejected terminal trials contribute zero published mass and must not mutate accepted state.

Maximum accepted ledger remains <=5e-8 cm.

A mass failure is a separate blocker:

`BLOCKED_TIMEINT17B_ACCEPTED_MASS`.

## Stop rules

TIMEINT17B does not:

- alter MAXIT;
- alter backtracking limits;
- alter balance/head/ponding tolerances;
- shorten horizon;
- change rain or initial states;
- localize events;
- split intervals;
- change K predictor;
- use SWKIMPL=1 rescue;
- tune DTMIN/DTMAX;
- introduce AUTO/LTE work.

No production `src/**` change.

## Production boundary

Research attribution only.

`LEGACY_NUMERICS` remains production default.
