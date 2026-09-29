# F-PE-TIMEINT15 preregistration — conservative second-order one-step Richards integration

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS_RECONCILED`

Current canonical authority:

`integration/f-ci-canonical@a5f127e2f42329914826a835d760102be6fee71f`

Authority reconciliation:

`docs/performance/F-PE-TIMEINT15_AUTHORITY_RECONCILIATION.md`

## Parent authority

TIMEINT14 established that ordinary BDF2 cannot retain SWAP5's exact consecutive-state physical interval mass contract without importing numerical history into current-interval mass publication.

TIMEINT13 established that history-predicted conductivity can retain near-second-order smooth accuracy while avoiding expensive endpoint-fully-implicit conductivity coupling.

The next valid question is therefore:

> Can a conservative second-order one-step method retain physical per-interval mass semantics and the weak-coupling performance advantage?

Research-only. No production source change.

## Candidate family

Primary candidate:

`TRAP_KPRED`

A conservative trapezoidal / Crank-Nicolson-style Richards discretization.

For each soil compartment:

`theta(h_(n+1)) - theta(h_n) = h/2 * [F_n + F_(n+1)]`

where `F` denotes the net physical water-flux divergence plus source/sink rate with the same sign convention as current HeadCalc.

The storage increment is the exact consecutive physical theta difference.

Therefore summing compartments naturally produces the physical interval storage change rather than a modified multistep storage.

## Conductivity treatment

To avoid the expensive SWKIMPL=1 dynamic coupling, the endpoint flux operator uses a second-order accepted-history prediction:

`K_pred_(n+1) = K_n + r (K_n-K_(n-1))`.

For constant-step P0/P1:

`K_pred_(n+1) = 2 K_n-K_(n-1)`.

The candidate endpoint conductivity is held fixed during Newton:

- `dK/dh=0`;
- exact candidate theta(h) and C(h);
- existing conductivity mean method;
- positivity floor `1e-12 cm/day` only as fail-safe;
- clamp count recorded.

The origin flux `F_n` is evaluated from the accepted origin using exact accepted conductivity `K_n`.

## Bootstrap

The first accepted interval has insufficient conductivity history.

It uses the current one-step BE/KLAG Reference operator.

TRAP_KPRED starts on the second accepted interval.

Any later event/restart semantics are outside TIMEINT15 and would require a first-order restart.

## Why this method is contract-compatible in principle

For the candidate one-step equation:

`Delta S_n = h/2 (F_n+F_(n+1))`.

The right-hand side is a quadrature using physical rates belonging to the current interval endpoints.

There is no previous-interval mass term.

If all internal face fluxes cancel and every storage component is discretized consistently, the accepted physical interval ledger remains a direct physical identity.

This must be demonstrated, not assumed.

## P0 — smooth fixed-flux mechanism

First exclude dynamic-top and other discontinuities.

Use the established TIMEINT smooth bank:

- B01, infiltration 2 cm/day;
- B01, infiltration 4 cm/day;
- O05, infiltration 2 cm/day;
- O05, infiltration 4 cm/day.

Constant-step ladder:

- 0.010 d;
- 0.005 d;
- 0.0025 d;
- 0.00125 d.

Horizon:

- 0.04 d.

Comparators:

1. current BE/KLAG;
2. TIMEINT13 extrapolated-K BDF2.

Frozen P0 gates:

1. 4/4 candidate ladders complete;
2. median refined top-head order >=1.6;
3. at least 3/4 individual refined top-head orders >=1.5;
4. physical per-step ledger <=5e-8 cm;
5. cumulative physical ledger <=5e-8 cm;
6. storage spread <=1e-10 cm across the refinement ladder;
7. no conductivity clamp on the smooth bank;
8. median deterministic work per step <=1.10 times TIMEINT13 extrapolated-K BDF2;
9. no alternative-solver or retry pathology.

If P0 fails, stop this candidate.

## P1 — source/flux quadrature consistency

Only if P0 passes.

Use time-varying but smooth prescribed top flux forcing with an analytically integrable rate over the interval.

Candidate forcing family:

`q(t)=q_bar + q_amp * sin(2*pi*t/T)`.

Preregistered cases will use amplitudes small enough to remain within the fixed-flux boundary regime.

Compare:

- exact analytical cumulative boundary input;
- trapezoidal interval quadrature;
- candidate physical storage change.

Frozen P1 gates:

1. cumulative physical ledger <=5e-8 cm;
2. observed boundary-quadrature convergence order >=1.8;
3. no route/process discontinuity.

This separates a genuinely second-order physical flux quadrature from merely obtaining a second-order state endpoint.

## P2 — dynamic-top prerequisite

Dynamic-top is opened only after P0 and P1 pass.

Before a dynamic-top solve, derive a trapezoidal surface-storage residual using:

`P_(n+1)-P_n = h/2[(q0+qtop-qrun)_n + (q0+qtop-qrun)_(n+1)]`.

The BE production provider remains the bootstrap/reference authority.

A test-only dynamic-top trapezoidal provider must first reproduce the production provider in the first-order bootstrap branch exactly.

Dynamic-top P2 requires separate preregistered formulas/gates before exposure.

## Jacobian rule

For TRAP_KPRED the candidate endpoint flux contribution is weighted by 1/2.

Accordingly the endpoint flux Jacobian contribution must be weighted by 1/2 relative to the corresponding BE endpoint operator.

The exact storage derivative remains:

`d theta(h_(n+1))/dh`.

The origin-flux contribution is a frozen residual source and has no candidate-state Jacobian term.

TIMEINT15 P0 must patch these semantics test-only and must not alter production HeadCalc.

## Mass semantics

Non-negotiable:

- physical storage remains consecutive endpoint physical water;
- physical flux publication is built only from current-interval physical rates/quadrature;
- no numerical history debt enters physical mass;
- mass tolerance is not widened;
- transaction semantics are not changed.

## Cost interpretation

A trapezoidal one-step solve requires one nonlinear solve per accepted interval.

No second nonlinear stage is allowed in the primary candidate.

The target is therefore materially cheaper than TR-BDF2/SDIRK while providing a natural second-order conservative interval identity.

## Stop rule

Do not rescue TRAP_KPRED with empirical blending factors after results.

If the method fails temporal order, physical ledger, or nonlinear robustness gates, close the candidate and reconsider another conservative one-step scheme.

## Possible outcomes

- `CONSERVATIVE_TRAP_KPRED_MECHANISM_QUALIFIED`;
- `CLOSED_TRAP_KPRED_ORDER_FAIL`;
- `CLOSED_TRAP_KPRED_CONSERVATION_FAIL`;
- `BLOCKED_TRAP_KPRED_NONLINEAR_ROBUSTNESS`.

## Production boundary

No production `src/**` change.

`LEGACY_NUMERICS` remains default.

No user DTMIN/DTMAX change follows from TIMEINT15 alone.
