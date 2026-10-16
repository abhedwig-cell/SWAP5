# F-PE-NLGLOB12A1 preregistration — representation-aware endpoint certificate and replay

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@15e5fa2738a889700dc4b8ed792e823652b38dd3`

Parent authority:

- NLGLOB12A: `NLGLOB12A_AGGREGATE_STORAGE_FLOOR_CONFIRMED`;
- all 8 stagnation trajectories satisfy `R_total_ulp <= 1` and `R_local_ulp <= 1`;
- observed maxima on canonical NLGLOB12A: `R_total_ulp = 0.210625`, `R_local_ulp = 0.7088`;
- BALTOL02 remains unchanged.

## Purpose

Test whether a representation-aware convergence certificate can safely terminate the eight stagnating above-floor endpoint solves without changing the scalar balance tolerances.

The certificate is derived from actual floating-point storage representation, not from an empirical tolerance multiplier.

This is test-only replay.

## Frozen certificate R0

At a post-backtracking Newton state, R0 is true only if all conditions hold.

### R0.1 Local representation bound

For every active node i:

`|R_i| <= U_i`

where:

`U_i = (ulp(theta_i) + ulp(theta_m1_i)) * f_i * dz_i / dt`.

Equivalent:

`R_local_ulp <= 1`.

### R0.2 Aggregate representation bound

`|sum_i R_i| <= U_total`

where:

`U_total = sum_i |U_i|`.

Equivalent:

`R_total_ulp <= 1`.

### R0.3 Existing head guard

The existing HeadCalc pressure-head update contract must be satisfied.

No head tolerance is changed.

### R0.4 Existing ponding guard

Where ponding balance is applicable, the existing ponding contract must be satisfied.

No ponding tolerance is changed.

### R0.5 Route and finite-state guard

Require:

- all active state and diagnostic values finite;
- dynamic-top route equals the intended frozen fixture route;
- no provider/process failure.

R0 is independent of rho, iteration number and S0.

## Replay composition

The test-only HeadCalc may terminate a still-`flnonconv` iteration with explicit diagnostic:

`F_PE_NLGLOB12A1_ACCEPT|REASON=REPRESENTATION_FLOOR`

iff R0 is true.

The existing S0 replay remains available unchanged in the full dynamic bank.

If either existing ordinary convergence, S0, or R0 accepts the endpoint, the physical state is returned through the normal adapter seam.

No extra Newton iteration is added by R0.

## Frozen banks

### Bank A — eight stagnation trajectories

Reuse exactly the NLGLOB12 stagnation subset.

Require:

1. 8/8 execute;
2. >=7/8 are recovered by R0 or ordinary convergence;
3. no R0 acceptance violates finite/route/head/ponding guards;
4. all R0 acceptances are explicitly diagnosed.

### Bank D — full 96-case dynamic replay

Reuse the NLGLOB09 full bank with unchanged S0 plus R0.

Require:

1. 96/96 execute;
2. completed requested horizon in >=80% of cases;
3. completed set spans TG and KLAG;
4. all three routes represented;
5. at least 3 materials represented;
6. max accepted-interval physical ledger <= `5e-8 cm`;
7. max cumulative ledger <= `5e-8 cm`;
8. all completed accepted states finite and route-consistent;
9. every R0 acceptance has explicit diagnostic;
10. no scalar solver tolerance, MAXIT, backtracking, timestep, K staging or route rule changes.

## Frozen classifications

If Bank A and Bank D pass:

`QUALIFIED_REPRESENTATION_AWARE_ENDPOINT_CERTIFICATE_RESEARCH`.

If R0 recovers fewer than 7/8 Bank-A cases:

`CLOSED_REPRESENTATION_CERTIFICATE_INSUFFICIENT_RECOVERY`.

If any R0 acceptance violates mass/state/route/head/ponding safety:

`CLOSED_REPRESENTATION_CERTIFICATE_UNSAFE`.

If Bank A passes but full dynamic recovery remains <80%:

`REPRESENTATION_CERTIFICATE_QUALIFIED_ENDPOINT_BLOCKER_REMAINS`.

## Stop rules

Do not:

- multiply U_i or U_total by a fitted factor;
- change BALTOL02;
- relax head/ponding criteria;
- increase MAXIT or backtracking;
- combine R0 with predictor-domain clipping;
- reconstruct external physical flux from storage.

## Architecture invariants

Affected invariants: 7, 13, 23, 24, 25, 26, 30.

## Production boundary

Research/test-only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
