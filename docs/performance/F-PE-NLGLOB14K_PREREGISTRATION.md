# F-PE-NLGLOB14K preregistration — mixed-profile temporal-mode ownership attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@e803842a434d792ba5209f71e3681bd78be90560`

Parent authority:

- TIMEINT17 requalification: `QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE_RESEARCH_POLICY`;
- NLGLOB14D: `QUALIFIED_PERSISTENT_SATURATED_TEMPORAL_MODE_RESEARCH`;
- NLGLOB14I: contiguous lower saturated block expands under dry forcing;
- NLGLOB14J: `NLGLOB14J_DOWNWARD_REDISTRIBUTION_EXPLAINS_BLOCK_EXPANSION`.

## Purpose

NLGLOB14J established that the spatially mixed dry-phase state is physically mass-consistent.

The remaining question is numerical-policy ownership:

once the surface and upper profile are unsaturated while a contiguous lower saturated block remains, is full-column persistent KLAG still required by TG admissibility, or is the unsaturated upper region already locally compatible with the ordinary TG predictor?

NLGLOB14K is observational only.

No split-domain solver and no switch back to TG is implemented.

## Frozen fixtures

Reuse exactly the 8 NLGLOB14G-J forcing-reversal fixtures:

- O05;
- TG before saturation entry;
- persistent saturated KLAG after entry;
- HEAD and RUNOFF wet-entry routes;
- four dt levels;
- 0.012 d horizon;
- unchanged forcing reversal;
- unchanged S0/R0 endpoint policy;
- unchanged physical mass authority.

## Mixed-profile state

For each accepted dry-phase state define a mixed-profile state when all hold:

1. surface provider route is `surface-flux`;
2. ponding is zero within numerical representation;
3. node 1 is unsaturated;
4. at least one lower node remains saturated;
5. saturated nodes form one contiguous lower block ending at node 16;
6. state is finite and saturation indicators agree.

For each fixture record the first accepted mixed-profile interval and all later accepted mixed-profile intervals.

## Upper-region TG admissibility probe

At every mixed-profile state:

- let s be the shallowest saturated node;
- the upper candidate TG region is nodes 1:(s-1);
- evaluate the same constitutive provider on the accepted pressure-head state;
- evaluate the same current-state physical flux divergence used by the existing TG origin derivative;
- construct the ordinary current-step moisture predictor on upper nodes only:

`theta_tilde_i = theta_i + dt * theta_dot_i`.

The probe is `UPPER_TG_ADMISSIBLE` only if, for every upper node:

- predictor is finite;
- `theta_r < theta_tilde_i < theta_s`;
- no upper-node constitutive-domain failure occurs.

The lower saturated block is not converted to TG and is not altered.

This probe is diagnostic only.

## Frozen diagnostics

For every mixed-profile interval record:

- shallowest saturated node;
- saturated-node count;
- number of unsaturated upper nodes;
- upper-region predictor minimum/maximum;
- minimum normalized distance to either retention bound;
- whether all upper nodes are TG-admissible;
- surface route and ponding;
- physical mass diagnostics from the enclosing trajectory.

Also report:

- first mixed-profile interval;
- fraction of mixed-profile intervals that are upper-TG-admissible;
- whether admissibility persists once first achieved.

## Frozen classifications

### UPPER_TG_REGION_ADMISSIBLE

A fixture classifies this way only if:

1. at least one mixed-profile interval occurs;
2. at least 95% of mixed-profile intervals are upper-TG-admissible;
3. every mixed-profile interval after the first admissible interval remains admissible;
4. state and mass remain valid.

### UPPER_TG_REGION_NOT_ADMISSIBLE

Classify if fewer than 50% of mixed-profile intervals are upper-TG-admissible.

### UPPER_TG_ADMISSIBILITY_MIXED

Otherwise.

Any state/indicator inconsistency classifies:

`MIXED_PROFILE_STATE_INCONSISTENT`.

## Frozen aggregate interpretation

If 8/8 fixtures classify `UPPER_TG_REGION_ADMISSIBLE`:

`NLGLOB14K_UPPER_TG_REGION_ADMISSIBLE_WITH_LOWER_SATURATED_BLOCK`.

If 8/8 classify `UPPER_TG_REGION_NOT_ADMISSIBLE`:

`NLGLOB14K_FULL_COLUMN_KLAG_STILL_REQUIRED_BY_TG_DOMAIN`.

If any inconsistency occurs:

`NLGLOB14K_MIXED_PROFILE_STATE_INCONSISTENT`.

Otherwise:

`NLGLOB14K_MIXED_MODE_OWNERSHIP_SIGNAL`.

## Consequence

A positive upper-region admissibility result does not authorize domain splitting.

It would establish that persistent full-column KLAG is conservative but potentially broader than required by local TG constitutive admissibility.

A separately preregistered hybrid temporal-domain experiment would then be needed.

A negative result supports retaining full-column KLAG until physical desaturation of the lower block.

## Stop rules

Do not:

- switch any node or region back to TG in NLGLOB14K;
- change forcing or horizon;
- alter saturation indicators;
- alter dt, K staging, mass gates or nonlinear policy;
- infer a release threshold.

## Architecture invariants

Affected invariants: 7, 13, 20, 23, 25, 26, 30.

Expected effect: observational only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14K

BASELINE: `e803842a434d792ba5209f71e3681bd78be90560`

BRANCH: `research/f-pe-nlglob14k-mode-ownership`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: evaluate upper-region TG admissibility on the frozen mixed-profile dry fixtures

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
