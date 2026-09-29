# F-PE-ELASTIC11D — frozen BHR-GT mechanical-model holdout result

Date: 2026-09-29

Status: HOLDOUT_PASSED_DEEP_BHR_GT_MECHANICAL_RELATION_QUALIFIED

Workflow:
`F-PE-ELASTIC11D frozen mechanical-model holdout`

Run:
`36534683481`

Job:
`109295919193`

Qualified head:
`ef3a902e273fdc90c7c2a8c4ffddca31b2ccbdb4`

Artifact:
`f-pe-elastic11d-holdout`

Artifact id:
`11017218724`

Artifact digest:
`sha256:4644b66b2b26b06ce8f4f9779d5012b6c553718e957ed34233e37fe91d672c51`

## Frozen model

No coefficient was refitted after target opening.

M5 remained exactly:

`log10(Ssk_cm_inv) = -5.213084677584852
                      + 1.0383403589566573 * log10(water_content_pct)
                      - log10(stress_midpoint_kpa)`.

Frozen M0 baseline:

`log10(Ssk_cm_inv) = -5.300865461580213`.

## Holdout population

Exactly the preregistered 8 BRO objects and all 25 valid ELASTIC10E-R1 target
rows were opened.

No row was dropped.

- objects: 8/8;
- rows: 25/25;
- in calibration predictor domain: 21;
- frozen extrapolation rows: 4.

Deterministic duplicate evaluation was byte-identical:

`F_PE_ELASTIC11D_DETERMINISM=PASS`.

## Primary object-grouped result

M5:

- mean object MAE: `0.1379154881` log10;
- median object MAE: `0.1638016666` log10;
- maximum object MAE: `0.2306336583` log10;
- objects with MAE <= 0.50: `8/8`;
- mean object median signed error: `-0.1411687114` log10.

Frozen M0 baseline:

- mean object MAE: `0.4755825332` log10;
- median object MAE: `0.4371323382` log10;
- maximum object MAE: `0.9336994276` log10;
- objects with MAE <= 0.50: `5/8`.

Improvement in mean object MAE:

`0.3376670451` log10.

All preregistered primary gates pass.

Marker:

`F_PE_ELASTIC11D=PASS`.

## Object-level M5 MAE

- BHR000000353614: `0.16821`;
- BHR000000356940: `0.02910`;
- BHR000000380281: `0.02373`;
- BHR000000453775: `0.13654`;
- BHR000000456023: `0.23063`;
- BHR000000462646: `0.17054`;
- BHR000000466469: `0.15940`;
- BHR000000470064: `0.18518`.

No holdout object approaches the preregistered `1.20` maximum-MAE ceiling.

## Route diagnostics

### R2 unload/reload targets

17 rows:

- MAE: `0.20454` log10;
- median absolute error: `0.21543`;
- maximum absolute error: `0.48018`;
- median multiplicative error factor: `1.64`;
- maximum factor: `3.02`;
- mean signed error: `-0.20399`.

### R3 effective-stress targets

8 rows:

- MAE: `0.09064` log10;
- median absolute error: `0.05224`;
- maximum absolute error: `0.24209`;
- median multiplicative error factor: `1.13`;
- maximum factor: `1.75`;
- mean signed error: `-0.08128`.

R3 is descriptively much tighter than R2 in this holdout.

This is diagnostic only; route-specific refitting was not allowed.

## Predictor-domain diagnostics

The four preregistered extrapolation rows did not cause deterioration.

In-domain rows, n=21:

- MAE: `0.18070`;
- maximum absolute error: `0.48018`;
- median multiplicative factor: `1.50`.

Extrapolation rows, n=4:

- MAE: `0.10187`;
- maximum absolute error: `0.17102`;
- median multiplicative factor: `1.31`.

The two high-water extrapolation rows from BHR000000353614 have water contents
`474.6%` and `534.2%` and remain accurately predicted.

The two low-water extrapolation rows from BHR000000462646 have water contents
`18.7%` and `15.9%` and also remain within the overall holdout envelope.

These observations do not widen the formally qualified predictor domain.

## Interpretation

The holdout strongly supports three statements within the frozen deep BHR-GT
mechanical population:

1. explicit inverse stress scaling is physically and predictively useful;
2. source-bound specimen water content adds substantial predictive information;
3. the two-parameter M5 relation generalizes across completely held-out BRO
   objects much better than a constant Ssk baseline.

The result is especially notable because:
- object grouping prevents pseudo-replication across multiple steps from one
  borehole object;
- holdout target magnitudes were not used for model selection;
- all primary thresholds were fixed before target opening;
- no post-holdout retuning occurred.

## Scientific boundary

This result does **not** yet qualify:

- a root-zone ELAS parameterization;
- BOFEK/Staringreeks transfer;
- a production ELAS default;
- use of instantaneous SWAP water content as if it were the BHR-GT laboratory
  specimen water-content predictor;
- stress-independent ELAS;
- a causal water-content law;
- peat/root-zone extrapolation outside the BHR-GT mechanical population.

The BHR-GT predictor `water_content_pct` is source-bound specimen metadata from
geotechnical testing. Its physical meaning must be reconciled before any SWAP
state variable is substituted.

## Decision

Classification:

`DEEP_BHR_GT_M5_HOLDOUT_GENERALIZATION_QUALIFIED`.

The physical parameter line may now proceed to a separate transfer/falsification
workunit.

The next workunit must not fit against SWAP runtime performance. It should test
whether the qualified mechanical relation can be mapped to shallow/root-zone
soil descriptors and a declared effective-stress convention without silently
changing predictor semantics.
