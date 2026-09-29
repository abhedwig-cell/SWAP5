# F-PE-NLGLOB14C preregistration — saturated-remainder temporal regime switch

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@31901d9bbb75d87e8723c09f6804dabbcc25c219`

Parent authority:

- NLGLOB14A: `NLGLOB14A_SATURATION_EVENT_ROOT_LOCALIZED`;
- NLGLOB14B: `CLOSED_TG_EVENT_SPLIT_REMAINDER_DOMAIN_FAILED`;
- NLGLOB12A1/NLGLOB12C: representation-aware endpoint certificate is qualified at research level;
- TIMEINT16C/NLGLOB11A: no-event provider-consistent TG remains second order.

## Purpose

NLGLOB14B established that the saturation event can be localized and integrated conservatively, but that continuing the same unsaturated moisture-based TG accepted-state construction over the remainder is inadmissible.

NLGLOB14C tests one bounded post-event temporal regime switch:

- TG before the saturation event;
- existing implicit head-based/KLAG endpoint formulation for the exact remainder.

The no-event TG path remains unchanged.

## Frozen target set

Use the same five O05/TG near-saturation targets:

- HEAD, nominal dt = 0.00025 d;
- HEAD, nominal dt = 0.000125 d;
- HEAD, nominal dt = 0.0000625 d;
- RUNOFF, nominal dt = 0.00025 d;
- RUNOFF, nominal dt = 0.000125 d.

## Frozen event localization

Use NLGLOB14A unchanged:

- same accepted nominal origin;
- same accepted TG event function;
- bracket-preserving bisection;
- maximum 32 evaluations;
- event physical-distance criterion <= `5e-8 cm`;
- no clipping.

## Frozen regime switch

After positive event localization:

1. retain the localized event state as the exact internal remainder origin;
2. reevaluate the dynamic-top provider at that state;
3. define exact remainder duration:
   `dt_rem = (1-phi_event) * dt_nominal`;
4. bind the existing KLAG/current-state K provider at the event origin;
5. execute one existing implicit head-based/KLAG endpoint solve over `dt_rem`;
6. use the provider-resolved event route as the required remainder route;
7. publish only the final split nominal-interval state if the remainder succeeds.

No TG accepted-moisture averaging is applied on the remainder.

No second event or nested split is allowed.

## Transaction and mass contract

Before the event process save the exact nominal origin and cumulative ledgers.

If localization or KLAG remainder fails, restore the nominal origin and fail closed.

For a successful split:

- event subinterval ledger <= `5e-8 cm`;
- KLAG remainder physical ledger <= `5e-8 cm`;
- full nominal split ledger <= `5e-8 cm`;
- cumulative trajectory ledger <= `5e-8 cm`.

No external flux is reconstructed from storage.

## Mandatory smooth no-event bank

Reuse the TIMEINT16C smooth fixed-flux bank with head-space endpoint TG staging.

The event logic must be inactive.

Frozen gates:

- 4/4 complete;
- median refined top-head order >=1.6;
- median refined top-theta order >=1.6;
- >=3/4 individual head orders >=1.5;
- physical/cumulative ledgers <=5e-8 cm;
- retention roundtrip <=1e-12;
- median work ratio <=1.15x KLAG BE.

## Frozen target gates

Classify:

`QUALIFIED_TG_TO_KLAG_SATURATED_REMAINDER_RESEARCH`

only if all five target intervals satisfy:

1. event localized under unchanged NLGLOB14A authority;
2. event state finite and retention-admissible;
3. event physical ledger <=5e-8 cm;
4. event-state route explicitly resolved;
5. exact positive finite remainder duration;
6. KLAG remainder solve converges;
7. final remainder state finite and route-consistent;
8. final water content remains within constitutive domain;
9. full split nominal ledger <=5e-8 cm;
10. no recursive event/split is used;
11. mandatory smooth bank passes unchanged.

If at least 3/5 KLAG remainder solves fail endpoint convergence:

`CLOSED_SATURATED_KLAG_REMAINDER_ENDPOINT_FAILED`.

If at least 3/5 complete but violate mass/state/route authority:

`CLOSED_SATURATED_KLAG_REMAINDER_PHYSICAL_ADMISSIBILITY_FAILED`.

If smooth order regresses:

`CLOSED_SATURATED_KLAG_REMAINDER_ORDER_REGRESSION`.

If coverage fails:

`BLOCKED_NLGLOB14C_COVERAGE`.

Otherwise:

`NLGLOB14C_MIXED_SATURATED_REMAINDER_SIGNAL`.

## Positive consequence

A positive result removes the five frozen O05/TG near-saturation temporal-admissibility failures at research level.

It authorizes a separate full-horizon 96-case dynamic-top qualification using:

- no-event TG;
- saturation event root;
- KLAG remainder after saturation;
- S0/R0 endpoint certificates.

Production admission remains separate.

## Stop rules

Do not:

- use another temporal method on the pre-event segment;
- apply TG averaging again on the KLAG remainder;
- recursively split the remainder;
- clip accepted moisture;
- alter BALTOL02, S0/R0, MAXIT or backtracking;
- alter K-staging ownership.

## Architecture invariants

Affected invariants: 7, 9, 13, 20, 23, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14C

BASELINE: `31901d9bbb75d87e8723c09f6804dabbcc25c219`

BRANCH: `research/f-pe-nlglob14c-klag-remainder`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: materialize TG-event plus one KLAG remainder and execute smooth plus five-target qualification

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
