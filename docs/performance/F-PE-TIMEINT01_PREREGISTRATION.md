# F-PE-TIMEINT01 preregistration — Richards temporal-discretization reconstruction

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULT`

Canonical authority:

`integration/f-ci-canonical@bc365f8d24fb1854ee1484a4f6f9dcc5bc3944fb`

Parent authority:

- TIMEARCH01-11: timestep control architecture separated and production seams established;
- TIMEARCH12-17: heuristic AUTO_REFERENCE controllers rejected after blind validation;
- DYNERR01: dynamic-top endpoint defect indicator not predictive enough;
- BALTOL02: dt-scaled balance floor admitted.

## Purpose

Reconstruct the exact current temporal discretization of the Reference Richards solve and assess modern adaptive integration options before any further controller tuning.

No production timestep behavior changes in TIMEINT01.

## Questions

1. What discrete-in-time equation is solved by current Reference SWKIMPL=0?
2. Which terms are evaluated at the accepted origin and which at the candidate endpoint?
3. What formal temporal order should be expected in smooth fixed-regime operation?
4. What happens to effective order at dynamic-top regime transitions?
5. Which modern schemes can supply a mathematically grounded local error estimate at acceptable nonlinear-solve cost?
6. What state/history must become transactionally committed for those schemes?
7. Which candidate deserves an executable successor study?

## Scope boundary

Primary reconstruction:

- SWKIMPL=0;
- current Reference Richards route;
- dynamic-top and fixed-flux top boundaries;
- current BALTOL02 floor;
- no macropore temporal redesign;
- no SWKIMPL=1 inference.

## Candidate schemes to assess

A. current semi-implicit one-step method with step doubling;

B. variable-step BDF2 with first-order fallback/bootstrap;

C. two-stage SDIRK / embedded implicit Runge-Kutta family;

D. defect/error estimation around the current one-step method without extra nonlinear solves.

Assessment criteria:

- temporal order;
- extra nonlinear solves per accepted interval;
- robustness at boundary regime switches;
- compatibility with current Jacobian/provider architecture;
- committed-history requirements;
- rollback complexity;
- compatibility with event clipping and variable dt;
- ability to provide a local error estimate;
- expected performance potential.

## Advancement rule

TIMEINT01 may recommend a successor only when:

1. the current discrete equation is source-derived explicitly;
2. the formal-order claim is bounded by actual evaluation semantics;
3. regime-switch limitations are explicit;
4. candidate solve costs are compared honestly;
5. no option is selected solely because it is higher order;
6. the selected option has a plausible path to <=1 additional nonlinear solve per accepted step on average, or a strong reason why higher cost is still justified.

Possible outcomes:

- `QUALIFIED_BDF2_SUCCESSOR`;
- `QUALIFIED_EMBEDDED_IE_SUCCESSOR`;
- `QUALIFIED_SDIRK_SUCCESSOR`;
- `QUALIFIED_DEFECT_ESTIMATOR_SUCCESSOR`;
- `CLOSED_NO_MODERN_INTEGRATOR_CANDIDATE`.

