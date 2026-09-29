# F-PE-TIMEINT17C preregistration — shared dynamic-top endpoint nonlinear-path attribution and repair

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent authority:

- TIMEINT17B: `TIMEINT17B_ENDPOINT_SOLVER_DOMINANT`;
- secondary: `TIMEINT17B_SHARED_DYNAMIC_TOP_BLOCKER`.

Canonical base:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

## Purpose

Identify why the dynamic-top endpoint solve shared by TG and KLAG exhausts the frozen nonlinear/backtracking envelope before route-event semantics can be assessed.

TIMEINT17C is a nonlinear-path attribution and research-repair work unit.

It does not qualify event localization, temporal order, adaptive stepping or production admission.

## Frozen bank

Use only the frozen TIMEINT17A2 fixtures.

- B01, B12, O05, O14;
- FLUX, HEAD, RUNOFF;
- H = 0.001 d;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- A2 fixture derivation with dtop = 10 cm.

Primary endpoint attribution may use the first terminal interval only because TIMEINT17B established that all 48 TG fixtures terminate through endpoint solve failure.

## Frozen numerical envelope

Unchanged:

- MAXIT = 8;
- max backtracking = 8;
- existing balance/head/ponding tolerances;
- conductivity mean method 1;
- zero bottom flux;
- no sinks;
- no macropores.

No tolerance or iteration-limit rescue.

## Attribution arms

All arms are test-only and may not alter accepted physical semantics.

### C0 CURRENT_DYNAMIC

Authority control.

Use the current dynamic-top endpoint provider exactly as in TIMEINT17B.

Expected reference: endpoint failure on the frozen A2 requests.

### C1 ROUTE_FROZEN_DIAGNOSTIC

Freeze only the boundary-route algebra to the accepted-origin physical route during the endpoint nonlinear trial.

Requirements:

- keep the same current-step predicted K used by the endpoint solve;
- keep the same physical rain, previous ponding and surface parameters;
- evaluate the route-local residual continuously without allowing route reclassification during Newton;
- do not publish this trial as accepted physical behavior;
- do not change MAXIT/tolerances.

Purpose:

test whether route switching/nonsmooth route reclassification inside Newton is the dominant path blocker.

### C2 SURFACE_JACOBIAN_CONSISTENT

Apply the current physical dynamic-top route, but make the test-only top residual and its Newton derivative algebraically consistent with the same route-local surface equation and fixed predicted-K authority.

No finite-difference tuning and no altered physical flux law.

Purpose:

test residual/Jacobian consistency separately from route selection.

### C3 PONDING_STATE_CONSISTENT

Diagnostic only if C1/C2 do not explain the blocker.

Ensure the Newton candidate ponding variable used by the provider is the same candidate surface state represented in the residual/Jacobian, while previous accepted ponding remains immutable transaction state.

No mixing previous and candidate ponding in one derivative.

Purpose:

test surface-state ownership mismatch.

## Required diagnostics

For every arm and fixture record:

- solve status;
- NL/BACK/JAC/LIN;
- residual norm or native balance residual by nonlinear iteration if available;
- route observed by every provider evaluation;
- candidate top head;
- candidate ponding;
- actual top flux;
- surface-head derivative availability/value;
- predicted K top;
- accepted state remains unchanged for failed/diagnostic trials.

At minimum record terminal solve result and total route-switch count during Newton.

## Frozen decision rules

### ROUTE_SWITCHING_DOMINANT

Classify:

`TIMEINT17C_ROUTE_SWITCHING_DOMINANT`

if:

1. C0 fails on >=75% of frozen requests;
2. C1 converges on >=75% of the corresponding C0 failures;
3. C1 accepted-mass diagnostic for its converged route-local trial is within 5e-8 cm;
4. no tolerance/iteration change is used.

This opens a later event-consistent route-local endpoint formulation, not immediate event localization.

### JACOBIAN_CONSISTENCY_DOMINANT

Classify:

`TIMEINT17C_SURFACE_JACOBIAN_DOMINANT`

if C1 does not meet its recovery threshold but C2 converges on >=75% of corresponding C0 failures under the unchanged envelope.

### PONDING_OWNERSHIP_DOMINANT

Classify:

`TIMEINT17C_PONDING_STATE_OWNERSHIP_DOMINANT`

if C1/C2 do not recover >=75%, but C3 does.

### MIXED_NONLINEAR_PATH_BLOCKER

Classify:

`TIMEINT17C_MIXED_NONLINEAR_PATH_BLOCKER`

if no single frozen diagnostic arm recovers >=75% of C0 failures.

### INVALID_DIAGNOSTIC

Any diagnostic arm that changes physical forcing, tolerance, MAXIT, accepted mass semantics or predicted-K authority is invalid and cannot support attribution.

## Research repair boundary

A positive diagnostic attribution may justify a separate repair candidate in TIMEINT17C only if:

- it is algebraically derived from the existing physical boundary law;
- it retains transaction semantics;
- accepted physical mass remains exact;
- it does not change route event definitions.

Any production source change requires a later separately preregistered qualification/admission step.

## Stop rules

No:

- event bisection;
- known-time event qualification;
- variable-step TG;
- LTE/AUTO work;
- MAXIT change;
- backtracking change;
- balance/head/ponding tolerance change;
- forcing or fixture change;
- SWKIMPL=1 rescue.

## Production boundary

Research attribution only.

No production default change.

`LEGACY_NUMERICS` remains production default.
