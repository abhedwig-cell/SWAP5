# F-PE-TIMEINT02A preregistration — SWKIMPL=1 failure attribution

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent: F-PE-TIMEINT02.

## Trigger

In the first BDF2 operator-consistency matrix:

- BE_KLAG completed 4/4 cases and remained first order;
- BDF2_KLAG completed 3/4 and did not approach second order;
- BE_KIMPL failed every planned case/dt;
- BDF2_KIMPL therefore could not be interpreted.

The fully implicit conductivity route is thus blocked before BDF2-specific conclusions can be drawn.

## Question

Is SWKIMPL=1 failure in the explicit fixed-flux provider fixture primarily insufficient nonlinear iteration allowance, or is the route structurally nonconvergent in this test envelope?

## Frozen attribution matrix

Use BE storage only.

Hydraulic/forcing cases:

- B01, rain 2 cm/day;
- B01, rain 4 cm/day;
- O05, rain 2 cm/day;
- O05, rain 4 cm/day.

Fixed dt:

- 0.005 d;
- 0.00125 d.

MAXIT arms:

- 8;
- 16;
- 32.

max_backtracking remains 8.

All other solver tolerances and provider semantics unchanged.

## Recorded failure detail

For every run record:

- completion;
- first failing accepted-step index;
- solver status;
- retry_advised flag;
- nonlinear iterations;
- backtracks;
- Jacobian builds;
- linear solves.

## Decision

If no run completes at MAXIT=32:

`SWKIMPL1_PROVIDER_ROUTE_STRUCTURAL_BLOCKER`.

If some cases complete only with higher MAXIT:

classify as nonlinear-effort sensitivity and rerun BDF2_KIMPL only with the smallest broadly completing MAXIT, under a separately recorded amendment.

No production SWKIMPL=1 qualification is inferred from this attribution.
