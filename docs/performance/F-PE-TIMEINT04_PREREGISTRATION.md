# F-PE-TIMEINT04 preregistration — BDF2 nonlinear-path reconstruction

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_TRACE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@bd9a3fcc54000b9cdafee77f4a20e739a5abfaf2`

Parent authority:

- TIMEINT03 confirms fully implicit BDF2 is approximately second order in three complete smooth ladders;
- the sole B01 high-infiltration fine-dt ladder fails at step 25;
- MAXIT 8, 12, 16 and 24 all fail at that same step;
- a simple linear BDF2 head predictor does not rescue the route.

## Purpose

Reconstruct the exact nonlinear path at the transition from the last accepted BDF2 step to the first failed BDF2 step.

This is observation-only. No Newton, line-search, BDF2, tolerance or physical equation is changed.

## Frozen case

- material: B01;
- initial head: -100 cm;
- fixed top infiltration: 4 cm/day;
- bottom: prescribed zero flux;
- dt: 0.00125 d;
- horizon: 0.04 d;
- SWKIMPL=1;
- MAXIT=8;
- max backtracking=8;
- BALTOL02 unchanged.

Compare:

1. BE_KIMPL;
2. BDF2_KIMPL with one BE bootstrap.

Trace only steps 24 and 25.

## Per-iteration trace

Record without altering control flow:

- step index;
- temporal mode;
- nonlinear iteration index;
- pre-Newton residual quadratic norm `sumold`;
- pre-Newton residual infinity norm;
- min/max head;
- min/max water capacity;
- min/max conductivity;
- max absolute Newton update before line search;
- each attempted backtracking factor;
- resulting residual quadratic norm;
- resulting residual infinity norm;
- max absolute applied head change;
- whether line-search progress criterion passes;
- final convergence/nonconvergence at iteration end.

## Attribution classes

A. `LINE_SEARCH_REJECTION_STALL`
- raw Newton direction exists and trial residual can decrease only at progressively small factors or never passes the current progress test.

B. `NEWTON_RESIDUAL_STAGNATION`
- accepted trial updates occur but residual norms stop decreasing materially across iterations.

C. `UPDATE_CRITERION_STAGNATION`
- balance residual is small but pressure-head update criterion remains controlling.

D. `JACOBIAN_DIRECTION_FAILURE`
- full and backtracked steps systematically increase the residual from the first failing iteration.

E. `OTHER_NONLINEAR_PATHOLOGY`
- none of the above cleanly describes the trace.

## Decision boundary

TIMEINT04 P0 does not authorize a solver modification.

After trace exposure, at most one separately preregistered globalization candidate family may be opened, selected from the observed failure mechanism.

No production source changes.
