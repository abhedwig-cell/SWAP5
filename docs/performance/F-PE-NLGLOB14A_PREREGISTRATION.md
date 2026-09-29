# F-PE-NLGLOB14A preregistration — bracketed saturation-event root localization

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@b7e5acf9ea297d3d59f0b28202d34a0ccc96dd5e`

Parent authority:

- TIMEINT16C: provider-consistent endpoint TG staging is second order on the smooth bank;
- NLGLOB13C2: same-origin temporal refinement contracts near-saturation accepted-state overshoot;
- NLGLOB13D: bounded subdivision through h/8 is insufficient;
- NLGLOB14: the saturation event is bracketed in all five frozen targets, but the one-shot linear event fraction is insufficient.

## Purpose

NLGLOB14A localizes the saturation-boundary event from the temporal method itself.

The frozen event function is:

`g(phi) = max_i(theta_TG^*(phi h)-theta_s,i)`.

Here `theta_TG^*(phi h)` is the uncommitted prospective accepted TG moisture state produced from the same accepted physical origin over subinterval `phi h`.

No accepted state is clipped.

## Frozen target set

Use the same five NLGLOB14 primary targets:

- O05 / TG / HEAD / dt = 0.00025 d;
- O05 / TG / HEAD / dt = 0.000125 d;
- O05 / TG / HEAD / dt = 0.0000625 d;
- O05 / TG / RUNOFF / dt = 0.00025 d;
- O05 / TG / RUNOFF / dt = 0.000125 d.

## Frozen initial bracket

For each target:

- lower endpoint: `phi_lo = 0`, the accepted origin, strictly retention-admissible;
- upper endpoint: `phi_hi = phi_linear` from NLGLOB14;
- NLGLOB14 authority establishes the upper event trial as retention-inadmissible.

The same crossing node selected by the current prospective event function is recorded at every evaluation.

## Frozen root algorithm

Use bracket-preserving bisection only.

At each iteration:

1. `phi_mid = 0.5*(phi_lo+phi_hi)`;
2. restore the exact accepted origin;
3. execute one uncommitted TG prospective trial over `phi_mid h`;
4. if the prospective accepted state is retention-inadmissible above `theta_s`, set `phi_hi = phi_mid`;
5. if the prospective accepted state is retention-admissible, set `phi_lo = phi_mid` and retain this admissible candidate as the current event state;
6. never use secant, Newton, interpolation damping, clipping or extrapolation outside the bracket.

Maximum bisection evaluations:

`32`.

## Frozen localization stop

A retained admissible lower-bracket candidate is localized when, at its active crossing node,

`|theta_s-theta_event| * dz_selected <= 5e-8 cm`.

This is the existing physical water-depth authority expressed at the event node.

No new theta tolerance is introduced.

The event state must also satisfy:

- all nodes `theta <= theta_s`;
- all state quantities finite;
- physical event-subinterval ledger <= `5e-8 cm`;
- route finite and explicitly resolved by the dynamic-top provider.

If the stop criterion is not reached within 32 bisection evaluations, localization fails closed.

## P0 scope

P0 localizes the event only.

It does not integrate the remainder of the nominal interval.

No event state is committed to a subsequent subinterval in P0.

Record for every target:

- initial `phi_linear`;
- final `phi_lo` and `phi_hi`;
- bisection count;
- selected crossing node;
- event-state signed saturation distance;
- event water-depth distance;
- maximum domain overshoot;
- route;
- ponding;
- physical event-subinterval ledger;
- finite-state status.

## Frozen qualification gates

Classify:

`NLGLOB14A_SATURATION_EVENT_ROOT_LOCALIZED`

only if all five targets satisfy:

1. valid initial bracket;
2. no process failure;
3. localized admissible lower-bracket event within 32 evaluations;
4. event water-depth distance <= `5e-8 cm`;
5. no node above `theta_s`;
6. physical event-subinterval ledger <= `5e-8 cm`;
7. finite state;
8. dynamic-top route is explicitly resolved and valid.

If at least 3/5 fail to reach the physical event-distance criterion within 32 evaluations:

`NLGLOB14A_BISECTION_LOCALIZATION_INSUFFICIENT`.

If any accepted event state violates mass, route or finite-state safety:

`NLGLOB14A_EVENT_ROOT_PHYSICAL_ADMISSIBILITY_FAILED`.

If the initial bracket or diagnostic coverage is invalid:

`BLOCKED_NLGLOB14A_EVENT_ROOT_COVERAGE`.

## Positive consequence

A positive P0 authorizes a separately preregistered conservative event-split workunit that:

1. integrates and commits to the localized saturation event;
2. reevaluates the boundary/route at that event;
3. integrates the remainder interval under explicitly resolved saturated/dynamic-top semantics;
4. preserves the full nominal-interval physical mass ledger;
5. preserves smooth second-order behavior when no event occurs.

## Stop rules

Do not:

- increase the bisection limit after result exposure;
- introduce a multiplicative event-distance factor;
- clip accepted moisture;
- use secant/Newton extrapolation;
- interpret bisection as recursive timestep halving;
- modify BALTOL02, S0/R0, MAXIT, backtracking or K-staging ownership.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14A

BASELINE: `b7e5acf9ea297d3d59f0b28202d34a0ccc96dd5e`

BRANCH: `research/f-pe-nlglob14a-saturation-root`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: materialize bounded bisection event-root probe and execute the frozen five-target bank

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
