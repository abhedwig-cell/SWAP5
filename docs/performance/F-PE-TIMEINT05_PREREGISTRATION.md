# F-PE-TIMEINT05 preregistration — mass-conservative BDF2 smooth-regime mechanism

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@bc365f8d24fb1854ee1484a4f6f9dcc5bc3944fb`

Parent authority:

- TIMEINT01: canonical Richards time discretization reconstructed as mixed-form backward Euler;
- TIMEINT03: mixed-state derivative LTE mechanism qualified;
- TIMEINT04: closed-loop first-order adaptive BE rejected on performance.

## Purpose

Determine whether second-order BDF2 can reduce temporal error per nonlinear solve on the current SWKIMPL=0 Richards route.

TIMEINT05 is deliberately restricted to a smooth dynamic-top FLUX regime. Ponding/runoff transitions are excluded from this first mechanism test because the current dynamic-top surface-storage equation is itself backward-Euler shaped and must not be silently combined with a second-order soil-storage term.

No production source modification.

## Discretization

For constant dt and smooth flux-boundary cases, replace the current storage derivative:

`(theta_{n+1} - theta_n)/dt`

with BDF2:

`(3 theta_{n+1} - 4 theta_n + theta_{n-1})/(2 dt)`.

Equivalent coefficients:

- candidate theta: 1.5;
- current accepted theta: -2.0;
- preceding accepted theta: +0.5.

The Newton storage Jacobian becomes:

`1.5 * C(h_{n+1}) * dz / dt`.

All flux, source/sink, conductivity, SWKIMPL=0 and nonlinear convergence semantics remain otherwise unchanged.

## Startup/history

Construct two accepted backward-Euler history states using equal startup dt.

Only after two valid equally spaced accepted states is BDF2 evaluated.

No variable-step BDF2 coefficients are used in TIMEINT05.

## Mechanism cases

Use repository-backed hydraulic archetypes:

- B01;
- B12;
- O05;
- O14.

Use smooth nonponding forcing/state combinations only:

- DRY_S:
  - h0 = -250 cm;
  - rain = 0.8 cm/day;
- TRANS_S:
  - h0 = -100 cm;
  - rain = 2.0 cm/day;
- MOIST_S:
  - h0 = -50 cm;
  - rain = 3.0 cm/day.

Any point that enters dynamic-top HEAD regime, ponding or runoff during history/reference/candidate evaluation is classified outside the TIMEINT05 smooth domain and is not used for BDF2 qualification.

## Step sizes

For each material/state combination evaluate:

- dt = 0.005 d;
- dt = 0.010 d;
- dt = 0.020 d.

For each dt:

1. construct two equal-dt BE history intervals;
2. from the same accepted second history state execute:
   - one BE step of dt;
   - one BDF2 step of dt;
   - a refined BE reference of four equal substeps dt/4.

## Primary metrics

Against refined BE endpoint:

- max pressure-head error;
- max theta error;
- L1 water-depth error;
- storage error;
- bottom/top flux where applicable;
- discrete mass residual appropriate to each scheme;
- nonlinear iterations/backtracks/Jacobian builds/linear solves.

For backward Euler the familiar per-step integrated ledger is:

`storage_{n+1} - storage_n - net_boundary_inflow * dt`.

For BDF2 the mass gate is instead evaluated on the discrete BDF2 balance:

`sum(dz * (1.5 theta_{n+1} - 2 theta_n + 0.5 theta_{n-1})) - net_boundary_inflow * dt`.

Because TIMEINT05 is restricted to a smooth prescribed atmospheric-flux regime with zero ponding/runoff and zero bottom flux, the net boundary inflow is known directly from the prescribed top forcing.

Do not judge BDF2 with the backward-Euler endpoint-storage ledger. Higher-order BDF methods are mass-conservative in their multistep discrete balance, while simple accumulation of endpoint boundary flux times dt is not the same one-step storage identity as backward Euler.

Report error per deterministic work.

## Advancement gates

BDF2 mechanism advances only if:

1. at least 24 complete smooth-domain comparison points exist;
2. BDF2 discrete multistep mass residual <=5e-8 cm on every complete point;
3. median BDF2 max-theta error <=0.60 * median BE max-theta error;
4. median BDF2 L1 water-depth error <=0.60 * median BE L1 water-depth error;
5. BDF2 deterministic work per tested step <=1.25 * BE work on median;
6. BDF2 has no >2x BE error outlier in max theta or water L1 on any complete point;
7. no new solver-failure pattern appears.

This is an accuracy-per-solve mechanism gate, not a runtime admission.

## Stop rule

If BDF2 fails this smooth-regime mechanism gate, close higher-order BDF2 as the first migration candidate and reconsider alternative embedded implicit schemes.

If BDF2 passes, advance to a separately preregistered dynamic-top transition/restart study.

## Production boundary

No production timestep/integrator behavior changes.
