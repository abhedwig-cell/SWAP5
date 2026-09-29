# F-PE-NLGLOB14M preregistration — first saturated-block retreat event localization

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@246eca153a7846c07e4981a07c6498528b771ee5`

Parent authority:

- TIMEINT17 requalification: `QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE_RESEARCH_POLICY`;
- NLGLOB14L: all 8 frozen dry fixtures exhibit partial retreat after a 14-node saturation maximum within 0.05 d.

## Purpose

NLGLOB14L provides the first repeatable physical retreat event in the persistent saturated-mode line.

NLGLOB14M localizes the first retreat of the saturated lower block without changing temporal mode.

The target transition is:

`14 saturated nodes -> 13 saturated nodes`.

The workunit is observational only.

## Frozen fixtures

Reuse exactly the 8 NLGLOB14L fixtures:

- O05;
- TG before saturation entry;
- persistent saturated KLAG after entry;
- HEAD and RUNOFF wet-entry routes;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- total horizon = 0.05 d;
- unchanged dry forcing;
- unchanged S0/R0 endpoint policy;
- unchanged physical mass authority.

## Frozen event definition

NLGLOB14L shows that the peak saturated set contains nodes 3:16.

The first retreat event is the first loss of node 3 from the saturated set while nodes 4:16 remain saturated.

Use the constitutive saturation boundary of node 3 as event function:

`g(t) = h_3(t)`.

The physical event is:

`g = 0`.

This is not an empirical pressure threshold. It is the constitutive boundary separating:

- saturated state: `h_3 >= 0`, `theta_3 = theta_s`;
- unsaturated state: `h_3 < 0`, `theta_3 < theta_s`.

## Frozen bracket

For every fixture identify:

- `t_lo`: last accepted state with saturated-node count 14 and node 3 saturated;
- `t_hi`: first subsequent accepted state with saturated-node count 13 and node 3 unsaturated.

Require:

- `t_hi - t_lo = dt`;
- `h_3(t_lo) >= 0`;
- `h_3(t_hi) < 0`;
- nodes 4:16 remain saturated at both bracket endpoints;
- saturation indicators agree;
- state and mass remain valid.

## Frozen event-time estimator

Use linear interpolation in the physical event function only:

`phi = h_lo / (h_lo - h_hi)`.

Require `0 <= phi <= 1`.

Estimated event time:

`t_event = t_lo + phi * (t_hi-t_lo)`.

No state is accepted at the interpolated point and no substep solve is performed.

This estimator is diagnostic only.

## Frozen convergence gates

For each route family separately, the event localization qualifies only if:

1. all four dt fixtures produce valid brackets;
2. all event estimates are finite and lie inside their brackets;
3. the two finest event-time estimates differ by no more than:
   `2 * dt_finest = 6.25e-5 d`;
4. bracket width halves with dt;
5. bracket endpoints remain finite, route-consistent and mass-clean.

Full NLGLOB14M qualifies if both HEAD and RUNOFF families pass.

Positive:

`QUALIFIED_FIRST_RETREAT_EVENT_LOCALIZATION`.

If valid brackets exist but refined event times fail the frozen convergence criterion:

`NLGLOB14M_RETREAT_EVENT_TIME_NOT_CONVERGED`.

If node-3 sign change or 14->13 bracket is absent/inconsistent:

`NLGLOB14M_RETREAT_EVENT_BRACKET_INVALID`.

If coverage fails:

`BLOCKED_NLGLOB14M_RETREAT_LOCALIZATION`.

## Consequence

A positive result qualifies the physical first-retreat event as a temporally localizable moving saturated-block boundary event.

It does not authorize release to TG.

A successor may then test repeated retreat-event tracking of the moving upper edge of the saturated lower block, eventually including the terminal disappearance event.

## Stop rules

Do not:

- change the event node after result exposure;
- introduce an empirical pressure threshold;
- change the 0.05 d horizon;
- change forcing, dt levels or saturation indicators;
- switch modes;
- run a root solve inside NLGLOB14M.

## Architecture invariants

Affected invariants: 7, 13, 23, 25, 26, 30.

Expected effect: observational only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14M

BASELINE: `246eca153a7846c07e4981a07c6498528b771ee5`

BRANCH: `research/f-pe-nlglob14m-first-retreat-localization`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: evaluate the frozen node-3 retreat bracket and event-time convergence on the 8 fixtures

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
