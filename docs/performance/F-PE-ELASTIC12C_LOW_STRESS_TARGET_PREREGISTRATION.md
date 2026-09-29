# F-PE-ELASTIC12C — low-stress R3 mechanical target extraction

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_LOW_STRESS_TARGET_CALCULATION

Parents:
- F-PE-ELASTIC10E/R1 target semantics;
- F-PE-ELASTIC11D qualified deep-mechanical holdout;
- F-PE-ELASTIC12A root-zone transfer result;
- F-PE-ELASTIC12B low-stress coverage result.

## Purpose

Derive independent low-stress skeletal specific-storage targets from the exact
five LS25-LOCAL BHR-GT candidates frozen by F-PE-ELASTIC12B.

This workunit does not fit a model and does not evaluate M5.

Its only purpose is to turn source-bound low-stress unload mechanics into
mechanical Ssk targets under a frozen rule.

## Frozen source authority

F-PE-ELASTIC12B workflow:
`36538267535`.

Artifact:
`f-pe-elastic12b-low-stress-coverage`.

Artifact id:
`11018544503`.

Artifact digest:
`sha256:c47ebb65c641a4b01504e709f4b65da27816aba4d99e72f15c5b1f3dcc3e3f7b`.

Frozen candidate authority:
`docs/performance/evidence/F-PE-ELASTIC12C_FROZEN_CANDIDATES.json`.

The raw object bytes used by F-PE-ELASTIC12B are the target-extraction
authority. Do not refetch or replace objects based on current service content.

## Frozen candidates

Exactly five objects, all R3/effective-stress route:

1. BHR000000466495 — determination 1, unload step 2;
2. BHR000000466498 — determination 1, unload step 2;
3. BHR000000469044 — determination 1, unload step 2;
4. BHR000000469048 — determination 1, unload step 2;
5. BHR000000469193 — determination 1, unload step 2.

No touch-only object may be promoted in this workunit.

## Source series semantics

Use only:
`stressChangeDuringSettlement`
bound to:
`StressAtSpecificSettlement.xml`.

Required columns remain the already-qualified BHR-GT schema:

- elapsedTime [s];
- verticalStrain [%];
- excessPoreWaterPressure [kPa];
- verticalEffectiveStress [kPa];
- horizontalEffectiveStress [kPa].

The target uses vertical strain and vertical effective stress only.

## Frozen low-stress subset

Within the exact frozen unload step, select rows satisfying:

- finite verticalStrain;
- finite verticalEffectiveStress;
- `0 < verticalEffectiveStress <= 25 kPa`.

Preserve original series order.

No:
- loading rows;
- relaxation rows;
- rows from another determination;
- interpolation across the 25 kPa boundary;
- non-adjacent branch substitution;
- extension above 25 kPa.

## Primary target estimator

To preserve continuity with F-PE-ELASTIC10E R3 target semantics, use the
first-to-last secant of the selected low-stress unload subset.

Let:

- `sigma0` = first selected vertical effective stress [kPa];
- `sigma1` = last selected vertical effective stress [kPa];
- `eps0` = first selected vertical strain [%];
- `eps1` = last selected vertical strain [%].

Convert:

`delta_sigma_pa = (sigma1 - sigma0) * 1000`

`delta_eps = (eps1 - eps0) / 100`.

Then:

`mv = abs(delta_eps / delta_sigma_pa)`

and:

`Ssk_m_inv = gamma_w * mv`

with:

`gamma_w = 9806.65 N/m3`.

Finally:

`Ssk_cm_inv = Ssk_m_inv / 100`.

This is a low-stress secant target, not an infinitesimal tangent.

## Structural validity gates

Each candidate must retain:

- exact object SHA-256 and byte size from the frozen candidate authority;
- exactly the frozen determination index;
- exactly the frozen unload step index;
- R3 route;
- at least 3 selected rows;
- at least 2 distinct positive effective stresses;
- nonzero finite `delta_sigma_pa`;
- finite nonzero `delta_eps`;
- positive finite `mv`;
- positive finite `Ssk`.

No candidate may be dropped silently.

## Frozen diagnostics

For each target also report, without using these diagnostics for selection:

- selected row count;
- distinct positive stress count;
- minimum/maximum selected stress;
- first/last selected stress;
- first/last selected strain;
- absolute stress span;
- absolute strain span;
- endpoint secant sign before absolute value;
- object/determination/step identity.

Optional descriptive OLS diagnostics may be reported only if clearly labelled
non-primary and may not replace the endpoint secant.

## Success classes

### LOW_STRESS_TARGET_SET_QUALIFIED

All 5 frozen candidates yield structurally valid positive finite targets.

### LOW_STRESS_TARGET_SET_PARTIAL

At least 3 but fewer than 5 candidates yield valid targets.

Record every failed identity/structure reason. A later M5 falsification may not
silently ignore failed frozen candidates.

### LOW_STRESS_TARGET_EXTRACTION_BLOCKED

Fewer than 3 distinct objects yield valid targets.

Do not proceed to predictive-model evaluation.

## Downstream rule

Only after F-PE-ELASTIC12C is recorded may a separate workunit compare the
**already frozen** deep M5 relation with the low-stress targets.

That successor must:

- keep M5 coefficients fixed;
- use source-bound predictor metadata;
- make no fit to the low-stress targets;
- preregister error metrics and falsification thresholds before target
  predictions are evaluated.

## Prohibited

Do not:

- refit M5;
- choose a different slope estimator after seeing Ssk values;
- change the 25 kPa threshold;
- use LS50 data for target construction;
- use loading-only data;
- infer a production ELAS value;
- use SWAP runtime performance as target evidence;
- substitute instantaneous SWAP water content for BHR-GT specimen metadata.

## Claim boundary

This workunit can qualify only a five-object low-stress mechanical target set.

It cannot by itself qualify:
- a root-zone ELAS generator;
- BOFEK/Staringreeks transfer;
- a universal ELAS value;
- a production default.
