# F-PE-NLGLOB14I preregistration — dry-phase saturated-set migration attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@cf0430071c060d29ee1346ee2f21142fdfe19438`

Parent authority:

- TIMEINT17 requalification: `QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE_RESEARCH_POLICY`;
- NLGLOB14G: `NLGLOB14G_NO_RELEASE_UNDER_FROZEN_REVERSAL`;
- NLGLOB14H: `NLGLOB14H_MIXED_DRY_MANIFOLD_DRIFT`.

## Purpose

NLGLOB14H showed that the original saturation-event node remains saturated and becomes more positively pressurized while the profile as a whole dries and the surface route returns to flux control.

NLGLOB14I asks whether desaturation is nevertheless progressing spatially through the profile.

The workunit is observational only. No release switch is introduced.

## Frozen fixtures

Reuse exactly the 8 NLGLOB14G/H forcing-reversal fixtures:

- material O05;
- TG mode;
- HEAD and RUNOFF wet-entry routes;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- horizon = 0.012 d;
- identical wet-to-dry forcing reversal;
- unchanged complete same-route research policy;
- unchanged physical mass authority.

## Saturated-set definition

For each accepted dry-phase state and active node i, define saturated only when both existing indicators agree:

- `SAT_H_i = 1`;
- `SAT_THETA_i = 1`.

Any disagreement is a state-consistency failure.

For every accepted dry-phase interval derive:

1. number of saturated nodes;
2. shallowest saturated node;
3. deepest saturated node;
4. whether the saturated nodes form one contiguous lower block ending at node 16;
5. number of unsaturated nodes above that lower block;
6. surface route;
7. ponding;
8. storage;
9. top and bottom flux.

For the `LOWER_BLOCK_PERSISTENT` classification, “profile storage decreases materially” is frozen before results as:

`S_first - S_last > U_S`

with `S = sum_i(theta_i dz_i) + pond` and `U_S` equal to the sum of the endpoint floating-point representation scales `(ulp(theta_first_i)+ulp(theta_last_i))*dz_i` plus `ulp(pond_first)+ulp(pond_last)`. No multiplicative factor above one is used.

## Frozen trajectory classifications

### LOWER_BLOCK_RETREAT

A fixture classifies `LOWER_BLOCK_RETREAT` only if:

- every nonempty saturated set is one contiguous lower block ending at node 16;
- saturated-node count decreases at least once during the dry phase;
- saturated-node count never increases after its first decrease;
- top node is unsaturated by the final dry-phase state;
- state remains finite and mass-clean.

### LOWER_BLOCK_PERSISTENT

Classify `LOWER_BLOCK_PERSISTENT` if:

- saturated set remains a contiguous lower block;
- saturated-node count is unchanged throughout the dry phase;
- profile storage decreases materially.

### NONCONTIGUOUS_SATURATION_PATTERN

Classify if any accepted state contains a noncontiguous saturated set.

### SATURATION_INDICATOR_INCONSISTENT

Classify if SAT_H and SAT_THETA disagree at any node/accepted dry state.

Otherwise:

`MIXED_SATURATED_SET_MIGRATION`.

## Frozen aggregate interpretation

If 8/8 fixtures classify `LOWER_BLOCK_RETREAT`:

`NLGLOB14I_LOWER_SATURATED_BLOCK_RETREATS`.

If 8/8 classify `LOWER_BLOCK_PERSISTENT`:

`NLGLOB14I_LOWER_SATURATED_BLOCK_PERSISTS`.

If any noncontiguous pattern appears:

`NLGLOB14I_NONCONTIGUOUS_SATURATION_PATTERN`.

If any indicator inconsistency appears:

`NLGLOB14I_SATURATION_INDICATOR_INCONSISTENT`.

Otherwise:

`NLGLOB14I_MIXED_SATURATED_SET_MIGRATION`.

## Consequence

A positive retreat result may justify a separately preregistered release criterion based on the moving upper edge of the persistent lower saturated block, rather than the original saturation-event node.

A persistent-block result means release cannot be inferred from the current 0.012 d fixture and requires separate physical attribution before any longer-horizon or release-state-machine work.

## Stop rules

Do not:

- invent a pressure-head release threshold;
- extend the horizon in NLGLOB14I;
- change dry forcing;
- change saturation indicators;
- introduce a release switch;
- change timestep, mass gates, K staging or nonlinear policy.

## Architecture invariants

Affected invariants: 7, 13, 23, 25, 26, 30.

Expected effect: observational only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14I

BASELINE: `cf0430071c060d29ee1346ee2f21142fdfe19438`

BRANCH: `research/f-pe-nlglob14i-saturated-set-migration-r2`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: evaluate saturated-set migration on the unchanged 8 dry-phase fixtures

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
