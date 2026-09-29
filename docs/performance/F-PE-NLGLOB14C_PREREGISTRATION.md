# F-PE-NLGLOB14C preregistration — saturated-remainder KLAG regime switch

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@31901d9bbb75d87e8723c09f6804dabbcc25c219`

Parent authority:

- TIMEINT16C: provider-consistent TG endpoint staging is second order on the smooth bank;
- NLGLOB12A1/NLGLOB12C: representation-aware endpoint termination is qualified at research level;
- NLGLOB14A: saturation-event root localization succeeds for 5/5 frozen O05/TG near-saturation targets;
- NLGLOB14B: unchanged TG remainder fails accepted-state retention admissibility in 5/5 targets.

## Purpose

NLGLOB14C tests one bounded regime-switch hypothesis:

once the TG accepted trajectory reaches the localized saturation boundary, the remainder of that nominal interval should no longer use the unsaturated moisture-based TG accepted-state construction.

The event-localized state is retained exactly.

The remaining duration is integrated once with the existing implicit head-based/KLAG endpoint formulation.

The no-event TG path remains unchanged.

## Frozen target set

Use exactly the five NLGLOB14A/B targets:

- O05 / TG / HEAD / dt = 0.00025 d;
- O05 / TG / HEAD / dt = 0.000125 d;
- O05 / TG / HEAD / dt = 0.0000625 d;
- O05 / TG / RUNOFF / dt = 0.00025 d;
- O05 / TG / RUNOFF / dt = 0.000125 d.

## Frozen algorithm

For the first prospective accepted TG saturation crossing in a nominal interval:

1. restore the exact nominal accepted origin;
2. localize the event with the unchanged NLGLOB14A bracket-preserving root algorithm;
3. require the retained event state to satisfy the existing event-distance, mass, finite-state and route guards;
4. internally commit that event state as the origin of the remainder;
5. compute the exact remainder duration:
   `h_rem = h_nominal - h_event`;
6. reevaluate the dynamic-top provider from the event state;
7. set the local integration duration to `h_rem`;
8. integrate exactly one remainder step with the existing KLAG/head-based endpoint formulation;
9. retain unchanged S0/R0 research endpoint certificates for the remainder endpoint;
10. publish only the final full nominal-interval state.

No second event localization or recursive split is allowed.

## Transaction semantics

Before the event split, save:

- nominal accepted origin;
- cumulative physical ledger;
- runoff accumulation;
- maximum interval ledger;
- terminal/route diagnostic state.

If event localization or KLAG remainder integration fails, restore the nominal origin and fail closed.

Only successful event localization plus successful remainder integration completes the nominal interval.

## Frozen physical mass contract

The event and remainder use their existing physical ledgers.

The nominal split ledger is:

`L_nominal = L_event + L_remainder`.

Require:

- absolute nominal interval ledger <= `5e-8 cm`;
- cumulative trajectory ledger <= `5e-8 cm`.

No external flux may be reconstructed from storage.

## Mandatory smooth bank

Reuse the original TIMEINT16C smooth fixed-flux bank with head-space endpoint staging.

The event logic must remain inactive.

Frozen gates:

- 4/4 ladders complete;
- median refined top-head order >=1.6;
- median refined top-theta order >=1.6;
- >=3/4 individual head orders >=1.5;
- physical/cumulative ledgers <= `5e-8 cm`;
- constitutive roundtrip <= `1e-12`;
- native endpoint balance residual <= `5e-8 cm/d`;
- median work ratio <=1.15x KLAG BE.

## Frozen target qualification gates

Classify:

`QUALIFIED_TG_SATURATION_EVENT_KLAG_REMAINDER_RESEARCH`

only if all five targets satisfy:

1. event localized under unchanged NLGLOB14A authority;
2. event state finite and retention-admissible;
3. event subinterval physical ledger <= `5e-8 cm`;
4. exact remainder duration finite and >0;
5. KLAG remainder completes;
6. final state finite and route-consistent;
7. no accepted-state retention-domain failure;
8. no recursive event/split;
9. nominal split ledger <= `5e-8 cm`;
10. cumulative ledger <= `5e-8 cm`;
11. smooth bank remains qualified.

If >=3/5 KLAG remainders fail endpoint convergence:

`CLOSED_TG_KLAG_REMAINDER_ENDPOINT_FAILED`.

If mass/route/state safety fails:

`CLOSED_TG_KLAG_REMAINDER_PHYSICAL_ADMISSIBILITY_FAILED`.

If smooth second order regresses:

`CLOSED_TG_KLAG_REMAINDER_ORDER_REGRESSION`.

If coverage fails:

`BLOCKED_NLGLOB14C_COVERAGE`.

Otherwise:

`NLGLOB14C_MIXED_REGIME_SWITCH_SIGNAL`.

## Positive consequence

A positive result authorizes a separate full 96-case dynamic-top qualification with:

- TG on unsaturated no-event intervals;
- localized saturation event handling;
- KLAG remainder only after the event.

It does not yet authorize production integration.

## Stop rules

Do not:

- recurse the event split;
- use KLAG before an event;
- clip accepted theta;
- alter S0/R0, BALTOL02, MAXIT, backtracking or K staging;
- tune event location;
- switch back to TG within the same remainder.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14C

BASELINE: `31901d9bbb75d87e8723c09f6804dabbcc25c219`

BRANCH: `research/f-pe-nlglob14c-saturated-remainder-klag`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: materialize one-event TG-to-KLAG remainder switch and execute smooth plus five-target qualification

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
