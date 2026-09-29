# F-PE-ELASTIC11B — frozen holdout qualification preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_HOLDOUT_RETRIEVAL

Parent:
`F-PE-ELASTIC11A_RESULT.md`.

Current canonical reconciliation:
`integration/f-ci-canonical@30e507fc8bdf7f7c37f327ab378e5c4a8ae39b94`.

The canonical delta since the ELASTIC11A reconciliation contains only
F-PE-NLGLOB06 documentation, tests and workflow files. It does not intersect
the ELASTIC11 mechanical-target, descriptor, model or artifact dependency
surface.

## Purpose

Evaluate the already frozen ELASTIC11A M1 predictor on the previously unopened
18-object BHR-GT holdout.

This phase is validation only.

No predictor, coefficient, transformation, ridge penalty, target definition,
baseline or threshold may be changed after holdout retrieval.

## Frozen holdout authority

Exact BRO IDs, in frozen order:

1. BHR000000424612
2. BHR000000462723
3. BHR000000462718
4. BHR000000380954
5. BHR000000458789
6. BHR000000380408
7. BHR000000365007
8. BHR000000377189
9. BHR000000377071
10. BHR000000369337
11. BHR000000361974
12. BHR000000380390
13. BHR000000374009
14. BHR000000360500
15. BHR000000377179
16. BHR000000470651
17. BHR000000381747
18. BHR000000369340

Holdout-list SHA-256:
`bfbb1fdefaef57ea3e6a0d2e077fa8efee5b17f101a92da04f0f75603b94e5df`.

No other BHR-GT object may be fetched.

## Frozen target extraction

Use the already qualified ELASTIC10 extraction semantics unchanged.

Primary validation target:
- valid unload branches only;
- `Ss_skeleton = gamma_w * mv`;
- response `log10(Ss_skeleton [cm^-1])`.

Reload targets may be counted for provenance but are not scored.

No new extraction heuristic is allowed.

## Frozen predictor

M1 from ELASTIC11A:

`y_hat = -5.144312248981006
         - 0.25581251314464676 * z(rho)
         + 0.15229775506831100 * z(w)`

where:

`z(rho) = (rho - 1.4337873737373736) / 0.34422692442216535`

and:

`z(w) = (w - 191.8190909090909) / 182.02868188688447`.

Source fields:
- `rho = volumetricMassDensity`;
- `w = waterContent`.

No refit is allowed.

## Frozen baseline

Full-calibration M0:

`y0 = -5.185127014665233`

equivalent to:

`Ss = 6.529395646606904e-6 cm^-1`.

The baseline is not recalculated from holdout data.

## Descriptor binding

For every valid holdout unload target:
- volumetricMassDensity and waterContent must be bound to the exact owning
  settlement determination or investigated interval using the same source
  hierarchy as ELASTIC10D/D2;
- exactly one finite numeric value is required for each field;
- no imputation is allowed;
- no nearest-depth or cross-analysis borrowing is allowed.

Coverage is reported before score interpretation.

## Minimum holdout yield

For a qualification decision the holdout must contain at least:
- 10 distinct BRO objects with at least one valid unload target;
- 20 valid unload targets total.

If either threshold fails:

`INSUFFICIENT_HOLDOUT_YIELD`.

No model claim is made and no replacement holdout is selected.

## Frozen scoring

BRO object remains the independence unit.

For every holdout object:
- compute target-level absolute log10 errors;
- average them to object MAE.

Report:
1. object-balanced MAE;
2. object-balanced RMSE;
3. median object MAE;
4. maximum object MAE;
5. fraction of holdout objects on which M1 MAE is lower than frozen M0;
6. non-finite prediction count;
7. multiplicative error `10^MAE` for interpretation.

## Qualification gate

M1 qualifies on the independent holdout only if all are true:

- holdout yield meets the minimum gate;
- predictor coverage is 100% for valid unload targets;
- object-balanced M1 MAE improves over M0 by at least `0.05 log10`;
- median object MAE improves over M0 by at least `0.03 log10`;
- at least 60% of scored holdout objects have lower MAE under M1 than M0;
- all predictions are finite.

Classification on success:

`INDEPENDENT_HOLDOUT_QUALIFIED_PHYSICAL_PREDICTOR`.

Classification on adequate-yield failure:

`INDEPENDENT_HOLDOUT_REJECTS_CURRENT_PREDICTOR`.

## One-shot holdout rule

Once these 18 objects are fetched, they become spent validation evidence.

If M1 fails:
- do not tune M1 using their outcomes;
- do not change thresholds using their outcomes;
- do not use them as calibration data for an M1 successor.

A later predictor would require a new development/calibration design and a new
independent validation source.

## Scientific boundary

Even a successful ELASTIC11B establishes only a first bounded predictor for
mechanical skeleton specific storage in the observed BHR-GT domain.

It does not yet establish:
- BOFEK or Staringreeks transfer;
- national representativeness;
- a production default;
- a stress-independent universal soil constant;
- a production parser or automatic activation rule.

A successful holdout would justify the next mapping question, not automatic
production deployment.
