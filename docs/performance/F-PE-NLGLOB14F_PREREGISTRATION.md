# F-PE-NLGLOB14F preregistration — saturated-mode release attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@0324f5dac58444aa956ecb1031022e99e8c1f170`

Parent authority:

- TIMEINT16C: unsaturated provider-consistent TG is second order on the smooth bank;
- NLGLOB14A: the first saturation crossing is a localizable temporal event;
- NLGLOB14C: the first post-event remainder is admissible with KLAG/head-based integration;
- NLGLOB14D: persistent saturated KLAG mode is sufficient on the five frozen near-saturation targets;
- NLGLOB14E: the assembled research policy completes 96/96 frozen dynamic-top cases with mass and finite-state gates passing.

## Purpose

NLGLOB14D deliberately introduced no release rule.

NLGLOB14F determines what physical/numerical state variable can support a later transition from persistent `SATURATED_KLAG` back to `UNSATURATED_TG`.

This workunit is observational only.

It does not switch modes.

## Frozen population

Use every TG trajectory in the qualified 96-case NLGLOB14E bank that enters persistent saturated mode.

No case may be added or removed after outcome exposure.

For every accepted persistent-KLAG interval after entry, record the accepted state at every node.

## Frozen diagnostics

For each accepted saturated-mode interval and node i record:

- pressure head `h_i`;
- water content `theta_i`;
- `theta_s,i - theta_i`;
- whether `h_i >= 0`;
- whether `theta_i == theta_s,i` at floating-point representation;
- dynamic-top route;
- top flux, bottom flux and ponding depth.

For the original saturation-event node record the same diagnostics separately.

Define the constitutive active-set indicators:

`SAT_H(i) = (h_i >= 0)`

and

`SAT_THETA(i) = (theta_i == theta_s,i)`.

No tolerance is added to these definitions.

## Frozen questions

P0 asks:

1. Does the original event node remain on the saturated constitutive manifold throughout the frozen horizon?
2. If it leaves that manifold, is the first release represented consistently by both:
   - `h_event < 0`;
   - `theta_event < theta_s`?
3. Are any other nodes still saturated when the event node releases?
4. Is release associated with a route transition or can it occur within the same dynamic-top route?
5. Does the frozen bank contain any natural release trajectory at all?

## Frozen classifications

If one or more trajectories show a finite accepted transition from:

- event-node `h >= 0, theta = theta_s`

to:

- event-node `h < 0, theta < theta_s`

with no contradictory saturated node requiring the mode to remain active:

`NLGLOB14F_NATURAL_DESATURATION_SIGNAL`.

If all event-entry trajectories remain on the saturated manifold through the complete frozen horizon:

`NLGLOB14F_NO_RELEASE_IN_FROZEN_HORIZON`.

If head and moisture indicators disagree materially at accepted states:

`NLGLOB14F_RELEASE_STATE_INCONSISTENT`.

If coverage/diagnostics fail:

`BLOCKED_NLGLOB14F_RELEASE_ATTRIBUTION`.

## Consequence

A natural desaturation signal authorizes a separately preregistered release-event localization workunit.

If no release exists in the frozen horizon, open a separate forcing-reversal fixture workunit. That fixture must create a physically explicit drainage/drying condition before any release rule is selected.

NLGLOB14F does not authorize a release threshold, hysteresis band or mode switch.

## Stop rules

Do not introduce:

- an empirical head threshold;
- a theta deficit threshold;
- release hysteresis;
- forced switch back to TG;
- changed boundary forcing;
- changed bottom-boundary physics;
- tolerance or timestep changes.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14F

BASELINE: `0324f5dac58444aa956ecb1031022e99e8c1f170`

BRANCH: `research/f-pe-nlglob14f-desaturation-attribution`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: instrument accepted persistent-KLAG states on the qualified full-bank policy

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
