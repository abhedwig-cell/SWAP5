# F-PE-NLGLOB14D preregistration — persistent saturated temporal mode

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@c0995bd21b2b755cd25337c1b407752d5cb44fb9`

Parent authority:

- NLGLOB14A: `NLGLOB14A_SATURATION_EVENT_ROOT_LOCALIZED`;
- NLGLOB14B: `CLOSED_TG_EVENT_SPLIT_REMAINDER_DOMAIN_FAILED`;
- NLGLOB14C: `CLOSED_TG_EVENT_KLAG_REMAINDER_STATE_FAILED`;
- NLGLOB14C mechanistic attribution: `POST_EVENT_SATURATED_MODE_NOT_PERSISTED`;
- TIMEINT16C smooth provider-consistent TG staging remains second order;
- NLGLOB12A1 representation-aware endpoint certificate remains qualified at research level.

## Purpose

NLGLOB14C showed that the first localized saturation event and immediate KLAG remainder both succeed physically and conservatively in all five frozen targets.

The full trajectories fail only because the next nominal interval re-enters the ordinary unsaturated TG path from an accepted origin already on, or numerically indistinguishable from, the saturation boundary.

NLGLOB14D tests the missing bounded mechanism:

**persist the saturated temporal regime across subsequent nominal intervals after the first qualified saturation event.**

The first phase intentionally does not introduce a release rule.

For the frozen target horizon, once saturated mode is entered it remains active until the horizon ends.

This is an attribution/qualification test, not final production semantics.

## Frozen target set

Use the exact five NLGLOB14A-C targets:

- O05 / TG / HEAD / dt = 0.00025 d;
- O05 / TG / HEAD / dt = 0.000125 d;
- O05 / TG / HEAD / dt = 0.0000625 d;
- O05 / TG / RUNOFF / dt = 0.00025 d;
- O05 / TG / RUNOFF / dt = 0.000125 d.

## Frozen temporal state machine

Initial mode:

`UNSATURATED_TG`.

### Entry

Entry into:

`SATURATED_KLAG`

occurs only after:

1. ordinary TG produces prospective accepted-state saturation overshoot;
2. the NLGLOB14A event root localizes;
3. the event state passes the qualified event-distance, route, finite-state and event-mass guards;
4. the exact remainder of that same nominal interval completes using the NLGLOB14C KLAG remainder.

Only after successful completion of that event+remainder interval is the persistent mode flag set.

### Persistent saturated mode

For each later nominal interval while in `SATURATED_KLAG`:

1. keep the accepted current state as the physical interval origin;
2. reevaluate the dynamic-top provider normally;
3. advance the full nominal interval using the existing KLAG/Backward-Euler endpoint formulation;
4. retain the unchanged S0/R0 research endpoint certificates;
5. publish the resulting accepted state normally;
6. retain `SATURATED_KLAG` for the next nominal interval.

No TG saturation-event root localization is attempted while persistent saturated mode is active.

### Release

No release condition is introduced in NLGLOB14D.

For these short frozen trajectories, persistent saturated mode remains active through the requested horizon once entered.

This is conservative with respect to the current scientific question: whether missing regime persistence is sufficient to remove the repeated event-bracket failure.

A physical release rule requires a separate preregistered successor after positive persistence evidence.

## Frozen restrictions

No:

- accepted-state clipping;
- release threshold;
- iteration-count release;
- recursive event localization after saturated-mode entry;
- h/16 or deeper subdivision;
- predictor damping;
- tolerance relaxation;
- MAXIT/backtracking change;
- historical-K fallback;
- dynamic-top route-physics change.

## Frozen target qualification gates

Classify:

`QUALIFIED_PERSISTENT_SATURATED_TEMPORAL_MODE_RESEARCH`

only if all five targets:

1. execute without process failure;
2. localize the first saturation event within NLGLOB14A authority;
3. complete the first KLAG remainder;
4. enter persistent saturated mode exactly after the successful event interval;
5. complete every later nominal interval in saturated mode;
6. complete the requested horizon;
7. remain finite;
8. remain route-consistent;
9. max accepted nominal-interval physical ledger <= `5e-8 cm`;
10. cumulative physical ledger <= `5e-8 cm`;
11. no later `SATURATION_ROOT_BRACKET_INVALID` occurs;
12. no recursive event localization occurs after persistent mode entry.

If >=3/5 fail later saturated-mode KLAG intervals by endpoint nonconvergence:

`CLOSED_PERSISTENT_SATURATED_MODE_ENDPOINT_FAILED`.

If >=3/5 fail route/state admissibility:

`CLOSED_PERSISTENT_SATURATED_MODE_STATE_FAILED`.

If physical mass fails:

`CLOSED_PERSISTENT_SATURATED_MODE_MASS_FAILED`.

If entry/persistence diagnostics cannot be implemented faithfully:

`BLOCKED_PERSISTENT_SATURATED_MODE_IMPLEMENTATION`.

## Smooth no-event preservation

The persistent mode is never entered on the original smooth TIMEINT16C bank.

The unchanged smooth bank must retain:

- 4/4 complete ladders;
- median refined head order >=1.6;
- median refined moisture order >=1.6;
- >=3/4 individual head orders >=1.5;
- physical/cumulative ledger <= `5e-8 cm`;
- median work ratio versus KLAG BE <=1.15.

If this regresses:

`CLOSED_PERSISTENT_SATURATED_MODE_ORDER_REGRESSION`.

## Positive consequence

A positive result establishes at research level that:

- the saturation event is localized;
- post-event temporal regime switching is required;
- persistent head/KLAG evolution on the saturated branch is sufficient over the frozen target horizon.

It would then authorize a separate full 96-case dynamic-top bank and a separate physical release-condition attribution.

It does not authorize production integration by itself.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14D

BASELINE: `c0995bd21b2b755cd25337c1b407752d5cb44fb9`

BRANCH: `research/f-pe-nlglob14d-persistent-saturated-mode`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: materialize persistent saturated-mode state in the NLGLOB14C research harness and run target + smooth banks

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
