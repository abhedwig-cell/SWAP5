# F-PE-KIMPL-DYNTOP01 preregistration — fully implicit dynamic-top nonlinear-path attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_DIAGNOSTIC_RESULTS`

Canonical authority:

`integration/f-ci-canonical@199566655db5b13483194e16bb81a154f6fc2547`

Parent authority:

- TIMEINT12 qualifies the fully implicit dynamic-top surface-head derivative;
- TIMEINT12A shows fully implicit BE completes only 6/12 MOIST/WET/POND cases and fails the frozen work gates;
- fixed-flux fully implicit execution was previously robust.

## Question

Why does SWKIMPL=1 lose nonlinear robustness specifically when composed with dynamic top?

This is solver/operator attribution. It is not a timestep-policy study and cannot change TIMEINT12A qualification.

## Primary diagnostic cases

Use two early failures:

- B01/WET, KIMPL failure at outer step 7;
- O14/WET, KIMPL failure at outer step 1.

For each, compare:

1. failing KIMPL step;
2. same outer step under KLAG;
3. previous successful KIMPL step when available.

Fixed dt remains 0.005 d.

## Per-Newton trace

Record, without changing equations or solver decisions:

- outer step;
- Newton iteration;
- top pressure head;
- ponding depth;
- boundary route/regime;
- top-node conductivity;
- top-face conductivity;
- dK/dh at top;
- dHsurf/dh_top;
- max absolute residual;
- residual norm;
- max absolute Newton update;
- backtracking count / accepted line-search scale where available;
- local/total balance convergence indicators.

## Attribution classes

Classify the earliest divergence into one of:

A. `JACOBIAN_SIGN_OR_SCALE`
B. `BOUNDARY_ROUTE_DISCONTINUITY`
C. `DKDH_STIFFNESS`
D. `LINE_SEARCH_GLOBALIZATION`
E. `BALANCE_TOLERANCE_INTERACTION`
F. `ITERATION_BUDGET_ONLY`
G. `OTHER_<explicit>`

## Follow-up rules

No repair is allowed before attribution.

If evidence points to a Jacobian inconsistency, first verify the relevant derivative against finite differences.

If evidence points to globalization/line search while the Jacobian is locally correct, open a separately preregistered globalization study.

If merely increasing MAXIT would complete the same monotonically converging path, classify as iteration-budget-only, but do not retroactively qualify TIMEINT12A.

## Production boundary

Test-only instrumentation. No production source change.
