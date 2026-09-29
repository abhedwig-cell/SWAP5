# F-PE-NLGLOB14L preregistration — extended dry-horizon saturated-block evolution attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@67e6abbacf53aada2f2613644446eea826602806`

Parent authority:

- TIMEINT17 requalification: `QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE_RESEARCH_POLICY`;
- NLGLOB14I: saturated lower block expands from 1 to 14 nodes under the 0.012 d dry fixture;
- NLGLOB14J: block expansion is explained by mass-consistent downward redistribution;
- NLGLOB14K: upper-region TG admissibility is mixed and nonpersistent while the lower saturated block remains.

## Purpose

NLGLOB14J removed the main scientific objection to extending the dry fixture: the growing lower saturated block is mass-consistent internal redistribution rather than a state inconsistency.

NLGLOB14L therefore tests whether, under a fixed longer dry forcing horizon, the lower saturated block eventually:

1. reaches a maximum extent;
2. begins to retreat;
3. and possibly disappears completely.

The workunit is observational only.

No release switch is implemented.

## Frozen fixtures

Reuse the exact 8 O05/TG forcing-reversal fixtures used by NLGLOB14G-K:

- wet-entry routes: HEAD and RUNOFF;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- unchanged complete same-route research policy;
- unchanged saturation root/event policy;
- unchanged persistent saturated KLAG mode;
- unchanged S0/R0 endpoint certificates;
- unchanged dry forcing.

## Frozen extended horizon

Set total horizon to exactly:

`0.05 d`.

This is fixed before result exposure.

Do not stop early when a desired release pattern appears.

Do not extend beyond 0.05 d inside NLGLOB14L if no release occurs.

## Saturated-set diagnostics

For every accepted persistent-mode dry interval, derive:

- saturated-node count;
- shallowest saturated node;
- deepest saturated node;
- whether saturated nodes form one contiguous lower block ending at node 16;
- top-node saturation state;
- surface route;
- ponding;
- total profile storage;
- top flux;
- bottom flux.

Also retain physical interval and cumulative mass diagnostics.

## Frozen lifecycle measures

For each fixture record:

- initial saturated-node count;
- maximum saturated-node count;
- first step/time at maximum count;
- last step/time at maximum count;
- first later step where count becomes smaller than the maximum;
- final saturated-node count;
- first step/time with zero saturated nodes, if any.

## Frozen fixture classifications

### FULL_DESATURATION_AFTER_PEAK

Require all:

1. saturated set remains contiguous whenever nonempty;
2. maximum saturated-node count exceeds the initial count;
3. after the last occurrence of the maximum, saturated-node count later decreases;
4. saturated-node count reaches zero before the fixed 0.05 d horizon;
5. state remains finite and mass-clean.

### PARTIAL_RETREAT_AFTER_PEAK

Require:

1. contiguous saturated set throughout;
2. maximum count exceeds initial count;
3. final count is smaller than maximum count;
4. final count remains >0;
5. state remains finite and mass-clean.

### NO_RETREAT_WITHIN_FIXED_HORIZON

Require:

- saturated set remains contiguous;
- maximum count exceeds initial count;
- final count equals the maximum count;
- no post-maximum decrease occurs.

### NONCONTIGUOUS_OR_INCONSISTENT

Any noncontiguous saturated set, indicator inconsistency, nonfinite state or physical mass failure.

Otherwise:

`MIXED_EXTENDED_HORIZON_EVOLUTION`.

## Frozen aggregate interpretation

If 8/8 fixtures classify `FULL_DESATURATION_AFTER_PEAK`:

`NLGLOB14L_FULL_DESATURATION_OBSERVED`.

If all 8 show either full desaturation or partial retreat, and at least 4 show full desaturation:

`NLGLOB14L_SATURATED_BLOCK_RETREAT_CONFIRMED`.

If 8/8 classify `NO_RETREAT_WITHIN_FIXED_HORIZON`:

`NLGLOB14L_NO_RETREAT_WITHIN_0P05D`.

If any fixture is inconsistent:

`NLGLOB14L_EXTENDED_HORIZON_STATE_INCONSISTENT`.

Otherwise:

`NLGLOB14L_MIXED_EXTENDED_HORIZON_EVOLUTION`.

## Consequence

A positive full-desaturation result would provide direct physical evidence for a release event defined by disappearance of the saturated set, without inventing a pressure-head threshold.

A partial-retreat result would justify a separately preregistered release-event localization study but not yet a switch.

A no-retreat result closes this 0.05 d fixture and requires separate physical attribution before extending the horizon again.

## Stop rules

Do not:

- change the 0.05 d horizon after observing results;
- alter dry forcing;
- change dt levels;
- invent a release threshold;
- switch back to TG;
- change saturation indicators, mass gates or nonlinear policy.

## Architecture invariants

Affected invariants: 7, 13, 23, 25, 26, 30.

Expected effect: observational only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14L

BASELINE: `67e6abbacf53aada2f2613644446eea826602806`

BRANCH: `research/f-pe-nlglob14l-extended-dry-horizon`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: execute the frozen eight fixtures through 0.05 d and classify saturated-block lifecycle

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
