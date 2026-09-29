# F-PE-ELASTIC11C — calibration-only mechanical Ssk model selection

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_CALIBRATION_MODEL_RESULTS

Parent authorities:
- F-PE-ELASTIC10E-R1 reconciled 47-target mechanical corpus;
- F-PE-ELASTIC11B target-blind predictor corpus;
- F-PE-ELASTIC06B USGS stress-dependent specific-storage identity.

## Purpose

Select, using calibration objects only, the simplest interpretable mechanical model worth taking to the frozen 8-object holdout.

No holdout target magnitude may be read by model-selection code.

## Population

Calibration objects are the 8 objects frozen in F-PE-ELASTIC11B.
They contribute 22 valid mechanical targets.

The 8 holdout objects and their target magnitudes remain closed until this workunit freezes one model and all holdout metrics.

## Target

Primary target: y = log10(Ssk_cm_inv).

No target clipping, trimming or winsorization.
Every valid target from a calibration object is retained.

## Statistical grouping and weighting

The independent group is the BRO object.

Model assessment uses leave-one-object-out cross-validation over the 8 calibration objects.

Within each training fold, each object receives total weight 1, distributed equally over its target rows: w_row = 1 / n_targets_in_object.

Thus an object with more determinations cannot dominate parameter estimation.

For evaluation, compute an error summary per held-out object first; final CV metrics are the unweighted mean/median across the 8 held-out objects.

## Frozen complete predictors

Only predictors with complete calibration coverage are eligible for the primary candidate set:

- log10(stress_midpoint_kpa);
- log10(stress_span_kpa);
- volumetric mass density in g/cm3;
- water content in percent;
- route R2/R3;
- midpoint depth in m;
- sample quality;
- determination method/procedure.

sampleMoistness is not eligible because the calibration corpus is constant (veldvochtig).

Detailed soil-name and organic-matter fields are excluded from fitted candidates because their calibration coverage is too sparse.

Solids density is excluded from the primary set because it is missing in 5/22 calibration rows. A later complete-case sensitivity may be preregistered separately.

## Frozen candidate models

All fitted coefficients use weighted least squares on training objects only.

### M0 — object-balanced constant baseline

y = b0.

### M1 — route intercept

y = b0 + bR * I(R3).

### M2 — physical stress scaling

Freeze the theoretical stress coefficient to -1:

y = b0 - log10(stress_midpoint_kpa).

Only b0 is fitted.

This represents the first-order USGS/oedometer expectation Ss proportional to 1/sigma, while acknowledging that R2 stress is total test stress and R3 is effective stress.

### M3 — physical stress scaling + route offset

y = b0 + bR * I(R3) - log10(stress_midpoint_kpa).

### M4 — physical stress scaling + volumetric-mass-density correction

y = b0 + bD * density - log10(stress_midpoint_kpa).

### M5 — physical stress scaling + water-content correction

y = b0 + bW * log10(water_content_pct) - log10(stress_midpoint_kpa).

### M6 — bounded combined physical model

y = b0 + bR * I(R3) + bD * density - log10(stress_midpoint_kpa).

No model with more free coefficients than M6 is allowed in this workunit.

Depth and stress span are characterization variables only in this first model selection; they are not added as fitted terms unless all M0-M6 fail predefined adequacy and a new workunit is preregistered.

## Frozen CV metrics

For each held-out calibration object:
- median absolute error in log10 units;
- mean absolute error in log10 units;
- median signed error;
- maximum absolute error.

Across the 8 object folds report:
- median object MAE;
- mean object MAE;
- median object median-absolute-error;
- maximum object MAE;
- fold failures/non-finite predictions.

## Model selection rule

Selection is hierarchical, not winner-takes-all over noise.

1. A fitted model must beat M0 on mean object MAE.
2. A more complex model may replace a simpler admissible model only if:
   - mean object MAE improves by at least 0.05 log10 units;
   - median object MAE does not worsen by more than 0.02 log10 units;
   - no fold is non-finite.
3. Prefer the simpler model when improvements are below these thresholds.
4. M4/M5/M6 must not be selected solely because they fit row-level variation; the object-level CV rule is authority.

These thresholds are frozen before calibration results.

## Holdout gate to be frozen later

This workunit does not inspect holdout targets.

After model selection, a successor preregistration must freeze:
- the selected model/coefficient fitting rule;
- holdout target transformation;
- acceptable object-level errors;
- whether route-specific error limits apply;
- applicability limits in depth/stress/density/water-content space.

Only then may the 8 holdout target objects be opened.

## Scientific boundary

This is a mechanical BHR-GT model, not a BOFEK/Staringreeks ELAS generator.

Even a successful holdout does not validate transfer to root-zone soils.

No MvG or SWAP runtime variable is permitted.
