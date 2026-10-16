# F-PE-NLGLOB14C preregistration — saturated-remainder temporal regime switch

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@31901d9bbb75d87e8723c09f6804dabbcc25c219`

Parent authority:

- NLGLOB14A: `NLGLOB14A_SATURATION_EVENT_ROOT_LOCALIZED`;
- NLGLOB14B: `CLOSED_TG_EVENT_SPLIT_REMAINDER_DOMAIN_FAILED`;
- TIMEINT16C: smooth provider-consistent TG staging remains second order;
- NLGLOB12A1: representation-aware endpoint certificate qualified at research level.

## Purpose

NLGLOB14B established that after the localized saturation event the unchanged unsaturated TG accepted-state formulation is not admissible for the remaining part of the nominal interval.

NLGLOB14C tests one bounded regime switch:

- TG up to the localized saturation event;
- existing implicit head-based/KLAG remainder from the event state.

The no-event TG path remains unchanged.

## Frozen target set

Use the exact five NLGLOB14A/B primary targets:

- O05 / TG / HEAD / dt = 0.00025 d;
- O05 / TG / HEAD / dt = 0.000125 d;
- O05 / TG / HEAD / dt = 0.0000625 d;
- O05 / TG / RUNOFF / dt = 0.00025 d;
- O05 / TG / RUNOFF / dt = 0.000125 d.

## Frozen temporal construction

For a nominal TG interval that produces accepted-state saturation overshoot:

1. restore the exact accepted origin;
2. localize the saturation event using the unchanged NLGLOB14A bisection;
3. require the localized event state to pass the NLGLOB14A event-distance, mass, finite-state and route guards;
4. internally accept the event state as the first subinterval state;
5. compute the exact remainder duration:
   `h_rem = h - h_event`;
6. reevaluate the dynamic-top provider from the event state;
7. integrate `h_rem` using the existing KLAG/Backward-Euler endpoint formulation;
8. preserve unchanged S0/R0 research endpoint certificates for that remainder solve;
9. publish only the final state after the full nominal interval.

The KLAG remainder is a deliberate post-event temporal regime, not a fallback for ordinary unsaturated TG steps.

## Frozen restrictions

No:

- accepted-state clipping;
- recursive event localization within the same nominal interval;
- h/16 or deeper subdivision semantics;
- predictor damping;
- tolerance relaxation;
- MAXIT/backtracking change;
- historical-K fallback;
- change to dynamic-top route physics.

## Frozen mass contract

The full nominal interval consists of:

- TG event subinterval;
- KLAG remainder subinterval.

Require the physical ledger over the complete nominal interval to remain <= `5e-8 cm`.

Cumulative trajectory ledger must remain <= `5e-8 cm`.

## Mandatory target gates

Classify:

`QUALIFIED_TG_SATURATION_EVENT_KLAG_REMAINDER_RESEARCH`

only if all five frozen targets:

1. execute without process failure;
2. localize the event within NLGLOB14A authority;
3. complete the KLAG remainder;
4. complete the requested horizon;
5. retain finite state;
6. retain explicit provider-consistent route resolution;
7. max accepted nominal-interval ledger <= `5e-8 cm`;
8. cumulative ledger <= `5e-8 cm`;
9. no recursive event split occurs.

If >=3/5 remainders fail by endpoint nonconvergence:

`CLOSED_TG_EVENT_KLAG_REMAINDER_ENDPOINT_FAILED`.

If >=3/5 fail by route/state admissibility:

`CLOSED_TG_EVENT_KLAG_REMAINDER_STATE_FAILED`.

If physical mass fails:

`CLOSED_TG_EVENT_KLAG_REMAINDER_MASS_FAILED`.

## Smooth-order preservation

The event-regime switch is inactive on the original smooth TIMEINT16C bank.

The unchanged smooth bank must retain:

- 4/4 complete ladders;
- median refined head order >=1.6;
- median refined moisture order >=1.6;
- >=3/4 individual head orders >=1.5;
- physical/cumulative ledger <= `5e-8 cm`;
- median work ratio versus KLAG BE <=1.15.

If this regresses:

`CLOSED_TG_EVENT_KLAG_REMAINDER_ORDER_REGRESSION`.

## Positive consequence

A positive result authorizes a full 96-case dynamic-top qualification bank using:

- TG on ordinary unsaturated intervals;
- qualified saturation-event localization;
- KLAG remainder only after a saturation event;
- unchanged S0/R0 research endpoint certificates.

Only after that full-bank gate may TIMEINT17 same-route dynamic-top qualification be reopened.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14C

BASELINE: `31901d9bbb75d87e8723c09f6804dabbcc25c219`

BRANCH: `research/f-pe-nlglob14c-saturated-remainder`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: materialize TG-event plus KLAG-remainder test-only composition and run target + smooth banks

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
