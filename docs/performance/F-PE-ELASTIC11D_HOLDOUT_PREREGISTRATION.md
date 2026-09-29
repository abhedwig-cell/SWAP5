# F-PE-ELASTIC11D — frozen BHR-GT mechanical-model holdout

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_HOLDOUT_TARGET_OPENING

Parents:
- F-PE-ELASTIC11B predictor corpus;
- F-PE-ELASTIC11C selected calibration model.

## Frozen model

Use M5 exactly:

`log10(Ssk_cm_inv) = -5.213084677584852
                      + 1.0383403589566573 * log10(water_content_pct)
                      - log10(stress_midpoint_kpa)`.

No refitting on holdout data.

Frozen comparison baseline M0:

`log10(Ssk_cm_inv) = -5.300865461580213`.

## Frozen holdout population

Exactly 8 object groups:

- BHR000000462646
- BHR000000456023
- BHR000000356940
- BHR000000453775
- BHR000000380281
- BHR000000466469
- BHR000000353614
- BHR000000470064

All valid ELASTIC10E-R1 targets from these objects are opened once.

No row may be dropped after target opening except a pre-existing explicit
ELASTIC10E-R1 rejection.

## Error metric

For every target row:

`error = predicted_log10_Ssk - observed_log10_Ssk`.

First aggregate within each BRO object:

- MAE;
- median absolute error;
- median signed error;
- maximum absolute error.

Then aggregate equally across the 8 objects.

## Frozen primary acceptance gates

M5 holdout passes only if all are true:

1. no non-finite prediction;
2. all 8 objects have at least one valid target;
3. mean object MAE <= 0.50 log10 units;
4. median object MAE <= 0.40 log10 units;
5. maximum object MAE <= 1.20 log10 units;
6. at least 6 of 8 objects have MAE <= 0.50 log10 units;
7. M5 improves mean object MAE over the frozen M0 baseline by at least
   0.05 log10 units.

These gates are frozen before target opening.

## Predictor-domain reporting

Calibration interpolation domain:

- log10 stress midpoint: [1.7871769924705538, 2.6651446013599136];
- log10 water content: [1.3654879848908996, 2.656577291396114].

Predictor-only audit already established:

- 21/25 holdout rows are in-domain;
- BHR000000353614 has 2 high-water extrapolation rows;
- BHR000000462646 has 2 low-water extrapolation rows;
- all holdout stress values are within calibration stress range.

The primary gates use all holdout rows regardless of domain.

In-domain errors and extrapolation-row errors are reported separately for
diagnosis only and cannot be used to rescue a failed primary gate.

## Secondary descriptive checks

Report, without changing pass/fail:

- R2 and R3 errors separately;
- in-domain-only object metrics;
- extrapolation-row metrics;
- multiplicative error factors corresponding to log10 error;
- signed bias.

## Scientific claim boundary

A pass would support generalization of M5 only within this frozen deep BHR-GT
mechanical population.

A pass would not validate:
- root-zone soils;
- BOFEK/Staringreeks transfer;
- a production ELAS default;
- a stress-independent coefficient;
- a causal water-content law.

A fail is retained as a negative result; no coefficient or threshold is retuned
in this workunit.
