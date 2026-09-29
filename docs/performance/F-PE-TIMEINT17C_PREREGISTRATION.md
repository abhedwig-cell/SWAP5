# F-PE-TIMEINT17C preregistration — in-Newton dynamic-top route-path attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent authority:

- TIMEINT17B primary: `TIMEINT17B_ENDPOINT_SOLVER_DOMINANT`;
- TIMEINT17B secondary: `TIMEINT17B_SHARED_DYNAMIC_TOP_BLOCKER`.

Canonical base:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

## Question

Why does the shared dynamic-top endpoint solve fail before a converged route event can be classified?

TIMEINT17C distinguishes:

1. endpoint failure while the dynamic-top provider stays on one route; from
2. endpoint failure accompanied by route switching/chatter inside Newton/backtracking evaluations.

## Frozen numerical mechanism

No numerical behavior changes.

Reuse the exact TIMEINT17A2 bank and endpoint solves:

- identical states, rain and dt;
- identical TIMEINT16C TG staging;
- identical KLAG comparator;
- identical dynamic-top provider;
- identical MAXIT=8;
- identical backtracking limit=8;
- identical balance/head/ponding tolerances;
- identical K handling;
- identical physical ledger.

The only change is a test-only logging wrapper around the existing dynamic-top provider.

The wrapper delegates every evaluation to the same provider and returns the result unchanged.

## Logged sequence

For every dynamic-top provider evaluation inside a requested trial record, in order:

- evaluation index;
- candidate top pressure head;
- candidate top water content;
- candidate ponding depth;
- returned status;
- returned regime;
- returned route string;
- actual top flux;
- returned candidate ponding depth;
- runoff depth;
- surface-head derivative availability and value.

The log must not alter provider state or candidate state.

## Route code

Map returned routes to:

- FLUX: route contains `surface-flux`;
- HEAD: route contains `ponded-head` and not `linear-runoff`;
- RUNOFF: route contains `linear-runoff`;
- ATMOSPHERIC: route contains `atmospheric-head`;
- OTHER: any remaining route.

## Per-terminal-trial diagnostics

For the first non-complete terminal trial of every A2 run record:

- terminal reason from TIMEINT17B;
- total provider evaluations;
- distinct route codes observed;
- number of consecutive route-code transitions;
- first route;
- last route;
- minimum/maximum candidate ponding;
- minimum/maximum candidate top head;
- minimum/maximum actual top flux;
- count of provider-unavailable evaluations;
- count of FLUX/HEAD/RUNOFF/ATMOSPHERIC evaluations.

## Frozen attribution classes

### STATIC_ROUTE_ENDPOINT_FAILURE

The endpoint solve fails and all available provider evaluations remain on one route code.

### INTERNAL_ROUTE_SWITCHING_ENDPOINT_FAILURE

The endpoint solve fails and at least one consecutive provider evaluation changes physical route code.

### PROVIDER_AVAILABILITY_FAILURE

The endpoint solve fails and at least one provider evaluation is unavailable or OTHER due to unavailable/invalid provider state.

### NON_ENDPOINT_TERMINAL

TIMEINT17B terminal reason is not `ENDPOINT_SOLVE_FAILURE`.

## Aggregate decisions

Use all 48 A2 TG runs and all 48 matched KLAG runs.

### ROUTE_SWITCH_DOMINANT

Classify:

`TIMEINT17C_IN_NEWTON_ROUTE_SWITCH_DOMINANT`

if >=75% of TG endpoint-solve failures are `INTERNAL_ROUTE_SWITCHING_ENDPOINT_FAILURE`.

### STATIC_ROUTE_SOLVER_DOMINANT

Classify:

`TIMEINT17C_STATIC_ROUTE_SOLVER_DOMINANT`

if >=75% of TG endpoint-solve failures are `STATIC_ROUTE_ENDPOINT_FAILURE`.

### PROVIDER_AVAILABILITY_DOMINANT

Classify:

`TIMEINT17C_PROVIDER_AVAILABILITY_DOMINANT`

if >=50% of TG endpoint-solve failures contain provider-unavailable evaluations.

### MIXED_ROUTE_PATH_BLOCKER

Otherwise:

`TIMEINT17C_MIXED_ROUTE_PATH_BLOCKER`.

## TG versus KLAG secondary attribution

For matched fixtures compare whether both methods show the same route-path class.

If >=75% of TG endpoint failures have the same route-path class in KLAG, add:

`TIMEINT17C_SHARED_ROUTE_PATH_BLOCKER`.

If TG route switching is materially more common than KLAG, preserve a TG-specific composition signal.

No solver repair follows automatically from this comparison.

## Scientific consequences

If route-switch dominant:

- event surfaces are being encountered *inside* the nonlinear endpoint solve;
- do not increase MAXIT as first response;
- next work must investigate event-aware nonlinear decomposition or route-frozen endpoint subsolves.

If static-route solver dominant:

- event semantics are not the immediate cause;
- next work must attribute residual/Jacobian/convergence behavior inside one route before event localization.

If provider availability dominant:

- repair provider contract/test composition before temporal conclusions.

## Mass and transaction invariants

Failed endpoint trials publish no state and no mass.

Only previously accepted intervals contribute to mass diagnostics.

Logging must not mutate accepted or candidate state.

No hidden commit during provider evaluations.

## Stop rules

TIMEINT17C does not:

- change MAXIT;
- change backtracking;
- change tolerances;
- change timestep;
- change forcing;
- change K staging;
- freeze a route artificially;
- localize or split events;
- modify production `src/**`.

## Production boundary

Research attribution only.

`LEGACY_NUMERICS` remains production default.
