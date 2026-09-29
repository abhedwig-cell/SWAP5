# F-PE-NLGLOB14K preregistration — mixed-profile temporal-mode ownership attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@e803842a434d792ba5209f71e3681bd78be90560`

Parent authority:

- TIMEINT17 requalification: `QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE_RESEARCH_POLICY`;
- NLGLOB14J: `NLGLOB14J_DOWNWARD_REDISTRIBUTION_EXPLAINS_BLOCK_EXPANSION`.

## Purpose

The dry forcing-reversal fixtures develop a physically consistent mixed profile:

- surface route returns to surface-flux;
- ponding is zero;
- upper nodes are unsaturated and losing water;
- a contiguous lower saturated block remains and is supplied by downward redistribution.

Persistent saturated KLAG currently owns the whole column after saturation entry.

NLGLOB14K asks whether the accepted mixed state itself supports a spatially split numerical interpretation:

- TG-admissible unsaturated upper region;
- saturated lower region that remains outside the ordinary unsaturated TG chain-rule domain.

This workunit is observational only.

No hybrid solver, release switch or production policy is implemented.

## Frozen fixtures

Reuse exactly the 8 NLGLOB14G-J forcing-reversal fixtures:

- O05 / TG;
- HEAD and RUNOFF wet-entry routes;
- four dt levels;
- 0.012 d horizon;
- unchanged forcing reversal;
- unchanged qualified temporal policy;
- unchanged mass authority.

## Mixed-state population

An accepted dry-phase state belongs to the frozen mixed-state population only when all hold:

1. provider route is `surface-flux`;
2. ponding depth is exactly zero;
3. top node is unsaturated by both existing indicators;
4. at least one lower node is saturated by both indicators;
5. the saturated nodes form one contiguous lower block ending at node 16;
6. state and diagnostics are finite.

No state is added or removed after result exposure.

## Constitutive mode diagnostics

At every mixed state evaluate the same O05 constitutive relation on the accepted pressure heads.

For each unsaturated node above the lower saturated block record:

- water content consistency;
- capacity `C=dtheta/dh`;
- conductivity;
- finite/positive capacity status.

For each saturated node in the lower block record:

- `theta == theta_s`;
- pressure head >= 0;
- constitutive capacity.

The current B1.10 provider intentionally returns the existing numerical capacity floor

`C_floor = dt * 1e-7`

on the saturated branch. NLGLOB14K does not reinterpret that floor as physical storage.

Define a clean constitutive split when:

- every upper unsaturated node has finite `C>0`;
- every lower saturated node has `h>=0`, `theta==theta_s`, and provider capacity equal to the existing `C_floor` within floating-point identity;
- all accepted theta/head pairs are constitutively consistent.

## Upper-region current-step TG admissibility

Using the accepted state and the same hydraulic flux convention as the frozen TIMEINT16/17 harness:

1. evaluate node conductivities;
2. calculate top and internal interface fluxes;
3. calculate the physical moisture derivative for each unsaturated node above the saturated block;
4. form the original current-step endpoint moisture predictor
   `theta_tilde = theta + dt*theta_dot`
   for those upper nodes only.

An upper-region predictor is admissible iff every upper node satisfies:

`theta_r < theta_tilde < theta_s`

and all quantities are finite.

This is diagnostic only. The predicted state is not accepted and no solve is executed.

## Frozen trajectory gates

For each of the 8 fixtures record:

- number of mixed states;
- first and last mixed-state step;
- minimum upper-region capacity;
- maximum absolute lower-block capacity;
- fraction of mixed states with clean constitutive split;
- fraction of mixed states with upper-region TG predictor admissible.

A fixture supports spatially split mode ownership only if:

1. it contains at least one mixed state;
2. clean constitutive split fraction = 1.0;
3. upper-region TG predictor admissible fraction = 1.0;
4. physical mass remains closed;
5. no route/state inconsistency occurs.

## Frozen aggregate classifications

If all 8 fixtures support spatially split mode ownership:

`NLGLOB14K_SPATIALLY_SPLIT_MODE_OWNERSHIP_SIGNAL`.

If all 8 have a clean constitutive split but at least one fixture has upper-region TG predictor admissibility <1.0:

`NLGLOB14K_UPPER_TG_NOT_UNIFORMLY_ADMISSIBLE`.

If any fixture lacks a clean constitutive split:

`NLGLOB14K_NO_CLEAN_CONSTITUTIVE_MODE_SPLIT`.

If coverage, mass or state validity fails:

`BLOCKED_NLGLOB14K_MODE_OWNERSHIP_ATTRIBUTION`.

Otherwise:

`NLGLOB14K_MIXED_MODE_OWNERSHIP_SIGNAL`.

## Consequence

A positive spatially split signal may justify a separately preregistered hybrid temporal experiment in which the upper unsaturated region is advanced with TG while the lower saturated block remains on a saturated/head formulation, coupled through their common interface with one mass-conserving interval contract.

NLGLOB14K itself does not implement such a method.

A negative result closes that hybrid interpretation and keeps release/mode ownership as a whole-column problem.

## Stop rules

Do not:

- switch modes;
- introduce a capacity floor;
- clip predicted moisture;
- change forcing or horizon;
- change mass gates;
- change saturation indicators;
- tune the mixed-state population after results.

## Architecture invariants

Affected invariants: 7, 9, 13, 20, 23, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14K

BASELINE: `e803842a434d792ba5209f71e3681bd78be90560`

BRANCH: `research/f-pe-nlglob14k-mixed-profile-mode-ownership`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: instrument mixed-state constitutive split and upper-region TG predictor admissibility

## Production boundary

Research diagnostics only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
