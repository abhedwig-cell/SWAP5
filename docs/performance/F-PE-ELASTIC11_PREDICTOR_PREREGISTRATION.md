# F-PE-ELASTIC11 — calibration-only physical ELAS predictor preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_MODEL_EVALUATION

Baseline:
`research/f-pe-elastic10-bhrgt-targets@54d0990915ad5e4243ec1edf96b832115254ab6b`

Canonical reconciliation authority:
`integration/f-ci-canonical@2332a59d2ec33245f53593960e0c334525eda148`

Parent evidence:
- `F-PE-ELASTIC10_CLOSEOUT.md`;
- `F-PE-ELASTIC10D_CORPUS_RESULT.md`;
- `F-PE-ELASTIC10D2_DESCRIPTOR_RESULT.md`.

## Purpose

Test whether the frozen BHR-GT calibration evidence supports a bounded physical
predictor for SWAP ELAS.

This phase is calibration-only.

The 18 frozen holdout objects remain unopened until:
1. the candidate model family;
2. preprocessing;
3. model-selection rule;
4. scoring rule;
5. qualification thresholds;
6. final fitted calibration coefficients

have all been frozen in Git.

No solver runtime or numerical-performance quantity may enter target
construction, feature construction, model selection or scoring.

## Mechanical target

Primary target family:

`log10(Ss_skeleton [cm^-1])`

for valid **unload** branches only.

Authority:
the 77 valid unload targets frozen in F-PE-ELASTIC10D.

Reload targets are not pooled with unload targets and do not participate in
model selection.

## Unit of independence

BRO object is the statistical grouping unit.

Multiple unload branches from one object are correlated observations and may
not be treated as independent validation samples.

All model evaluation therefore uses leave-one-BRO-object-out cross-validation
(LOO-object-CV).

Training loss is target-level squared error with each target weighted by
`1 / number_of_unload_targets_in_its_BRO_object`, so every training object has
equal total weight.

Scoring is object-balanced:
- first compute MAE in log10-space within each held-out object;
- then average those object MAEs.

## Frozen predictors

Only source-bound or already-frozen target metadata are allowed.

### Deployment-eligible predictors

These are intended to be potentially reconstructable later for a SWAP layer:

- wet `volumetricMassDensity`;
- `waterContent`;
- target midpoint depth.

No derived dry density, porosity, void ratio, MvG parameter, BOFEK class or
borehole-log depth linkage is allowed in ELASTIC11.

### Explanatory-only predictors

One laboratory-context benchmark may additionally use:

- `log10(abs(delta_sigma_kPa))`;
- determination method indicator:
  `samendrukkenBelastinggestuurd` versus
  `samendrukkenSnelheidgestuurd`.

This model is explicitly not deployment-eligible because branch stress change
and laboratory method are not presently a SWAP soil-parameter input contract.

## Frozen candidate models

All regression models use:
- response `y = log10(Ss_skeleton_cm_inv)`;
- continuous predictors standardized using the training fold mean and population
  standard deviation;
- zero-variance predictors dropped within that fold;
- weighted ridge regression;
- unpenalized intercept;
- fixed ridge penalty `lambda = 1.0`.

No hyperparameter search is allowed.

Candidates:

### M0 baseline

Training-object median.

For every training BRO object:
- calculate that object's median `y`;
- M0 is the median of those object medians.

### M1 field-minimal

Predictors:
- volumetricMassDensity;
- waterContent.

### M2 field-depth

Predictors:
- volumetricMassDensity;
- waterContent;
- midpoint depth.

### M3 lab-context benchmark

Predictors:
- volumetricMassDensity;
- waterContent;
- midpoint depth;
- log10 absolute branch stress change in kPa;
- determination-method indicator.

M3 is diagnostic only and can never become the production/deployment
candidate in this work unit.

## Missing-data rule

M1 and M2 require complete target-bound density and water content.

The Phase-D/D2 authority states these are present on all 77 unload targets.

No imputation is allowed.

If the rerun contradicts that coverage, ELASTIC11 stops as
`CALIBRATION_AUTHORITY_DRIFT`.

## Cross-validation metrics

For each candidate report:

1. object-balanced MAE in log10 units;
2. object-balanced RMSE in log10 units;
3. median held-out-object MAE;
4. fraction of held-out objects whose MAE is lower than M0;
5. maximum held-out-object MAE;
6. count of non-finite predictions.

The original-scale multiplicative error corresponding to MAE is reported as
`10^MAE` for interpretation only.

## Deployment-candidate gate

A field model qualifies only if, versus M0:

- object-balanced MAE improves by at least `0.05 log10`;
- median held-out-object MAE improves by at least `0.03 log10`;
- at least 60% of held-out objects have lower MAE than M0;
- all predictions are finite.

If neither M1 nor M2 passes, classification is:

`NO_ROBUST_FIELD_PREDICTOR_ON_CURRENT_CALIBRATION`

and no holdout object may be opened.

If both pass:
- choose M1 unless M2 improves object-balanced MAE over M1 by at least
  `0.02 log10`;
- otherwise choose M2.

This simplicity rule is frozen before evaluation.

## Lab-context interpretation gate

M3 is compared with the selected field model, or with the better of M1/M2 if
neither qualifies.

If M3 improves object-balanced MAE by at least `0.05 log10`, record
`MECHANICAL_STATE_INFORMATION_MATERIALLY_IMPROVES_PREDICTION`.

That result does not authorize M3 for SWAP parameter generation.

## Full-calibration freeze

If a deployment model qualifies:

1. refit that exact model on all 77 unload calibration targets;
2. persist:
   - predictor order;
   - training means and standard deviations;
   - coefficient vector;
   - intercept;
   - lambda;
   - target range;
   - calibration object IDs;
   - calibration-list SHA;
3. freeze those values before any holdout retrieval.

Only a later separately recorded ELASTIC11B holdout phase may fetch the 18
holdout objects.

## Holdout rule

The Phase-D holdout list and SHA remain authority.

During ELASTIC11A:
- no holdout BRO ID may be fetched;
- no holdout XML may be present in the analysis artifact;
- no adaptive object reselection is allowed.

If a deployment candidate is frozen, ELASTIC11B may open the holdout exactly
once under the already-frozen model and score.

The holdout may not be used to:
- change predictors;
- change lambda;
- change transforms;
- change coefficients;
- change acceptance thresholds.

## Scientific boundary

ELASTIC11 does not:
- infer ELAS from MvG;
- optimize ELAS for runtime;
- define a universal default;
- alter production SWAP5 code;
- combine unload and reload;
- claim national representativeness;
- create a BOFEK/Staringreeks mapping.

Its narrow question is whether the current direct Dutch mechanical calibration
corpus contains enough information for a reproducible first physical predictor.
