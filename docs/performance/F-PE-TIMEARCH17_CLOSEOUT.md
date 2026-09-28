# F-PE-TIMEARCH17 closeout — GUARD_M5 blind validation

Date: 2026-09-28

Final status:

`CLOSED_GUARD_M5_BLIND_VALIDATION_FAILED`

## Decision

The first calibrated AUTO_REFERENCE controller does not survive blind validation.

Calibration performance:

- 16/16 P-C1;
- about 33.6% median deterministic work reduction.

Blind validation:

- 17/20 P-C1;
- about 11.6% median deterministic work reduction on passing cases;
- two candidate-specific WET accuracy failures;
- one common-domain Reference solver-floor failure;
- TRANSITION shows median work regression.

The calibration result therefore does not generalize sufficiently.

## Architectural interpretation

The TIMEARCH redesign remains qualified.

What failed is the GUARD_M5 algorithm, not the separated architecture.

The sequence TIMEARCH12-17 now provides a strong negative result for heuristic AUTO controllers based primarily on:

- nonlinear effort;
- accepted-state normalized pressure-head movement;
- dynamic-top endpoint mode;
- fixed wet-zone head thresholds;
- finite refinement/fallback state machines.

These signals contain useful performance information, but they do not provide a sufficiently reliable local temporal-error estimate across unseen wet-transition states.

## Implication for next research

Do not continue with another threshold or state-machine rescue.

The next valid question is at the temporal discretization level:

> Can SWAP's Richards time integration be reformulated or wrapped as a modern adaptive integrator with a mathematically grounded local truncation-error estimate?

This requires first identifying the exact current temporal discretization and its coupling to:

- storage/capacity linearization;
- dynamic-top boundary transitions;
- BALTOL02;
- Newton initialization and Jacobian;
- accepted-history state;
- transaction rollback.

Potential successor:

`F-PE-TIMEINT01 — Richards temporal-discretization reconstruction and modern integrator options`.

TIMEINT01 should be architecture/science first:

1. reconstruct the exact current discrete-in-time Richards equation;
2. identify formal temporal order in each boundary regime;
3. identify where regime switches reduce effective order;
4. assess candidate modern schemes such as embedded implicit Euler/step-doubling, BDF2 with fallback, or SDIRK-style embedded pairs;
5. reject schemes that require unaffordable extra nonlinear solves;
6. define what state/history must be committed transactionally;
7. design a cheap error estimator before controller qualification.

## Production boundary

No production timestep behavior changes.

LEGACY_NUMERICS remains default.

AUTO_REFERENCE remains configuration-valid but unavailable for production.
