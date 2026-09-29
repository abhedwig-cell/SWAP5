# F-PE-ELASTIC11A — calibration-only predictor result

Date: 2026-09-29

Status: DEPLOYMENT_CANDIDATE_FROZEN_HOLDOUT_AUTHORIZED

Branch:
`research/f-pe-elastic11-predictor-model`

Preregistration:
`F-PE-ELASTIC11_PREDICTOR_PREREGISTRATION.md`

Workflow run:
`36547712817`

Job:
`109338012766`

Evidence artifact:
`11022978124`

Conclusion:
PASS.

## Calibration authority

The run used only the frozen Phase-D artifact:
- calibration objects: 36;
- calibration-list SHA-256:
  `7b42fee42b2b05e2f788e13317b90d574b1039cf240e57fb3f2c35fe994dd45e`;
- holdout objects: 18;
- holdout-list SHA-256:
  `bfbb1fdefaef57ea3e6a0d2e077fa8efee5b17f101a92da04f0f75603b94e5df`;
- holdout XML present: 0;
- holdout fetches: 0.

Primary target:
77 valid unload branches distributed over 33 BRO objects.

The earlier Phase-D count of 35 objects refers to objects with any valid
mechanical target, including reload-only cases. ELASTIC11 uses unload only.

## Preregistered model results

### M0 object-median baseline

- object-balanced MAE: `0.42072 log10`;
- object-balanced RMSE: `0.50488 log10`;
- median held-out-object MAE: `0.41423 log10`;
- implied multiplicative MAE: `2.63x`.

### M1 field-minimal

Predictors:
- target-bound wet volumetric mass density;
- target-bound water content.

Results:
- object-balanced MAE: `0.25614 log10`;
- object-balanced RMSE: `0.31078 log10`;
- median held-out-object MAE: `0.21947 log10`;
- objects better than M0: `84.85%`;
- maximum held-out-object MAE: `0.62161 log10`;
- implied multiplicative MAE: `1.80x`;
- non-finite predictions: 0.

Improvement versus M0:
- MAE: `0.16457 log10`;
- median object MAE: `0.19476 log10`.

M1 passes all preregistered deployment-candidate gates.

### M2 field-depth

Predictors:
- wet volumetric mass density;
- water content;
- midpoint depth.

Results:
- object-balanced MAE: `0.25083 log10`;
- median held-out-object MAE: `0.25428 log10`;
- objects better than M0: `78.79%`.

M2 also passes the absolute deployment gate.

Its MAE improvement over M1 is only `0.00531 log10`, below the
preregistered `0.02 log10` complexity threshold.

Therefore the frozen simplicity rule selects M1.

### M3 laboratory-context benchmark

Additional predictors:
- log10 absolute laboratory branch stress change;
- determination method.

Result:
- object-balanced MAE: `0.25528 log10`.

Gain versus selected M1:
`0.00087 log10`.

This is far below the preregistered `0.05 log10` threshold.

Classification:
`MECHANICAL_STATE_INFORMATION_MATERIALLY_IMPROVES_PREDICTION = false`
for this particular laboratory-context representation.

This does not prove stress independence. It only shows that these two bounded
lab-context variables do not improve this calibration predictor materially.

## Frozen deployment candidate M1

Response:
`y = log10(Ss_skeleton [cm^-1])`.

Predictors:
- `rho = volumetricMassDensity`;
- `w = waterContent`.

Training normalization:
- mean rho = `1.4337873737373736`;
- sd rho = `0.34422692442216535`;
- mean w = `191.8190909090909`;
- sd w = `182.02868188688447`.

Fixed ridge penalty:
`lambda = 1.0`.

Fitted equation:

`y = -5.144312248981006
     - 0.25581251314464676 * z(rho)
     + 0.15229775506831100 * z(w)`

with:
- `z(rho) = (rho - 1.4337873737373736) / 0.34422692442216535`;
- `z(w) = (w - 191.8190909090909) / 182.02868188688447`.

Calibration target range:
- minimum `4.706062544989206e-7 cm^-1`;
- maximum `7.374023702492847e-5 cm^-1`.

Frozen M0 full-calibration baseline:
- `log10(Ss) = -5.185127014665233`;
- `Ss = 6.529395646606904e-6 cm^-1`.

## Interpretation

The first direct mechanical predictor is unexpectedly simple:
the two source-bound specimen quantities already explain enough between-object
variation to clear the conservative object-grouped calibration gate.

Depth does not add enough predictive value to justify the extra degree of
freedom.

Likewise, the explicit laboratory stress-change/method benchmark does not
materially improve object-grouped prediction.

These are calibration findings, not holdout qualification.

## Holdout authorization

The exact M1 equation, normalization, ridge penalty, target definition,
model-selection rule and scoring framework are now frozen.

Therefore the preregistered 18-object holdout may be opened in a separate
ELASTIC11B phase.

No coefficient, predictor, transform or threshold may be changed in response
to holdout performance.
