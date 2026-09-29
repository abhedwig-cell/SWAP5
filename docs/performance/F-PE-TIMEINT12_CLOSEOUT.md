# F-PE-TIMEINT12 closeout — fully implicit dynamic-top prerequisite chain

Date: 2026-09-29

Final status:

`CLOSED_FULLY_IMPLICIT_DYNTOP_ROUTE_NOT_QUALIFIED`

## What TIMEINT12 established

### Surface-head derivative

The missing fully implicit dynamic-top surface-head derivative was derived analytically and qualified against finite differences:

- 608 smooth head-regime points;
- ponded and linear-runoff branches covered;
- max absolute mismatch about 1.9e-10;
- fixed-K BOFEK00 limiting identity preserved.

The mathematical Jacobian prerequisite is solved.

### Fully implicit BE execution

After the derivative was supplied, the fully implicit dynamic-top route still completed only 6/12 wet/moist/ponding cases.

On completed pairs its median deterministic work was about 32% above fixed-K Reference, with individual cases up to about 67% higher.

Thus fully implicit conductivity is not currently a suitable basis for dynamic-top BDF2.

## Consequence for timestep modernization

Do not conclude that higher-order time integration is blocked.

The evidence now isolates the operator choice:

- one-step lagged K is cheap but order limiting;
- endpoint fully implicit K is second-order-capable on smooth fixed-flux cases but not robust/cost-effective on dynamic top.

The unresolved design space is a second-order semi-implicit nonlinear operator.

## Required successor

Open:

`F-PE-TIMEINT13 — extrapolated-conductivity semi-implicit BDF2`.

Candidate concept:

- BDF2 storage derivative;
- second-order accepted-history extrapolation of hydraulic conductivity / nonlinear flux coefficient to t(n+1);
- no endpoint dK/dh term in Newton;
- fixed-K-style dynamic-top Jacobian semantics for the predicted coefficient;
- explicit restart of extrapolation history at hard events and boundary-regime transitions.

This is consistent with established semi-implicit/IMEX BDF2 approaches for nonlinear Richards-type problems, but must be derived and qualified in SWAP's exact operator.

## Production boundary

No production source change.

LEGACY_NUMERICS remains default.
