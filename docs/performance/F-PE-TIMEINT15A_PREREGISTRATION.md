# F-PE-TIMEINT15A preregistration — Rannacher startup attribution for trapezoidal Richards

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@a5f127e2f42329914826a835d760102be6fee71f`

Parent:

F-PE-TIMEINT15 P0.

## Question

Is the observed approximately first-order TR_KIMPL convergence caused primarily by the abrupt t=0 forcing/initial compatibility discontinuity rather than by the conservative trapezoidal Richards formulation itself?

## Frozen candidate

Use fully implicit conductivity only.

For nominal step h:

1. cover the first nominal interval [0,h] using two Backward-Euler substeps of h/2;
2. from t=h onward use the unchanged TIMEINT15 trapezoidal formulation with step h;
3. no further smoothing steps;
4. no tolerance, MAXIT, conductivity, storage or flux-formula changes.

This is the classical Rannacher-startup pattern applied only at the known forcing start discontinuity.

The two BE half-step physical ledgers are evaluated individually with the unchanged physical mass identity.

## Bank

Same P0 smooth bank:

- B01 rain 2 and 4 cm/day;
- O05 rain 2 and 4 cm/day;
- horizon 0.04 d;
- nominal h:
  - 0.010;
  - 0.005;
  - 0.0025;
  - 0.00125 d.

## Metrics

- completion;
- terminal top/mid/bottom head;
- refined top-head order;
- max per-substep/step physical ledger;
- cumulative physical ledger;
- nonlinear iterations/backtracks/Jacobians/linear solves;
- total work normalized by the nominal number horizon/h.

## Frozen gates

TIMEINT15A supports the startup-attribution hypothesis only if:

1. 4/4 ladders complete;
2. median refined top-head order >=1.6;
3. >=3/4 individual refined top-head orders >=1.5;
4. max physical ledger <=5e-8 cm;
5. cumulative physical ledger <=5e-8 cm;
6. median work per nominal interval <=1.20 times fully implicit BE;
7. no retry/nonfinite pathology.

If these pass, classify:

`TRAPEZOIDAL_SECOND_ORDER_WITH_EVENT_STARTUP_CONFIRMED`.

If order remains <1.6, classify:

`TRAPEZOIDAL_ORDER_REDUCTION_NOT_RESCUED_BY_RANNACHER_STARTUP`.

## Consequence

A positive result means a modern one-step integrator must carry an explicit hard-event restart/startup rule.

It does not yet qualify dynamic top or predicted conductivity.

A negative result closes trapezoidal/CN as primary TIMEINT successor and leaves the preregistered Thomas-Gladwell/local-extrapolation family as the next route.

## Production boundary

No production source change.
