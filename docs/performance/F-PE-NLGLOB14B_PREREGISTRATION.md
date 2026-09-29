# F-PE-NLGLOB14B preregistration — conservative saturation-event split and remainder integration

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ea6a0617ded0c2e6bee89640e090a0aed8a558c2`

Parent authority:

- TIMEINT16C: provider-consistent endpoint TG staging is second order on the smooth bank;
- NLGLOB12A1: representation-aware endpoint certificate is qualified at research level;
- NLGLOB14A: all 5 frozen O05/TG saturation events are root-localized conservatively within the existing `5e-8 cm` event-distance authority.

## Purpose

NLGLOB14B tests the first complete conservative saturation-event split.

The event time is no longer the blocker.

The frozen question is:

**if the accepted TG trajectory is integrated to the localized saturation boundary and the remaining fraction of the same nominal interval is then integrated from that event state with the dynamic-top provider reevaluated, can the original interval complete conservatively and remain physically admissible?**

This is research/test-only.

## Frozen event targets

Use the same five NLGLOB14A primary targets:

- O05 / TG / HEAD / dt = 0.00025 d;
- O05 / TG / HEAD / dt = 0.000125 d;
- O05 / TG / HEAD / dt = 0.0000625 d;
- O05 / TG / RUNOFF / dt = 0.00025 d;
- O05 / TG / RUNOFF / dt = 0.000125 d.

## Frozen event mechanics

For a nominal interval of duration `h` whose prospective accepted TG state crosses `theta_s`:

1. restore the exact committed interval origin;
2. localize the first saturation event using the unchanged NLGLOB14A bracket-preserving bisection;
3. retain the admissible lower-bracket event state at fraction `phi_event`;
4. require event water-depth distance <= `5e-8 cm`;
5. treat the localized event state as the internal accepted state of subinterval 1;
6. reevaluate the dynamic-top provider, constitutive provider and current-step derivative from that event state;
7. integrate subinterval 2 over exactly:
   `h_rem = (1-phi_event) h`;
8. publish only the final state at the end of the original nominal interval;
9. restore the nominal `h` after the internal split.

No clipping of accepted moisture is allowed.

No recursive event split is authorized in NLGLOB14B.

If the remainder subinterval itself encounters another accepted-state saturation crossing, the target fails closed as:

`EVENT_REMAINDER_SECOND_CROSSING`.

## Frozen mass contract

Let:

- `M0` be storage at the nominal interval origin;
- `M1` be storage at the localized event state;
- `M2` be storage at the final remainder state.

Subinterval physical ledgers are evaluated using the unchanged existing driver logic.

The nominal interval ledger is the exact sum of the two subinterval ledgers.

No storage-derived external flux reconstruction is allowed.

Required:

- each subinterval ledger <= `5e-8 cm`;
- full nominal interval ledger <= `5e-8 cm`;
- cumulative trajectory ledger <= `5e-8 cm`.

## Route/event semantics

At the localized event:

- dynamic-top provider is reevaluated from the event state;
- event route must be explicit and finite;
- the remainder may continue in the same route or a different physically resolved route;
- any route change must be diagnosed explicitly.

No route is forced to remain equal to the pre-event route.

This is the first workunit allowed to observe route change at the saturation event.

It does not yet qualify general endogenous event localization outside this saturation-specific mechanism.

## Mandatory Bank E — event-target completion

All five frozen targets must be executed.

A target counts as completed only if:

1. event root localizes successfully;
2. event state is finite and retention-admissible;
3. event subinterval ledger <= `5e-8 cm`;
4. remainder duration is positive and finite;
5. remainder solve completes without a second saturation crossing;
6. final state is finite and retention-admissible;
7. nominal interval mass ledger <= `5e-8 cm`;
8. route/provider state is explicitly resolved before and after the event.

## Mandatory Bank S — smooth order preservation

Reuse the original TIMEINT16C smooth fixed-flux bank with event logic present but inactive.

Frozen gates:

- 4/4 ladders complete;
- median refined top-head order >= 1.6;
- median refined top-theta order >= 1.6;
- >=3/4 individual refined head orders >=1.5;
- physical/cumulative ledgers <= `5e-8 cm`;
- constitutive roundtrip <= `1e-12`;
- endpoint native balance residual <= `5e-8 cm/d`;
- median deterministic work ratio versus KLAG BE <=1.15;
- zero spurious saturation-event activations.

## Full-bank diagnostic

Also rerun the 96-case dynamic-top bank with:

- head-space endpoint coefficient staging from NLGLOB11A;
- unchanged S0 replay;
- qualified representation-aware R0 replay;
- NLGLOB14B event split.

The full bank is diagnostic and reports:

- completion fraction;
- remaining terminal-reason counts;
- event split count;
- route-change count;
- physical mass maxima.

It is not allowed to hide a failing mandatory Bank E or Bank S gate.

## Frozen classifications

Positive:

`QUALIFIED_CONSERVATIVE_SATURATION_EVENT_SPLIT_RESEARCH`

only if:

1. 5/5 Bank E targets complete;
2. Bank S passes all smooth second-order gates;
3. no physical mass, finite-state or retention-domain failure occurs;
4. no second saturation crossing occurs inside the remainder;
5. all event/remainder route states are explicitly resolved.

If event localization succeeds but at least 3/5 remainder solves fail:

`CLOSED_SATURATION_EVENT_SPLIT_REMAINDER_INSUFFICIENT`.

If any mass or state safety gate fails:

`CLOSED_SATURATION_EVENT_SPLIT_PHYSICAL_ADMISSIBILITY_FAILED`.

If smooth second-order authority is lost:

`CLOSED_SATURATION_EVENT_SPLIT_ORDER_REGRESSION`.

If diagnostic coverage fails:

`BLOCKED_SATURATION_EVENT_SPLIT_COVERAGE`.

## Consequence

A positive NLGLOB14B result would remove the current near-saturation TG blocker at research level for the frozen event bank.

It would authorize returning to TIMEINT17 same-route/dynamic-top mechanism qualification with:

- provider-consistent TG staging;
- S0/R0 representation-aware endpoint policy;
- saturation-event split.

It would not yet authorize production integration or general event localization.

## Stop rules

Do not:

- recurse on a second saturation event;
- clip accepted theta;
- damp the remainder duration;
- alter event-distance authority;
- alter S0/R0;
- increase MAXIT/backtracking;
- change BALTOL02;
- change K-staging ownership.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14B

BASELINE: `ea6a0617ded0c2e6bee89640e090a0aed8a558c2`

BRANCH: `research/f-pe-nlglob14b-conservative-event-split`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: materialize conservative event split, then run Bank E, Bank S and full-bank diagnostics

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
