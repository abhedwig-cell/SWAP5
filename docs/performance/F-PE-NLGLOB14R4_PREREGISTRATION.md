# F-PE-NLGLOB14R4 preregistration — post-release saturation-root invalid-bracket attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent research authority:

- NLGLOB14R3: `NLGLOB14R3_MIXED_RETRY_DEPTH`;
- 9/12 frozen fixtures terminate deep bounded retry with `SATURATION_ROOT_BRACKET_INVALID`;
- 3/12 exhaust the existing retry budget without an invalid bracket.

## Mechanistic hypothesis

NLGLOB14A declares a TG domain failure when any node has:

`theta_tg > theta_s`.

Its event-node search then requires:

- `theta_tg > theta_s`;
- `theta_tg > theta_origin`;
- `phi_i = (theta_s-theta_origin)/(theta_tg-theta_origin) > 0`.

At the post-release retry origin, nodes 4:16 are already saturated with `theta_origin = theta_s`.

If TG predictor overshoot occurs only on those already-saturated nodes, then:

`phi_i = 0`

for each overshooting saturated node. Such nodes trigger `domain_fail` but cannot form a valid positive root bracket, leaving `event_node=0`.

NLGLOB14R4 tests this hypothesis observationally.

## Frozen fixtures

Reuse the exact NLGLOB14R3 12-case retry-depth bank and unchanged bounded retry ladder.

Only the 9 fixtures that actually reach `SATURATION_ROOT_BRACKET_INVALID` contribute to the positive mechanism classification.

The 3 retry-budget-exhausted fixtures remain control observations.

## Frozen diagnostics at first invalid bracket

For the first `SATURATION_ROOT_BRACKET_INVALID` attempt in each affected fixture record:

- retry depth;
- attempted dt;
- current saturated-node count;
- for every node:
  - origin theta;
  - theta_s;
  - TG predictor theta_tg;
  - origin saturation flag;
  - predictor overshoot `theta_tg-theta_s`;
  - whether it is a new unsaturated-to-saturated crossing;
  - computed phi_i where denominator is positive;
- aggregate counts:
  - overshooting nodes;
  - overshooting nodes already saturated at origin;
  - genuine new crossing nodes;
  - valid positive phi candidates;
- selected event_node;
- phi_hi.

No root-search rule is changed.

## Frozen fixture classifications

### EXISTING_SATURATED_OVERSHOOT_WITHOUT_NEW_CROSSING

Require:

1. bracket-invalid is reproduced;
2. at least one node has `theta_tg > theta_s`;
3. every overshooting node was already saturated at the accepted retry origin;
4. zero genuine unsaturated-to-saturated crossing nodes exist;
5. zero valid positive phi candidates exist;
6. event_node = 0.

### NEW_CROSSING_PRESENT_BUT_BRACKET_INVALID

Classify if at least one genuine new crossing exists but no valid bracket is selected.

### BRACKET_INVALID_OTHER

Classify if bracket-invalid reproduces but neither mechanism above explains it.

### NO_INVALID_BRACKET

For the frozen retry-budget-exhausted controls that never reach bracket-invalid.

## Frozen aggregate interpretation

If all 9 bracket-invalid fixtures classify
`EXISTING_SATURATED_OVERSHOOT_WITHOUT_NEW_CROSSING`:

`NLGLOB14R4_INVALID_BRACKET_IS_ALREADY_SATURATED_OVERSHOOT`.

If any invalid fixture contains a genuine new crossing:

`NLGLOB14R4_INVALID_BRACKET_INCLUDES_NEW_CROSSING`.

Otherwise:

`NLGLOB14R4_MIXED_INVALID_BRACKET_MECHANISM`.

## Consequence

A positive already-saturated-overshoot result would show that the current post-release TG domain detector conflates:

- constitutive/predictor overshoot inside an already saturated lower block;

with:

- a new saturation-entry event that requires root localization.

That would justify a separately preregistered event-classification repair, not an ad hoc threshold.

## Stop rules

Do not:

- alter the `theta_tg > theta_s` domain condition;
- alter event-node selection;
- admit phi = 0;
- change capacity regularization;
- change retry scale/budget;
- change release timing or mode ownership;
- change solver tolerances;
- modify production source.

## Architecture invariants

Affected invariants: 7, 9, 13, 20, 23, 25, 26, 30.

Expected effect: diagnostics only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14R4

BRANCH: `research/f-pe-nlglob14r4-invalid-bracket-attribution`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: instrument the first invalid bracket on the frozen R3 retry bank and classify origin-saturated overshoot versus genuine new crossing.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
