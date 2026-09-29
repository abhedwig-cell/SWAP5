# F-PE-ELASTIC11B — independent holdout qualification result

Date: 2026-09-29

Status: INDEPENDENT_HOLDOUT_QUALIFIED_PHYSICAL_PREDICTOR

Preregistration:
`F-PE-ELASTIC11B_HOLDOUT_PREREGISTRATION.md`.

Workflow run:
`36548107018`

Job:
`109339294115`

Evidence artifact:
`11023436709`

Conclusion:
PASS.

## Frozen holdout execution

Exactly the 18 preregistered BHR-GT holdout objects were fetched.

No replacement or adaptive reselection occurred.

Observed mechanical yield:
- fetched holdout objects: 18;
- objects with at least one valid unload target: 13;
- valid unload targets: 45;
- valid reload targets: 53.

The preregistered minimum yield was:
- at least 10 unload-bearing objects;
- at least 20 valid unload targets.

Yield gate:
PASS.

## Predictor coverage

For all 45 valid unload targets:
- target-bound `volumetricMassDensity` was available;
- target-bound `waterContent` was available;
- both bound uniquely and numerically;
- no imputation or cross-depth borrowing was used.

Coverage:
`45 / 45 = 100%`.

## Frozen baseline M0

The holdout was scored against the frozen full-calibration M0:

`log10(Ss) = -5.185127014665233`.

Holdout results:
- object-balanced MAE: `0.40893 log10`;
- object-balanced RMSE: `0.48021 log10`;
- median object MAE: `0.40678 log10`;
- maximum object MAE: `0.96447 log10`;
- implied multiplicative MAE: `2.56x`.

## Frozen predictor M1

No coefficient or normalization was changed after calibration freeze.

Holdout results:
- object-balanced MAE: `0.32715 log10`;
- object-balanced RMSE: `0.38914 log10`;
- median object MAE: `0.30078 log10`;
- maximum object MAE: `0.81924 log10`;
- objects better than M0: `69.23%`;
- non-finite predictions: 0;
- implied multiplicative MAE: `2.12x`.

## Preregistered gate evaluation

Observed improvement over M0:

- object-balanced MAE gain:
  `0.08178 log10`;
- required:
  at least `0.05 log10`;

PASS.

Median object MAE gain:

`0.10600 log10`;

required:
at least `0.03 log10`;

PASS.

Objects better than M0:

`69.23%`;

required:
at least 60%;

PASS.

Predictor coverage:
100%;

PASS.

Finite predictions:
100%;

PASS.

Final classification:

`INDEPENDENT_HOLDOUT_QUALIFIED_PHYSICAL_PREDICTOR`.

## What the result means

The independent holdout supports the calibration-side conclusion that a simple
two-variable mechanical predictor contains reproducible information about
unload skeleton specific storage.

The predictor is:

`log10(Ss_skeleton [cm^-1]) =
 -5.144312248981006
 -0.25581251314464676 * z(volumetricMassDensity)
 +0.15229775506831100 * z(waterContent)`.

This is evidence against using one universal ELAS value for all soils.

It is also evidence that direct mechanical specimen properties can constrain
ELAS without using MvG hydraulic parameters or solver performance as fitting
targets.

## Accuracy boundary

The holdout qualification should not be overstated.

An object-balanced MAE of `0.327 log10` corresponds to a typical
multiplicative error of about `2.12x`.

The worst holdout-object MAE is `0.819 log10`, so substantial
object-specific error remains.

Therefore M1 is a useful first physical prior/predictor, not a high-precision
deterministic material law.

## Holdout is now spent

The 18 holdout objects are now validation evidence.

They must not be reused to:
- refit M1;
- tune the coefficients;
- choose new M1 predictors;
- alter lambda;
- alter acceptance thresholds.

Any successor model-development campaign needs independent validation evidence
that is not selected using these holdout outcomes.

## Scientific boundary

This holdout result does not yet establish:
- BOFEK transfer;
- Staringreeks transfer;
- national representativeness;
- a production default;
- a stress-independent universal ELAS law;
- automatic SWAP activation;
- a parser/input-file contract.

Those are separate transfer and production-admission questions.
