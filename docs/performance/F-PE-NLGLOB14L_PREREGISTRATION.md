# F-PE-NLGLOB14L preregistration — mixed-profile upper-region temporal-resolution attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@67e6abbacf53aada2f2613644446eea826602806`

Parent authority:

- TIMEINT17 requalification: `QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE_RESEARCH_POLICY`;
- NLGLOB14J: `NLGLOB14J_DOWNWARD_REDISTRIBUTION_EXPLAINS_BLOCK_EXPANSION`;
- NLGLOB14K: `NLGLOB14K_UPPER_TG_NOT_UNIFORMLY_ADMISSIBLE`.

## Purpose

NLGLOB14K established that the dry mixed profile has a clean constitutive split:

- unsaturated upper region;
- saturated lower block.

The original full-step TG moisture predictor is not uniformly admissible in the upper region, but its admissible fraction improves monotonically as dt is refined.

NLGLOB14L asks one bounded temporal-resolution question:

does a fixed half-step diagnostic predictor make the upper-region moisture predictor admissible in every mixed state of all eight fixtures?

This workunit is observational only.

No state is accepted or committed from the half-step predictor.

## Frozen fixtures and mixed-state population

Reuse exactly the NLGLOB14K fixtures and mixed-state definition:

- O05 / TG;
- HEAD and RUNOFF wet-entry routes;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d;
- 0.012 d horizon;
- dry forcing reversal unchanged;
- surface route = `surface-flux`;
- ponding = 0;
- top node unsaturated;
- contiguous lower saturated block ending at node 16;
- finite accepted state.

No state is added or removed after result exposure.

## Frozen diagnostic predictors

At every frozen mixed state use the same accepted-state physical moisture derivative already defined in NLGLOB14K.

For every upper unsaturated node evaluate:

### Full-step reference

`theta_full = theta + dt*theta_dot`.

### Half-step candidate

`theta_half = theta + 0.5*dt*theta_dot`.

A predictor is admissible only when every upper-region node satisfies:

`theta_r < theta_pred < theta_s`

and all quantities are finite.

No clipping, projection or alternate constitutive rule is allowed.

## Additional failure-side diagnostics

For every inadmissible full-step or half-step predictor record whether the failure is:

- upper saturation-bound overshoot;
- lower dry-bound overshoot;
- nonfinite.

For saturation-side failures define normalized overshoot:

`O_sat = max(theta_pred-theta_s,0)/(theta_s-theta_r)`.

For dry-side failures define:

`O_dry = max(theta_r-theta_pred,0)/(theta_s-theta_r)`.

These are diagnostics only.

## Frozen fixture gates

For each fixture record:

- mixed-state count;
- full-step admissible fraction;
- half-step admissible fraction;
- number of saturation-side failures;
- number of dry-side failures;
- maximum normalized full-step overshoot;
- maximum normalized half-step overshoot.

A fixture has a complete half-step admissibility signal only when:

- half-step admissible fraction = 1.0;
- no nonfinite predictor;
- physical mass and accepted-state validity remain unchanged.

## Frozen aggregate classifications

If all 8 fixtures have complete half-step admissibility:

`NLGLOB14L_HALFSTEP_UPPER_PREDICTOR_FULLY_ADMISSIBLE`.

If every fixture improves or equals the full-step admissible fraction, at least one improves strictly, but at least one remains below 1.0:

`NLGLOB14L_HALFSTEP_IMPROVES_BUT_INCOMPLETE`.

If any fixture has a lower half-step admissible fraction than full-step:

`NLGLOB14L_HALFSTEP_DEGRADES_ADMISSIBILITY`.

If coverage, mass or state validity fails:

`BLOCKED_NLGLOB14L_TEMPORAL_RESOLUTION_ATTRIBUTION`.

Otherwise:

`NLGLOB14L_MIXED_HALFSTEP_SIGNAL`.

## Consequence

A fully admissible half-step result may authorize a separately preregistered hybrid temporal experiment in which only the unsaturated upper-region TG stage is subcycled or evaluated on two half intervals while the saturated lower block remains on the qualified saturated formulation.

NLGLOB14L itself does not implement such a split or subcycle.

An incomplete result requires further attribution before any adaptive or deeper subdivision rule is considered.

## Stop rules

Do not test:

- quarter-step;
- adaptive fractions;
- clipping;
- accepted-state projection;
- altered forcing;
- altered saturation indicators;
- changed mass gates.

## Architecture invariants

Affected invariants: 7, 9, 13, 20, 23, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14L

BASELINE: `67e6abbacf53aada2f2613644446eea826602806`

BRANCH: `research/f-pe-nlglob14l-upper-halfstep-attribution`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: evaluate full-step and fixed half-step upper-region predictors on the frozen mixed-state population

## Production boundary

Research diagnostics only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
