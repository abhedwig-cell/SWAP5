# F-PE-NLGLOB14H preregistration — dry-phase saturation-manifold drift attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@c963cacfc86e3f0df5f318ac6a6ffce23bf92225`

Parent authority:

- NLGLOB14E: `QUALIFIED_COMPLETE_DYNAMIC_TOP_RESEARCH_POLICY`;
- NLGLOB14F: `NLGLOB14F_NO_RELEASE_IN_FROZEN_HORIZON`;
- NLGLOB14G: `NLGLOB14G_NO_RELEASE_UNDER_FROZEN_REVERSAL`.

## Purpose

NLGLOB14G showed that an explicit dry surface-forcing reversal does not release the original saturation-event node within 0.012 d.

NLGLOB14H determines whether the accepted event-node state is nevertheless moving toward desaturation, or is effectively stationary on the saturated constitutive manifold despite net profile drying.

This workunit is observational only.

No forcing, temporal policy, release rule or mode switch is changed.

## Frozen population and forcing

Reuse the exact eight NLGLOB14G O05/TG forcing-reversal fixtures unchanged:

- HEAD and RUNOFF;
- four dt levels;
- original wet saturation-entry forcing;
- after persistent saturated-mode entry:
  - precipitation = 0;
  - potential bare-soil evaporation = original wet precipitation rate;
  - potential pond evaporation = original wet precipitation rate;
- horizon = 0.012 d;
- persistent saturated KLAG remains active throughout attribution.

## Frozen diagnostics

For every accepted dry-phase persistent-KLAG interval record the same NLGLOB14F node states and NLGLOB14G forcing diagnostics.

For each fixture derive:

### Event-node head drift

Let:

- `h_first` = event-node pressure head in the first accepted dry-phase persistent interval;
- `h_last` = event-node pressure head in the final accepted dry-phase interval;
- `Delta h = h_last - h_first`.

Define representational head scale:

`U_h = 32 * (ulp(h_first) + ulp(h_last))`.

A material head drift exists when:

`|Delta h| > U_h`.

### Monotone drying direction

Across consecutive accepted dry-phase intervals, count the fraction of event-node transitions with:

`h_(k+1) <= h_k`.

A trajectory has sustained drying direction when this fraction is >=0.90.

### Event-node moisture state

Record:

- first and final `theta_s-theta_event`;
- whether `theta_event == theta_s` throughout;
- whether any accepted head/moisture saturation indicators disagree.

### Profile storage and ponding

The fixture geometry is exactly 16 nodes of 10 cm thickness.

For each accepted dry-phase interval define:

`S = 10 cm * sum_i(theta_i) + ponding`.

Record:

- first and final S;
- `Delta S = S_last - S_first`;
- first and final ponding depth;
- first and final provider route;
- first and final top and bottom flux.

A profile has net drying when:

`Delta S < 0`.

No magnitude threshold is added.

## Frozen classifications

If all 8 fixtures satisfy:

- material negative event-node head drift: `Delta h < -U_h`;
- sustained drying direction >=0.90;
- net profile drying `Delta S < 0`;
- no head/moisture indicator inconsistency;

classify:

`NLGLOB14H_EVENT_NODE_MOVING_TOWARD_DESATURATION`.

If all 8 fixtures satisfy:

- `|Delta h| <= U_h`;
- event-node `theta == theta_s` throughout;
- net profile drying `Delta S < 0`;

classify:

`NLGLOB14H_EVENT_NODE_PINNED_ON_SATURATED_MANIFOLD`.

Otherwise, if coverage and physical guards pass:

`NLGLOB14H_MIXED_DRY_MANIFOLD_DRIFT`.

If any accepted head/moisture saturation indicators disagree:

`NLGLOB14H_SATURATION_STATE_INCONSISTENT`.

If coverage, mass, finite-state or forcing guards fail:

`BLOCKED_NLGLOB14H_DRIFT_ATTRIBUTION`.

## Consequence

A full moving-toward-desaturation result may justify a separately preregistered longer-horizon observation fixture using unchanged forcing.

A pinned result does **not** justify merely extending the horizon. It requires attribution of why the saturated temporal formulation or boundary configuration keeps the event node on the saturated manifold while the profile loses water.

A mixed result requires route/dt attribution before any release semantics.

## Stop rules

Do not change:

- forcing magnitude;
- horizon;
- bottom boundary;
- release threshold;
- mode state;
- timestep or temporal formulation.

No release switch is implemented in NLGLOB14H.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14H

BASELINE: `c963cacfc86e3f0df5f318ac6a6ffce23bf92225`

BRANCH: `research/f-pe-nlglob14h-dry-manifold-drift`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: rerun the exact NLGLOB14G fixtures and quantify accepted dry-phase drift

## Production boundary

Research diagnostics only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
