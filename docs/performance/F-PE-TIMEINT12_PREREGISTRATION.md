# F-PE-TIMEINT12 preregistration — dynamic-top BDF2 with explicit first-order transition fallback

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@044e686d1899adf3a631716d09743aa4fce0818f`

Parent authority:

- BOFEK00: corrected fixed-K dynamic-top, SWKIMPL=0 correctness;
- TIMEINT05: fully implicit variable-step BDF2 is qualified on smooth fixed-flux trajectories for accepted step ratio 0.5 <= r <= 2.0;
- TIMEINT11: two-stage TR-BDF2/ESDIRK is too expensive as the default smooth-regime integrator.

## Purpose

Test whether the qualified BDF2 mechanism can coexist cleanly with SWAP's piecewise dynamic-top boundary physics when explicit first-order restart semantics are used at accepted boundary-regime transitions.

This is an integrator-mechanism study.

It does not yet define an adaptive timestep controller and it does not production-admit SWKIMPL=1.

## Numerical route

Use:

- corrected BOFEK00 fixed-K dynamic-top provider;
- fully implicit conductivity inside the test-only TIMEINT BDF2 solver;
- TIMEINT04 representation-aware total-balance floor;
- fixed requested timesteps for mechanism isolation.

The physical dynamic-top equations and BOFEK00 Jacobian derivative remain unchanged.

## History state

Track for the primary trajectory:

- current accepted state n;
- previous accepted water-content state n-1;
- previous accepted dt;
- whether BDF2 history is valid;
- dynamic-top regime at the current accepted endpoint.

Boundary regimes are:

- FLUX;
- HEAD.

The initial state has no accepted dynamic-top history.

## Step rule

### Bootstrap / invalid history

If BDF2 history is invalid:

1. solve the requested interval with fully implicit Backward Euler;
2. evaluate the final dynamic-top regime;
3. commit the BE endpoint;
4. store the previous accepted state and dt;
5. mark one accepted history interval available.

BDF2 becomes valid only after sufficient accepted first-order history exists.

### Smooth BDF2 candidate

When BDF2 history is valid:

1. solve the requested interval with variable-step fully implicit BDF2;
2. evaluate the candidate final dynamic-top regime;
3. compare candidate final regime with the regime at the accepted origin.

If the regime is unchanged:

- commit the BDF2 endpoint;
- advance BDF2 history normally.

### Boundary-regime transition

If the BDF2 candidate final regime differs from the accepted-origin regime:

1. discard the BDF2 candidate;
2. rerun exactly the same interval from the same accepted origin with fully implicit BE;
3. require BE convergence and ledger preservation;
4. commit the BE endpoint;
5. invalidate BDF2 multistep history;
6. require first-order bootstrap before BDF2 is used again.

No BDF2 state from the rejected transition candidate may enter the committed history.

## Solver failure

If a requested BDF2 or BE mechanism solve fails, record the failure.

TIMEINT12 does not introduce a new timestep reduction law. Fixed-step mechanism runs fail closed rather than tuning dt post hoc.

## Evaluation bank

Hydraulic archetypes:

- B01;
- B12;
- O05;
- O14.

Regimes:

- TRANSITION: h0=-100 cm, rain=4 cm/day;
- WET: h0=-20 cm, rain=12 cm/day;
- POND: h0=-5 cm, rain=25 cm/day.

Requested fixed dt:

- 0.010 d;
- 0.005 d.

Horizon:

- 0.12 d.

Total primary trajectories:

24.

The bank intentionally includes smooth periods and surface-boundary transitions.

## Comparators

For every case run:

1. `BE_FULL`:
   fully implicit BE at the same fixed dt for every step;
2. `BDF2_RAW`:
   BDF2 after bootstrap with no regime-transition fallback;
3. `BDF2_FALLBACK`:
   preregistered transition fallback rule.

These comparators isolate whether fallback specifically repairs boundary-transition behavior.

## Metrics

Per trajectory record:

- completion;
- accepted steps;
- BDF2 steps;
- BE bootstrap steps;
- BE transition-fallback steps;
- rejected/discarded BDF2 transition candidates;
- FLUX->HEAD transitions;
- HEAD->FLUX transitions;
- nonlinear iterations;
- backtracks;
- Jacobian builds;
- linear solves;
- deterministic work index;
- cumulative runoff;
- terminal ponding;
- terminal top/mid/bottom head;
- terminal storage;
- maximum ledger residual.

## Refined mechanism reference

For terminal trajectory comparison, use fully implicit BE with fixed dt=0.0025 d on the same case when it completes.

This reference is used only for mechanism-scale terminal comparison.

It is not claimed as universal temporal truth outside this bank.

## Frozen gates

The fallback mechanism advances only if all are true:

1. at least 22/24 BDF2_FALLBACK trajectories complete;
2. every POND case completes;
3. every BDF2-detected regime transition is rerun from the same origin with BE and no transition BDF2 candidate is committed;
4. maximum ledger residual <=5e-8 cm in all completed fallback trajectories;
5. no fallback trajectory is worse than BDF2_RAW in terminal max-head error versus the refined BE reference by more than 0.01 cm;
6. on trajectories containing at least one detected transition, median terminal max-head error of BDF2_FALLBACK is lower than BDF2_RAW;
7. on trajectories containing no detected transition, BDF2_FALLBACK and BDF2_RAW endpoints are numerically identical within:
   - head 1e-10 cm;
   - storage 1e-10 cm;
   - runoff 1e-10 cm;
8. deterministic work of BDF2_FALLBACK is <=1.35 times BDF2_RAW median across completed cases;
9. smooth no-transition BDF2 steps preserve the TIMEINT05 history semantics.

## Interpretation boundary

A pass demonstrates that explicit first-order restart semantics can make a higher-order BDF2 trajectory coexist with dynamic-top regime changes.

It does not yet prove:

- adaptive timestep acceptance;
- dynamic-top local-error estimator qualification;
- production SWKIMPL=1;
- production performance superiority over legacy SWKIMPL=0.

## Successor rule

If TIMEINT12 passes:

- advance to adaptive BDF2 controller architecture with event/regime-aware history ownership;
- keep transition fallback explicit.

If it fails:

- do not attempt to hide dynamic-top transitions inside multistep history;
- reconsider one-step higher-order integration specifically for boundary-transition intervals.

## Production boundary

No production `src/**` change.

Possible outcomes:

- `DYNTOP_BDF2_TRANSITION_FALLBACK_QUALIFIED`;
- `CLOSED_DYNTOP_BDF2_FALLBACK_NOT_QUALIFIED`.
