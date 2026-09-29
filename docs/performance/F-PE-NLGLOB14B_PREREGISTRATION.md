# F-PE-NLGLOB14B preregistration — conservative saturation-event split and remainder integration

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ea6a0617ded0c2e6bee89640e090a0aed8a558c2`

Parent authority:

- NLGLOB14: one-shot linear event localization is insufficient;
- NLGLOB14A: `NLGLOB14A_SATURATION_EVENT_ROOT_LOCALIZED`, with 5/5 events localized by bracket-preserving bisection within the existing `5e-8 cm` physical event-distance authority.

## Purpose

NLGLOB14B tests whether a localized saturation event can be used as an internal transactional split of one nominal TG interval.

The workunit integrates:

1. from the accepted nominal origin to the localized saturation event;
2. from that event state through the exact remainder of the same nominal interval.

P0 of NLGLOB14A already qualified event localization. NLGLOB14B tests event-state commit, route reevaluation, remainder integration and complete nominal-interval mass closure.

## Frozen target set

Use the same five NLGLOB14A O05/TG targets:

- HEAD, nominal dt = 0.00025 d;
- HEAD, nominal dt = 0.000125 d;
- HEAD, nominal dt = 0.0000625 d;
- RUNOFF, nominal dt = 0.00025 d;
- RUNOFF, nominal dt = 0.000125 d.

Only the first saturation event in the first failing nominal interval is handled.

## Frozen event localization

Use the qualified NLGLOB14A algorithm unchanged:

- same accepted origin;
- same event function `g(phi)`;
- bracket-preserving bisection;
- maximum 32 evaluations;
- retained admissible lower-bracket state;
- stop at `|theta_s-theta_event|*dz <= 5e-8 cm`.

No event-localization threshold changes.

## Frozen split mechanics

After positive localization:

1. retain the localized admissible event state as an internal committed subinterval state;
2. record the event fraction `phi_event`;
3. set
   `dt_rem = (1-phi_event) * dt_nominal`;
4. reevaluate the dynamic-top provider at the event state;
5. use the explicitly resolved event-state route as the active route for the remainder trial;
6. execute one TG remainder trial over `dt_rem` using unchanged head-space/provider-consistent endpoint coefficient staging and unchanged S0/R0 research endpoint certificates;
7. do not subdivide or localize a second event inside the remainder;
8. stop the research trajectory after the remainder trial and report the complete nominal-interval split result.

No intermediate event state is published externally as a nominal accepted state.

## Transaction and rollback contract

Before the split, save:

- accepted physical origin;
- cumulative physical ledger;
- runoff accumulation;
- maximum ledger;
- terminal/route diagnostic state.

If localization or remainder integration fails, restore the nominal origin and fail closed.

Only a successful event plus successful remainder constitutes a completed split interval.

## Full nominal-interval mass

Define the split-interval physical ledger as the sum of the unchanged physical subinterval ledgers:

`L_split = L_event + L_remainder`.

Equivalently in the test harness:

`L_split = cumledger_after_remainder - cumledger_before_event`.

No flux is reconstructed from storage.

## Mandatory smooth bank

Reuse the original TIMEINT16C smooth fixed-flux bank with head-space endpoint staging.

Frozen gates remain:

- 4/4 ladders complete;
- median refined top-head order >=1.6;
- median refined top-theta order >=1.6;
- >=3/4 individual head orders >=1.5;
- mass and roundtrip gates unchanged;
- median work ratio <=1.15x KLAG BE.

Event logic is inactive on this bank.

## Frozen split qualification gates

Classify:

`QUALIFIED_TG_SATURATION_EVENT_SPLIT_RESEARCH`

only if all five target intervals satisfy:

1. event localized under unchanged NLGLOB14A authority;
2. event state finite and retention-admissible;
3. event subinterval ledger <= `5e-8 cm`;
4. event-state dynamic-top route is explicitly resolved;
5. remainder duration is finite and strictly positive;
6. remainder trial completes without domain, endpoint, route, ponding or nonfinite failure;
7. complete split nominal-interval ledger <= `5e-8 cm`;
8. no accepted theta clipping or constitutive extrapolation occurs;
9. no second event/subdivision is invoked;
10. smooth bank passes unchanged.

If at least 3/5 remainder trials fail retention admissibility:

`CLOSED_TG_EVENT_SPLIT_REMAINDER_DOMAIN_FAILED`.

If mass/route/state safety fails:

`CLOSED_TG_EVENT_SPLIT_PHYSICAL_ADMISSIBILITY_FAILED`.

If smooth second order regresses:

`CLOSED_TG_EVENT_SPLIT_ORDER_REGRESSION`.

If coverage fails:

`BLOCKED_NLGLOB14B_EVENT_SPLIT_COVERAGE`.

Otherwise:

`NLGLOB14B_MIXED_EVENT_SPLIT_SIGNAL`.

## Positive consequence

A positive result authorizes a separate full-horizon same-route/dynamic-route qualification workunit using the event split.

It does not yet admit production code.

## Stop rules

Do not:

- localize a second event in the remainder;
- recursively subdivide the remainder;
- clip accepted moisture;
- alter S0/R0, BALTOL02, MAXIT or backtracking;
- tune the event fraction after result exposure.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14B

BASELINE: `ea6a0617ded0c2e6bee89640e090a0aed8a558c2`

BRANCH: `research/f-pe-nlglob14b-event-split`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: materialize one-event split wrapper and execute smooth plus five-target qualification

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
