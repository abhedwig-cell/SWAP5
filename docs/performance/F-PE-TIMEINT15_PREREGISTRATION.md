# F-PE-TIMEINT15 preregistration — conservative second-order one-step Richards integration

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@a5f127e2f42329914826a835d760102be6fee71f`

Supersedes as an executable research plan:

`work/f-pe-timeint15-conservative-one-step`

That earlier branch proposed a recursive BDF2 flux integral containing prior accepted-interval mass. Final TIMEINT14 authority explicitly rejects such reassignment under the existing physical transaction lineage. No results from that superseded TIMEINT15 proposal are used here.

## Parent authority

TIMEINT14 final status:

`CLOSED_BDF2_INCOMPATIBLE_WITH_INTERVAL_MASS_CONTRACT`.

The decisive constraint is:

- physical accepted interval storage is consecutive-state storage;
- physical in/out belongs to the current accepted interval only;
- numerical history may not be published as current physical water.

Therefore TIMEINT15 changes temporal formulation rather than the mass contract.

## Purpose

Test whether a second-order **one-step** Richards scheme can retain:

1. physical endpoint storage;
2. exact current-interval physical water balance;
3. second-order temporal accuracy;
4. approximately one nonlinear endpoint solve per accepted step;
5. the weak-conductivity-coupling performance advantage suggested by TIMEINT13.

No production source change.

## Candidate — trapezoidal Richards

For each soil compartment define the ordinary physical storage increment:

`Delta theta = theta_(n+1)-theta_n`.

Let `G(y)` be the non-storage Richards residual contribution, including Darcy face fluxes and current step-frozen source/sink terms.

Candidate residual:

`Delta theta * dz / h + 0.5*G(y_n) + 0.5*G(y_(n+1)) = 0`.

Newton Jacobian:

`C_(n+1)*dz/h + 0.5*dG(y_(n+1))/dh`.

This is a one-step method. It has no accepted history mass debt.

For constant prescribed top flux and zero prescribed bottom flux, the physical interval external mass remains exactly the current interval forcing integral.

## Test-only materialization

At HeadCalc entry for an admitted test arm:

1. evaluate the unchanged non-storage residual at the accepted origin and retain it as `G_n`;
2. keep the full physical storage increment unchanged;
3. during Newton replace the non-storage candidate residual by `0.5*(G_n+G_candidate)`;
4. scale only the endpoint non-storage Jacobian contribution by 0.5;
5. leave storage capacity derivative unscaled.

The production HeadCalc source is not modified.

## P0 arms

### TR_KIMPL

- trapezoidal one-step temporal formulation;
- endpoint conductivity fully implicit, `SWKIMPL=1`;
- purpose: prove conservative second-order mechanism independent of cheap-K approximation.

### TR_KPRED

- same trapezoidal formulation;
- endpoint conductivity predicted from accepted history and fixed during Newton;
- first step uses accepted-origin K;
- subsequent constant steps:
  `K_pred = 2*K_n-K_(n-1)`;
- positivity floor 1e-12 cm/day is fail-safe only;
- purpose: one-solve performance candidate.

No third arm may be introduced after P0 exposure.

## P0 smooth bank

Reuse established smooth fixed-flux bank:

- B01, infiltration 2 cm/day;
- B01, infiltration 4 cm/day;
- O05, infiltration 2 cm/day;
- O05, infiltration 4 cm/day.

Horizon:

`0.04 d`.

Constant-step ladder:

- 0.010 d;
- 0.005 d;
- 0.0025 d;
- 0.00125 d.

Explicit fixed top flux and zero bottom flux.

## P0 metrics

Per run:

- completion;
- top/middle/bottom terminal head;
- terminal physical storage;
- max ordinary physical per-step ledger;
- cumulative ordinary physical ledger;
- nonlinear iterations;
- backtracking attempts;
- Jacobian builds;
- linear solves;
- work per accepted step;
- K-prediction clamp count.

Per case:

- refined top-head temporal order.

## P0 gates

TR_KIMPL advances if:

1. 4/4 ladders complete;
2. median refined top-head order >=1.6;
3. >=3/4 individual refined orders >=1.5;
4. max per-step physical ledger <=5e-8 cm;
5. cumulative physical ledger <=5e-8 cm;
6. no nonfinite state or retry pathology;
7. median work per step <=1.25 times fully implicit BE.

TR_KPRED advances if:

1. 4/4 ladders complete;
2. median refined top-head order >=1.6;
3. >=3/4 individual refined orders >=1.5;
4. max per-step physical ledger <=5e-8 cm;
5. cumulative physical ledger <=5e-8 cm;
6. no nonfinite state or retry pathology;
7. zero conductivity clamps on the smooth bank;
8. median work per step <=1.10 times KLAG Backward Euler.

Primary TIMEINT15 mechanism success requires TR_KPRED to advance.

If only TR_KIMPL advances, classify the one-step temporal mechanism positive but cheap conductivity treatment unresolved.

## P1 boundary

Only if TR_KPRED advances.

Dynamic top requires a separately preregistered surface-reservoir and runoff quadrature. No endpoint runoff term may simply be multiplied by dt and called trapezoidal.

## Stop rule

If TR_KIMPL itself fails second-order physical-conservative qualification, close trapezoidal one-step modernization.

If TR_KIMPL passes but TR_KPRED fails, do not fit another conductivity predictor post hoc in TIMEINT15.

## Possible outcomes

- `CONSERVATIVE_TRAPEZOIDAL_KPRED_MECHANISM_QUALIFIED`;
- `CONSERVATIVE_TRAPEZOIDAL_KIMPL_ONLY`;
- `CLOSED_CONSERVATIVE_TRAPEZOIDAL_NOT_QUALIFIED`.

## Production boundary

No production `src/**` change.

No transaction mass-contract change.

No DTMIN/DTMAX tuning.

`LEGACY_NUMERICS` remains production default.
