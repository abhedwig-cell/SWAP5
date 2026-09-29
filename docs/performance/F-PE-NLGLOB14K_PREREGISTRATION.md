# F-PE-NLGLOB14K preregistration — mixed-profile temporal-mode ownership attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@667c4b76768f760403e0b58383c386686baa3784`

Reconciliation note:

This r2 preregistration preserves the frozen mixed-profile ownership question and gates from the earlier preregistration on `e803842a...`. The intervening canonical delta is ELASTIC23-only and does not alter the NLGLOB14/TIMEINT17 temporal-policy, constitutive, forcing-reversal, saturation-indicator or physical-mass dependency surface. No NLGLOB14K result had been exposed before this r2 postimage.

Parent authority:

- TIMEINT17 requalification: `QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE_RESEARCH_POLICY`;
- NLGLOB14I: lower saturated block expands upward under dry forcing;
- NLGLOB14J: `NLGLOB14J_DOWNWARD_REDISTRIBUTION_EXPLAINS_BLOCK_EXPANSION`.

## Purpose

NLGLOB14J established that the expanding lower saturated block is physically supported by downward redistribution and is not a mass/state inconsistency.

The remaining question is temporal-mode ownership.

Persistent saturated KLAG currently owns the whole column after first saturation entry, even after:

- ponding disappears;
- the surface route returns to `surface-flux`;
- the top and upper profile are unsaturated;
- only a contiguous lower block remains saturated.

NLGLOB14K asks whether the upper unsaturated region is already independently compatible with the existing TG temporal mechanism while the lower saturated block still requires saturated treatment.

The workunit is observational only.

No release or mode switch is introduced.

## Frozen fixtures

Reuse exactly the 8 NLGLOB14G-J forcing-reversal fixtures:

- material O05;
- TG wet-entry mode;
- HEAD and RUNOFF wet-entry routes;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- horizon = 0.012 d;
- identical wet-to-dry forcing reversal;
- unchanged complete same-route research policy;
- unchanged S0/R0 endpoint certificates;
- unchanged physical mass authority.

## Mixed-profile onset

For each fixture define the first accepted dry-phase interval satisfying all:

1. actual provider route is `surface-flux`;
2. ponding <= `1e-12 cm`;
3. top node is unsaturated under both existing saturation indicators;
4. at least one saturated node remains;
5. saturated nodes form one contiguous lower block ending at node 16;
6. at least one unsaturated node lies above that block.

Call this interval:

`MIXED_PROFILE_ONSET`.

If no such state occurs, the fixture does not support mixed-profile ownership attribution.

## Upper-region TG admissibility

At every accepted state from MIXED_PROFILE_ONSET onward, let s be the shallowest saturated node.

The upper region is nodes `1:(s-1)`.

For every active upper-region node require:

1. pressure head < 0;
2. water content < theta_s;
3. constitutive capacity C(h) is finite and > 0;
4. accepted state is finite;
5. provider theta(h) roundtrip is within `1e-12`;
6. the head-space chain-rule quantity `h_dot = theta_dot / C(h)` is finite when evaluated from the current accepted-state physical moisture derivative;
7. one-step endpoint head predictor `h_tilde = h + dt*h_dot` is finite.

These are the existing NLGLOB11A/TIMEINT16C admissibility ingredients applied only to the unsaturated upper region.

No capacity floor or clipping is introduced.

## Lower-block persistence

At every accepted state from MIXED_PROFILE_ONSET onward record:

- saturated-node count;
- shallowest saturated node;
- whether the lower saturated set remains contiguous;
- lower-block storage;
- downward edge flux;
- bottom flux.

The lower block is considered physically persistent only while:

- saturation indicators agree;
- it remains contiguous;
- state remains finite.

## Frozen fixture classifications

### UPPER_TG_LOWER_SATURATED_SPLIT

Classify if all hold:

1. MIXED_PROFILE_ONSET exists;
2. from onset onward, every upper-region node passes all TG-admissibility checks;
3. lower saturated block persists and remains contiguous;
4. lower-block edge flux/state remain finite;
5. physical mass remains closed;
6. no process failure occurs.

### WHOLE_COLUMN_SATURATED_OWNERSHIP_STILL_REQUIRED

Classify if mixed onset exists but upper-region TG admissibility fails in any accepted post-onset state while lower-block state remains valid.

### NO_MIXED_PROFILE_ONSET

Classify if no mixed-profile onset occurs.

### MIXED_PROFILE_STATE_INCONSISTENT

Classify if saturation indicators disagree, lower saturated set becomes noncontiguous, or state/constitutive evaluation becomes nonfinite.

Otherwise:

`MIXED_MODE_OWNERSHIP_SIGNAL`.

## Frozen aggregate interpretation

If 8/8 fixtures classify `UPPER_TG_LOWER_SATURATED_SPLIT`:

`NLGLOB14K_SPATIALLY_SPLIT_TEMPORAL_OWNERSHIP_SIGNAL`.

If 8/8 classify `WHOLE_COLUMN_SATURATED_OWNERSHIP_STILL_REQUIRED`:

`NLGLOB14K_WHOLE_COLUMN_SATURATED_OWNERSHIP_SUPPORTED`.

If any fixture classifies `MIXED_PROFILE_STATE_INCONSISTENT`:

`NLGLOB14K_MIXED_PROFILE_STATE_INCONSISTENT`.

Otherwise:

`NLGLOB14K_MIXED_TEMPORAL_OWNERSHIP`.

## Consequence

A positive spatial-split signal does not authorize a release switch.

It would establish that the current whole-column persistent saturated mode is broader than required by the upper-region state and would justify a separately preregistered split-ownership or release-policy experiment.

A whole-column-support result would keep persistent saturated KLAG ownership as the current research policy and require another physical release mechanism.

## Stop rules

Do not:

- implement a switch in NLGLOB14K;
- change the dry horizon or forcing;
- introduce a capacity floor;
- clip h, theta or h_tilde;
- change saturation indicators;
- change timestep, mass gates, K staging or nonlinear policy.

## Architecture invariants

Affected invariants: 7, 13, 20, 23, 25, 26, 30.

Expected effect: observational only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14K

BASELINE: `667c4b76768f760403e0b58383c386686baa3784`

BRANCH: `research/f-pe-nlglob14k-mixed-profile-ownership-r2`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: evaluate mixed-profile onset and upper-region TG admissibility on the unchanged 8 dry fixtures

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
