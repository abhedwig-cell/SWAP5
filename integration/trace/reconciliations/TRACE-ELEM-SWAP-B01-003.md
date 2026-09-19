# TRACE-ELEM-SWAP-B01-003 reconciliation

Date closed: 2026-09-19
Prospective result: `NO_CONFIRMED_DISCREPANCY`
Candidate IDs: none

## Element

Frozen reference Richards nonlinear solver and linearisation contract, selected before detailed inspection as the numerical-scientific-convention stratum of Exposure Batch 01.

## Scope authority

The reviewer page `docs/numerics/richards-solver.md` and F-DOC25 both bind the claim surface to:

- Status-A authority `992a5c657bfe10a10100f92e0cb77c4825ae65b6`;
- scientific production baseline `50346642bd565f79134ea17d5462e544b354998c`;
- frozen HeadCalc blob `3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55`;
- frozen reference linear-solver blob `5b6ecd2341b315967bcfac6b879c3afe227fb245`.

Post-Status-A Ross/RossFast work is explicitly outside this denominator.

The known SWAP-011 conductivity/Jacobian correction predates the TRACE freeze and remains historical/pilot evidence only. It is not recycled as a prospective observation.

## Residual and storage

Direct inspection of frozen `headcalc.f90` confirms that `vector_F` uses the actual nonlinear storage change

`(theta(i)-thetm1(i))*matrix_fraction(i)*dz(i)/dt`

together with process source/sink terms and hydraulic face terms.

Interior face gradients are formed as

`(h(i-1)-h(i))/distance + 1`.

For flux boundaries, native `qtop` is added at the top and `qbot` is subtracted at the bottom. Prescribed-head branches insert their hydraulic face terms instead. The documentation correctly keeps these native solver signs distinct from normalized external accounting conventions.

## Jacobian and conductivity policy

For `SWKIMPL=0`, frozen HeadCalc initializes the off-diagonal hydraulic coefficients before the nonlinear loop as

`-Kmean/distance`

and leaves conductivity fixed at the time-level value for that attempted step.

For `SWKIMPL=1`, HeadCalc reevaluates conductivity and `dK/dh`, refreshes `Kmean`, and adds conductivity-derivative terms in `jacobian_F`. The documentation states only this structural distinction and does not broaden all historical implicit-conductivity combinations into Status-A scope.

The main diagonal contains the water-capacity storage derivative plus adjacent hydraulic conductances and applicable head-boundary stiffness.

## Newton, backtracking and convergence

Frozen HeadCalc directly confirms:

- `J*delta_h=F`;
- `h_new=h_old-factor*delta_h`;
- initial `factor=1`;
- residual objective `0.5*dot(F,F)`;
- backtracking factor divided by three when progress criteria fail;
- compartment residual criterion `CritDevBalCp`;
- absolute/relative pressure-head update criteria `CritDevh2Cp/CritDevh1Cp`;
- total residual criterion `CritDevBalTot`.

The page does not invent universal numeric values for these criteria.

## Linear solve and fallback

The frozen reference linear solver implements tridiagonal forward elimination/back substitution and returns failure on near-zero pivots. HeadCalc then calls the banded one-sub/one-super-diagonal fallback. This is documented as a property of the reference route, not a requirement on future solvers.

## Architecture and auxiliary operator

F-SI35 records that the mandatory typed production solver seam was closed without changing the full Richards algorithm and without requiring RossFast production readiness.

F-SI38 qualifies only a restricted auxiliary temporal-indicator source capability. Its hard nonclaims match the reviewer page: no universal head budget, no new Richards physics, no new mass or retry policy, and no admission of deferred macropore/root-sink/dynamic-top envelopes.

## TRACE disposition

No prospectively new conflict was found between the frozen numerical documentation, exact implementation or admitted scope authorities.

No candidate was registered.

This null result does not erase the historical SWAP-011 finding. It shows only that the selected current frozen reference representation is internally reconciled at the TRACE observation point.
