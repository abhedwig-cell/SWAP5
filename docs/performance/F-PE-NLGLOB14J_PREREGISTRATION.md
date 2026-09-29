# F-PE-NLGLOB14J preregistration — dry-phase lower-block mass redistribution attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@6fe778ffb5a55f6fb3cc13b9c1a43b71a4641096`

Parent authority:

Reconciliation note: r2 preserves the original frozen NLGLOB14J fixtures, flux definition and classification gates unchanged on current canonical after admission of NLGLOB14I and NLGLOB15A. No NLGLOB14J result had been exposed before this r2 postimage.


- TIMEINT17 requalification: `QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE_RESEARCH_POLICY`;
- NLGLOB14H: `NLGLOB14H_MIXED_DRY_MANIFOLD_DRIFT`;
- NLGLOB14I: `NLGLOB14I_MIXED_SATURATED_SET_MIGRATION`.

## Purpose

NLGLOB14I established a consistent but counterintuitive dry-phase pattern:

- profile storage decreases;
- the surface becomes unsaturated and returns to flux control;
- the saturated set remains one contiguous lower block;
- saturated-node count grows from 1 to 14.

NLGLOB14J asks whether that upward expansion is explained by downward internal redistribution from the drying upper profile into the lower block.

The workunit is observational only.

No release switch is introduced.

## Frozen fixtures

Reuse exactly the 8 NLGLOB14G-I forcing-reversal fixtures:

- O05;
- TG;
- HEAD and RUNOFF wet-entry routes;
- four dt levels;
- 0.012 d horizon;
- unchanged complete same-route research policy;
- unchanged dry forcing;
- unchanged physical mass authority.

## Frozen internal-flux definition

For every accepted dry-phase state, evaluate the same constitutive provider on the accepted pressure-head profile and obtain node conductivities K_i.

For an internal interface between upper node i and lower node i+1 define the existing SWAP-form interface flux:

`q_(i+1/2) = -Kmean * ((h_i-h_(i+1))/distance + 1)`

with the same arithmetic K mean as the frozen test bank.

Under this convention, negative q denotes downward flow.

Define:

`q_down = -q`.

No flux is reconstructed from storage.

## Moving saturated-block edge

For every accepted dry-phase state:

- let s be the shallowest saturated node of the contiguous lower block;
- if s>1, the block-edge interface is between nodes s-1 and s;
- record q_edge and q_down_edge;
- if s=1, the whole profile is saturated and no upper-edge interface exists.

Also record:

- saturated-node count;
- upper unsaturated storage above s;
- saturated lower-block storage from s through node 16;
- total profile storage;
- top flux;
- bottom flux;
- ponding.

## Fixed-region storage attribution

NLGLOB14I showed that all fixtures end with nodes 3:16 saturated.

Therefore additionally freeze two fixed regions for first-to-final dry-phase storage attribution:

- upper cap: nodes 1:2;
- lower region: nodes 3:16.

For each fixture record:

`DeltaS_upper = S_upper(final)-S_upper(first)`

`DeltaS_lower = S_lower(final)-S_lower(first)`.

This is descriptive attribution only; it is not used to redefine mass.

## Frozen classifications

### DOWNWARD_REDISTRIBUTION_SUPPORTS_BLOCK_EXPANSION

A fixture qualifies this class only if all hold:

1. profile storage decreases;
2. lower-region storage increases;
3. upper-cap storage decreases;
4. saturated-node count increases;
5. during at least 90% of accepted dry-phase intervals in which saturated-node count increases, q_down_edge > 0;
6. bottom flux remains zero within the existing numerical authority;
7. physical mass remains closed.

### BLOCK_EXPANSION_WITHOUT_DOWNWARD_EDGE_SUPPLY

Classify if the saturated block expands but criterion 5 fails.

### LOWER_REGION_DOES_NOT_GAIN_STORAGE

Classify if block count expands but fixed lower-region storage does not increase.

### INTERNAL_FLUX_STATE_INCONSISTENT

Classify if accepted-state constitutive evaluation is nonfinite or the saturated set is noncontiguous/inconsistent.

Otherwise:

`MIXED_BLOCK_REDISTRIBUTION`.

## Frozen aggregate interpretation

If 8/8 fixtures classify `DOWNWARD_REDISTRIBUTION_SUPPORTS_BLOCK_EXPANSION`:

`NLGLOB14J_DOWNWARD_REDISTRIBUTION_EXPLAINS_BLOCK_EXPANSION`.

If 8/8 classify `BLOCK_EXPANSION_WITHOUT_DOWNWARD_EDGE_SUPPLY`:

`NLGLOB14J_BLOCK_EXPANSION_NOT_EXPLAINED_BY_EDGE_FLUX`.

If any fixture classifies `INTERNAL_FLUX_STATE_INCONSISTENT`:

`NLGLOB14J_INTERNAL_FLUX_STATE_INCONSISTENT`.

Otherwise:

`NLGLOB14J_MIXED_BLOCK_REDISTRIBUTION`.

## Consequence

A positive downward-redistribution result would show that the lower saturated block expansion is mass-consistent redistribution rather than a state inconsistency.

It still would not define a release condition.

The next physical question would then be whether persistent saturated mode is intended to follow this moving lower saturated block or whether mode ownership should transfer once the surface and upper profile are unsaturated.

## Stop rules

Do not:

- change the dry horizon;
- change forcing;
- change saturation indicators;
- infer a release threshold;
- change K staging or solver policy;
- reconstruct external flux from storage.

## Architecture invariants

Affected invariants: 7, 13, 23, 25, 26, 30.

Expected effect: observational only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14J

BASELINE: `6fe778ffb5a55f6fb3cc13b9c1a43b71a4641096`

BRANCH: `research/f-pe-nlglob14j-block-redistribution-r2`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: instrument accepted-state internal block-edge flux and run the frozen 8 fixtures

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
