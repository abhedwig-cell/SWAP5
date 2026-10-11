# F-PE-NLGLOB14B preregistration — conservative saturation-event split and remainder integration

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ea6a0617ded0c2e6bee89640e090a0aed8a558c2`

Parent authority:

- NLGLOB14A: `NLGLOB14A_SATURATION_EVENT_ROOT_LOCALIZED`;
- NLGLOB12A1: `QUALIFIED_REPRESENTATION_AWARE_ENDPOINT_CERTIFICATE_RESEARCH`;
- TIMEINT16C smooth provider-consistent TG authority remains second order.

## Purpose

Test whether the localized saturation event can be used as an internal transactional split of the nominal TG interval.

The mechanism must preserve physical mass, provider-consistent coefficient staging and the nominal-interval accepted state semantics.

## Frozen target set

Use the five NLGLOB14A targets:

- O05 / TG / HEAD / dt = 0.00025 d;
- O05 / TG / HEAD / dt = 0.000125 d;
- O05 / TG / HEAD / dt = 0.0000625 d;
- O05 / TG / RUNOFF / dt = 0.00025 d;
- O05 / TG / RUNOFF / dt = 0.000125 d.

## Frozen event-split algorithm

For a nominal interval that produces accepted-state saturation overshoot:

1. restore the exact accepted origin;
2. localize the event using the unchanged NLGLOB14A bisection;
3. require the retained lower event state to satisfy the NLGLOB14A event-distance, mass, finite-state and route guards;
4. internally accept that event state as a subinterval state;
5. compute the exact remaining duration:
   `h_rem = h - h_event`;
6. reevaluate the dynamic-top provider from the event state;
7. integrate one TG remainder interval of duration `h_rem` with unchanged head-space endpoint K staging and unchanged S0/R0 research endpoint certificates;
8. publish only the final state of the full nominal interval to the outer trajectory.

The event split is allowed at most once per nominal interval.

No recursive event split, h/16 subdivision or accepted-theta clipping is allowed.

## Frozen mass contract

For the complete nominal interval:

`ledger_nominal = ledger_event + ledger_remainder`.

Require:

- absolute nominal ledger <= `5e-8 cm`;
- cumulative trajectory ledger <= `5e-8 cm`.

Each internal subinterval retains the unchanged physical accounting.

## Mandatory target gates

Classify:

`QUALIFIED_TG_SATURATION_EVENT_SPLIT_RESEARCH`

only if all five frozen targets:

1. execute without process failure;
2. localize the event within NLGLOB14A authority;
3. complete the remainder interval;
4. complete the requested horizon;
5. retain finite states;
6. retain explicit provider-consistent route resolution;
7. have max nominal accepted-interval ledger <= `5e-8 cm`;
8. have cumulative ledger <= `5e-8 cm`;
9. require no accepted-state clipping;
10. require no recursive event split.

## Smooth-order preservation

The event-split mechanism must be inactive on the original smooth TIMEINT16C bank.

The unchanged smooth bank must retain:

- 4/4 complete ladders;
- median refined head order >=1.6;
- median refined moisture order >=1.6;
- >=3/4 individual head orders >=1.5;
- physical/cumulative ledgers <= `5e-8 cm`;
- median work ratio versus KLAG BE <=1.15.

## Frozen negative classifications

If >=3/5 target remainders again become retention-inadmissible:

`CLOSED_TG_EVENT_SPLIT_REMAINDER_DOMAIN_FAILED`.

If event localization succeeds but remainder endpoint solve fails in >=3/5:

`CLOSED_TG_EVENT_SPLIT_REMAINDER_ENDPOINT_FAILED`.

If mass, route or finite-state safety fails:

`CLOSED_TG_EVENT_SPLIT_PHYSICAL_ADMISSIBILITY_FAILED`.

If smooth second order regresses:

`CLOSED_TG_EVENT_SPLIT_ORDER_REGRESSION`.

If coverage fails:

`BLOCKED_NLGLOB14B_EVENT_SPLIT_COVERAGE`.

## Positive consequence

A positive result authorizes a full 96-case dynamic-top qualification pass with the event-split mechanism active, followed by return to TIMEINT17 same-route qualification.

## Stop rules

Do not:

- recursively split the remainder;
- clip accepted theta;
- alter BALTOL02, S0/R0, MAXIT, backtracking or K staging;
- empirically move the localized event time;
- change dynamic-top route physics.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14B

BASELINE: `ea6a0617ded0c2e6bee89640e090a0aed8a558c2`

BRANCH: `research/f-pe-nlglob14b-saturation-event-split`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: materialize single-event split on the five frozen targets and run smooth-order regression

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
