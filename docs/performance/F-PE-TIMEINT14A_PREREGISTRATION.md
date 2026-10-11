# F-PE-TIMEINT14A preregistration — BDF2 interval-mass identity

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@56a072f6484b8c8dd92e0c72bb2e71ab1d55ed94`

Parent:

F-PE-TIMEINT13 / PR #745.

## Question

Are the O(1e-3) to O(1e-2 cm) ordinary interval-ledger residuals observed for dynamic-top BDF2 an actual loss of water, or the exact algebraic consequence of combining:

- a BDF2 soil-water storage derivative; and
- SWAP5's one-step physical accepted-interval mass contract?

## Discrete identity

For constant dt after the BE bootstrap, the soil storage term in the TIMEINT13 BDF2 equation is:

`1.5*Ssoil_(n+1) - 2*Ssoil_n + 0.5*Ssoil_(n-1)`.

The dynamic-top surface store remains a one-step physical balance.

If the discrete Richards equation itself is solved to tolerance, the ordinary physical interval ledger

`Rphysical = (Ssoil_(n+1)-Ssoil_n) + (Pond_(n+1)-Pond_n) - external_net_interval_mass`

should differ from zero by the soil-history correction:

`Rhistory = -0.5 * (Ssoil_(n+1) - 2*Ssoil_n + Ssoil_(n-1))`.

Frozen identity prediction:

`Rphysical - Rhistory = O(solver/balance tolerance)`.

The BE bootstrap step has no BDF2 history correction and must retain the ordinary roundoff-scale ledger.

## Evaluation bank

Use the same TIMEINT13 dynamic-top candidate:

- B01, B12, O05, O14;
- MOIST, WET, POND;
- dt = 0.005 d;
- horizon = 0.12 d;
- extrapolated-K BDF2;
- MAXIT=8;
- corrected fixed-K dynamic-top route.

Record all completed steps, including prefixes of trajectories that later fail.

Per accepted step record:

- soil storage n-1;
- soil storage n;
- soil storage n+1;
- ponding n and n+1;
- external interval mass terms;
- ordinary physical ledger;
- predicted BDF2 history correction;
- corrected identity residual;
- solver work and route.

## Frozen gates

The structural identity is confirmed only if:

1. at least 100 BDF2 accepted steps are available across the bank;
2. BE bootstrap ordinary ledger <= 5e-8 cm for every completed bootstrap;
3. max absolute `Rphysical-Rhistory` over BDF2 steps <= 5e-8 cm;
4. median absolute identity residual <= 1e-10 cm;
5. at least one case has ordinary |Rphysical| >= 1e-3 cm, proving the test is not trivial;
6. no result is removed because its ordinary physical ledger is large.

## Interpretation rule

If the identity passes:

- classify the TIMEINT13 ledger signal as `BDF2_HISTORY_CONTRACT_MISMATCH_CONFIRMED`;
- do not call it a hidden mass leak;
- also do not relabel the history term as a physical external flux;
- open TIMEINT14B to decide whether modified-storage accounting is admissible or whether a different conservative second-order integrator is required.

If the identity fails:

- classify `UNEXPLAINED_MASS_DEFECT_REMAINS`;
- stop higher-order integration work until the missing mass term is found.

## Production boundary

No production source change.

No mass gate is relaxed.

No transaction mass semantics are changed.
