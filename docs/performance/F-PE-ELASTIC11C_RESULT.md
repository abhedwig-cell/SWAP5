# F-PE-ELASTIC11C — calibration-only mechanical Ssk model-selection result

Date: 2026-09-29

Status: CALIBRATION_MODEL_SELECTED_HOLDOUT_CLOSED

Workflow:
`F-PE-ELASTIC11C calibration model selection`

Run:
`36533818344`

Job:
`109293227398`

Qualified head:
`50a4965e1a429695f948a1530107186596b58a35`

Artifact:
`f-pe-elastic11c-calibration-model`

Artifact id:
`11017528429`

Artifact digest:
`sha256:e22f29acaad1d8fbdbc4cf4b663d7a027d96c753c4a9a986c9fdd8524b8ed72e`

## Population

Only the 8 preregistered calibration objects were used.

- calibration rows: 22;
- calibration objects: 8;
- holdout target values accessed by model-selection code: 0.

The run explicitly emits:
`F_PE_ELASTIC11C_HOLDOUT_TARGETS_ACCESSED=0`.

## Target

`y = log10(Ssk_cm_inv)`.

Calibration target range:
- minimum: -7.26664;
- median: -4.98846;
- maximum: -4.23899.

No clipping/trimming was applied.

## Object-grouped leave-one-object-out results

Mean object MAE in log10 units:

- M0 constant baseline: 0.7389;
- M1 route intercept: 0.7372;
- M2 fixed 1/stress scaling: 0.5905;
- M3 fixed 1/stress + route: 0.5542;
- M4 fixed 1/stress + volumetric mass density: 0.3682;
- M5 fixed 1/stress + water content: 0.3283;
- M6 fixed 1/stress + route + density: 0.3968.

Median object MAE:

- M0: 0.7160;
- M1: 0.6387;
- M2: 0.5328;
- M3: 0.4847;
- M4: 0.2446;
- M5: 0.2490;
- M6: 0.2043.

Maximum object MAE:

- M0: 1.4179;
- M1: 1.2903;
- M2: 1.3004;
- M3: 1.0984;
- M4: 1.1913;
- M5: 1.0900;
- M6: 1.1290.

No fold failed.

## Selected model

The preregistered hierarchical complexity rule selects M5.

Model:

`log10(Ssk_cm_inv) = b0 + bW * log10(water_content_pct) - log10(stress_midpoint_kpa)`.

Full calibration coefficients:

- `b0 = -5.213084677584852`;
- `bW = 1.0383403589566573`.

Equivalent multiplicative form:

`Ssk_cm_inv = 10^b0 * water_content_pct^bW / stress_midpoint_kpa`.

The stress exponent remains physically frozen at -1.

M6 is not selected despite a slightly lower median object MAE because its mean
object MAE is worse than M5 and it does not satisfy the preregistered
replacement rule.

## Interpretation

The calibration evidence supports three descriptive points:

1. explicit stress dependence is useful relative to a constant baseline;
2. water content materially improves calibration-object generalization beyond
   the fixed stress scaling;
3. adding route+density complexity does not improve object-level mean
   generalization enough to justify the larger model.

This does not establish water content as a unique causal material parameter.
In this small BHR-GT corpus it may partly proxy composition, density, saturation
state or other unobserved mechanical structure.

## Calibration predictor domain

For M5 predictors:

`log10(stress_midpoint_kpa)`:
- min 1.78718;
- max 2.66514.

`log10(water_content_pct)`:
- min 1.36549;
- max 2.65658.

These bounds are frozen as the calibration interpolation domain before holdout
targets are opened.

## Holdout predictor-only audit

Without accessing target magnitudes:

- 25 holdout rows exist across 8 objects;
- all holdout stress-midpoint values fall inside the calibration stress range;
- 21/25 holdout rows are fully within the M5 calibration predictor domain;
- 2 rows in BHR000000353614 exceed the calibration water-content maximum;
- 2 rows in BHR000000462646 fall below the calibration water-content minimum.

These extrapolation flags are frozen before target opening.

## Decision

Classification:

`M5_MECHANICAL_RELATION_SELECTED_FOR_FROZEN_HOLDOUT`.

No holdout target has yet been used.

This is still a deep BHR-GT mechanical relationship, not a root-zone/BOFEK ELAS
parameterization.
