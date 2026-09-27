# F-PE-SOLVE01 P0B preregistration — bounded refresh arms

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

Parent workunit:
`F-PE-SOLVE01 / PR #654`

## Trigger

The aggressive EF upper-bound arm passed on the frozen 12-group difficult matrix.

Observed on the first qualified EF run:

- median full-solve reduction: about 74.95%;
- median end-to-end speedup: about 70.69%;
- all 12 groups retain exact final-state identity;
- maximum intermediate linear-response relative excursion error: about 1.12e-4.

This is sufficient evidence to continue with bounded refresh policies.

The result does not admit EF to production.

## Purpose

Measure the performance/error curve between exact-every-trial and the aggressive EF upper bound.

Use the same:

- six difficult material/regime origins from PROFILE06;
- both +/-10% dynamic-history directions;
- c=0.50 temporal research-enabler;
- BALTOL02 qualified balance-floor replay;
- same-origin eight-request corrector block:
  `+0.001, +0.01, -0.001, -0.01, +0.001, -0.001, +0.01, -0.01 cm`;
- exact final validation before commit;
- no production source modification.

## Frozen arms

### E0

Every request exact.

### E2

One skipped response is allowed after each exact anchor.

A new exact anchor is then required.

The final request of the block is exact.

Expected nominal exact-request pattern:

`E, A, E, A, E, A, E, E`

where E is exact and A is approximate.

### E4

Up to three skipped responses are allowed after each exact anchor.

The final request of the block is exact.

Expected nominal exact-request pattern:

`E, A, A, A, E, A, A, E`

### EH

Head-window refresh.

Frozen window:

`|h_request - h_anchor| <= 0.010 cm`

may use the local response from the current exact anchor.

Crossing the window forces an exact refresh.

The final request of the block is exact regardless of window.

The window is frozen before execution and must not be retuned after seeing results.

### EF

Aggressive upper bound retained for comparison:

- first request/anchor exact;
- all intermediate discarded responses approximate;
- final request exact.

## Response representation

Use the local linear response from the most recent exact anchor:

`q(h) = q_anchor + J_anchor * (h - h_anchor)`

No secant, ROM or fitted surrogate in P0B.

## Measurements

Per arm/group:

- exact Richards solve count;
- skipped/approximate response count;
- median wall-clock per corrector block;
- speedup versus E0;
- maximum absolute q error on skipped responses;
- maximum relative response-excursion error;
- exact final q/state/ledger identity;
- final validation success.

## Interpretation gates

The original SOLVE01 advancement gates remain authoritative:

- >=50% solve reduction for an arm to qualify as solve-eliminating;
- >=30% median end-to-end speedup for an arm to justify continuation;
- exact final validation before commit;
- exact committed state/ledger ownership.

E2 is retained even if its nominal cadence cannot reach 50% solve reduction. It is a low-aggression reference point for the curve, not necessarily an advancement candidate.

No production admission occurs in P0B.
