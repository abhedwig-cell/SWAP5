# F-PE-NLGLOB02 preregistration — balance-floor and late-iteration stagnation attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@235017bbe0fbac6c4167537c645fb45ceb9172d2`

Parent authority:

- TIMEINT17: `BLOCKED_TG_DYNAMIC_TOP_BY_ENDPOINT_GLOBALIZATION`;
- TIMEINT17I: `TIMEINT17I_MIXED_MODEL_QUALITY`;
- NLGLOB01: `NLGLOB01_NO_SIMPLE_SCALING_SIGNAL`;
- BALTOL02: production-qualified effective balance-rate floor `max(configured, 2.8e-16 cm / dt)`;
- PUB-P2E07: Reference residual floor dominated by storage-input representation scale in its frozen domain.

## Question

Do the poor-model Newton iterations in the TIMEINT17 endpoint-failure bank occur primarily when the nonlinear solve has already reached the existing qualified balance-resolution floor, so that the remaining failure is better described as late-iteration stagnation near attainable residual resolution than as a globalization step-size defect?

This is observational only. No tolerance, residual, Jacobian, timestep, K staging, line-search factor, iteration cap, route semantics or production source is changed.

## Frozen bank

Reuse exactly the TIMEINT17H/I and NLGLOB01 bank: B01, B12, O05, O14; FLUX, HEAD, RUNOFF; TG and matched KLAG; dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d; horizon = 0.001 d; unchanged A2 route-margin fixtures; MAXIT=8; MaxBackTr=8.

The harness already applies `baltol = max(1e-12, 2.8e-16/dt)` to both compartment and total balance criteria. The observed balance ratios are therefore measured against already qualified numerical authority.

## Per-iteration diagnostics

At the Newton origin before backtracking record `res_inf`, `res_sum`, `tol_cp`, `tol_tot`, `r_cp=res_inf/tol_cp`, `r_tot=res_sum/tol_tot`, `r_bal=max(r_cp,r_tot)`, NLGLOB01 step diagnostics, TIMEINT17I selected rho/factor, route, mode, material, dt, and dominant convergence-contract component. Only terminal endpoint-failure iterations are included.

## Frozen bands

- `AT_FLOOR`: `r_bal <= 1`;
- `NEAR_FLOOR`: `1 < r_bal <= 10`;
- `ABOVE_FLOOR`: `r_bal > 10`.

The factor 10 is a diagnostic decade, not a solver tolerance or proposed acceptance threshold.

## Frozen classifications

### FLOOR_STAGNATION_SIGNAL

`NLGLOB02_BALANCE_FLOOR_STAGNATION_SIGNAL` if coverage passes and all hold:

1. >=50% of poor-model iterations are AT_FLOOR or NEAR_FLOOR;
2. the poor-model near-floor fraction is at least 1.5 times the adequate-model near-floor fraction;
3. median `r_bal` of poor-model iterations is <=10;
4. the final audited iteration of at least 4/6 route-mode families has median `r_bal <= 10`.

### ROUTE_SPECIFIC_FLOOR_SIGNAL

`NLGLOB02_ROUTE_SPECIFIC_BALANCE_FLOOR_SIGNAL` if the aggregate rule fails but both FLUX/TG and FLUX/KLAG satisfy conditions 1 and 3 while at least one HEAD or RUNOFF family does not.

### FLOOR_NOT_DOMINANT

`NLGLOB02_BALANCE_FLOOR_NOT_DOMINANT` if fewer than 25% of poor-model iterations are within one decade of the floor and median poor-model `r_bal > 10`.

### MIXED

Otherwise: `NLGLOB02_MIXED_BALANCE_FLOOR_SIGNAL`.

## Coverage gate

Conclusive NLGLOB02 requires all three routes, all four materials, all four dt levels, TG and KLAG, >=500 audited failing Newton iterations, >=100 poor-model iterations, and finite balance ratios for >=99% of audited iterations. Otherwise: `BLOCKED_NLGLOB02_FLOOR_COVERAGE`.

## Consequence

If BALANCE_FLOOR_STAGNATION_SIGNAL: do not tighten balance tolerances and do not add more damping; open a separately preregistered convergence-contract workunit to test whether a floor-aware termination rule can distinguish numerically exhausted iterations from physically unresolved ones while preserving mass authority.

If route-specific: no global termination change; first isolate route-specific residual construction and floor behavior.

If floor not dominant: do not use BALTOL02/floating-point floor as explanation for TIMEINT17; move to a separately preregistered globalization family.

If mixed: decompose by route, mode and terminal iteration before any repair.

## Stop rules

NLGLOB02 does not alter production `src/**`, BALTOL02, tolerances, mass acceptance, MAXIT, MaxBackTr, dt, K staging, route/event logic, or select a trust-region radius or pseudo-transient parameter.

## Production boundary

Research diagnostics only. `LEGACY_NUMERICS` remains production default.