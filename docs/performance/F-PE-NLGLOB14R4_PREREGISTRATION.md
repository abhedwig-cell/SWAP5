# F-PE-NLGLOB14R4 preregistration — post-release saturation-root invalid-bracket attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent research authority:

- NLGLOB14R3: `NLGLOB14R3_MIXED_RETRY_DEPTH`;
- nine of twelve bounded-retry fixtures terminate at deep retry with `SATURATION_ROOT_BRACKET_INVALID`;
- three of twelve remain retry-advised through all eight retries.

## Purpose

NLGLOB14R3 showed that post-release TG retry does not find accepted internal progress.

At sufficiently small retry dt, nine fixtures transition from solver retry-advised outcomes to the saturation-root globalization path, which then declares its bracket invalid.

NLGLOB14R4 attributes that invalid bracket without changing root semantics.

The central question is:

does the root globalization represent a genuinely new unsaturated-to-saturated crossing, or is it being invoked because ordinary full-column TG is evaluated from an origin that already contains a persistent 13-node saturated lower block?

## Frozen bank

Replay all 12 R3 fixtures with the same:

- O05 material;
- HEAD and RUNOFF wet-entry families;
- six nominal dt levels;
- first-retreat accepted TG handoff;
- accepted first TG interval;
- second-interval bounded retry ladder;
- retry scale 0.5;
- maximum 8 retries;
- dry forcing;
- surface-flux route;
- NLGLOB14N3 saturation-root retry policy.

The nine R3 bracket-invalid fixtures are the attribution bank.

The three R3 retry-budget-exhausted fixtures are frozen negative controls.

## Frozen diagnostics

At every retry attempt for which the NLGLOB14A wrapper receives `domain_fail=true`, record before root classification:

1. retry depth and attempted dt;
2. accepted-origin saturated-node count and exact saturated-node set;
3. the specific TG-core domain-failure stage:
   - predictor retention-domain failure;
   - post-endpoint TG retention-domain failure;
   - other existing domain-return site;
4. for every node:
   - accepted-origin theta;
   - theta_s;
   - current candidate/predictor theta relevant to the triggering stage;
   - candidate minus theta_s;
   - whether the node was already saturated at the accepted origin;
5. for every node that is unsaturated at the origin and exceeds theta_s in the candidate:
   - computed `phi_i=(theta_s-theta_origin)/(theta_candidate-theta_origin)`;
6. the root wrapper's selected event_node and phi_hi;
7. whether at least one genuine new unsaturated-to-saturated crossing exists.

Do not use stale candidate arrays as crossing evidence. If the TG core exits before a candidate array is freshly defined for that stage, record that candidate as unavailable.

## Frozen invalid-bracket classifications

### INVALID_BRACKET_NO_NEW_CROSSING

Classify a bracket-invalid attempt when:

- the accepted origin already contains saturated nodes;
- no origin-unsaturated node has a freshly defined candidate value above theta_s;
- root event_node is zero or no valid phi exists.

### INVALID_BRACKET_STALE_CANDIDATE_SURFACE

Classify when root selection inspects a candidate array that was not freshly defined by the domain-failure stage that triggered globalization.

### INVALID_BRACKET_NEW_CROSSING_BUT_PHI_INVALID

Classify when at least one genuine new unsaturated-to-saturated crossing exists but all corresponding phi values are nonfinite or outside (0,1).

### INVALID_BRACKET_NEW_CROSSING_SELECTION_FAILURE

Classify when a valid new crossing and valid phi exist but the current root selector nevertheless returns event_node=0 or an inconsistent selected node.

### CONTROL_NO_INVALID_BRACKET

For the three frozen retry-exhausted controls, require no bracket-invalid event inside retry depths 1..8.

### ROOT_ATTRIBUTION_STATE_INCONSISTENT

Classify on nonfinite accepted origin, saturation-indicator disagreement, rollback leakage or accepted physical-mass failure.

## Frozen aggregate interpretation

If all nine bracket-invalid fixtures classify `INVALID_BRACKET_NO_NEW_CROSSING` and all three controls classify `CONTROL_NO_INVALID_BRACKET`:

`NLGLOB14R4_ROOT_GLOBALIZATION_WITHOUT_NEW_CROSSING`.

If all nine bracket-invalid fixtures classify `INVALID_BRACKET_STALE_CANDIDATE_SURFACE`:

`NLGLOB14R4_ROOT_GLOBALIZATION_USES_STALE_CANDIDATE`.

If classifications reveal genuine new crossings:

`NLGLOB14R4_GENUINE_POSTRELEASE_SATURATION_EVENT_SIGNAL`.

If attribution differs by fixture:

`NLGLOB14R4_MIXED_ROOT_INVALIDITY`.

Any state/mass inconsistency:

`NLGLOB14R4_ROOT_ATTRIBUTION_STATE_INCONSISTENT`.

## Consequence

A no-new-crossing result would show that the current saturation-root globalization is being asked to localize an event that is already present in the accepted origin. A later successor may then test a root-controller distinction between pre-existing saturated ownership and a genuinely new crossing.

A stale-candidate result would require a diagnostic/algorithmic repair before interpreting the event.

A genuine-crossing result would keep root localization as the relevant mechanism and require a different bracket repair.

## Stop rules

Do not:

- change saturation-root selection;
- suppress globalization;
- change retry scale or budget;
- change dt, forcing or route semantics;
- change provider capacity;
- change solver tolerances or iteration limits;
- switch temporal ownership;
- modify production source.

## Architecture invariants

Affected invariants: 2, 3, 4, 7, 9, 13, 20, 23, 25, 26, 30.

Expected effect: diagnostics only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14R4

BRANCH: `research/f-pe-nlglob14r4-postrelease-root-bracket-attribution`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: instrument TG-core domain-failure stage and root candidate freshness, then replay the frozen R3 bank unchanged.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
