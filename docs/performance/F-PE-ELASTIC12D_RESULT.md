# F-PE-ELASTIC12D — frozen deep-M5 low-stress falsification result

Date: 2026-09-29

Status: LOW_STRESS_M5_TRANSFER_SUPPORTED

Qualified workflow:
`F-PE-ELASTIC12D frozen low-stress M5 falsification`

Run:
`36539932731`

Job:
`109312665899`

Qualified head:
`561b1d2d5aeeface0f59aeb8ccdd5d744479a298`

Artifact:
`f-pe-elastic12d-m5-low-stress`

Artifact id:
`11019439588`

Artifact digest:
`sha256:7ea4a1ba57c0482ca2426802992bc07da3be1a357fc81d1b32282569902303b1`

## Integrity

All preregistered integrity gates passed:

- exact five frozen low-stress target objects;
- predictors extracted from the frozen ELASTIC12B object bytes;
- target authority from the frozen ELASTIC12C artifact;
- source-bound BHR-GT `waterContent` in `%`;
- water predictor ASSIGNED for 5/5;
- target-blind predictor projection;
- no Ssk/strain target magnitude in predictor output;
- frozen M5 coefficients unchanged;
- duplicate predictor extraction byte-identical;
- duplicate evaluation byte-identical.

Markers:

- `F_PE_ELASTIC12D_WATER_ASSIGNED=5/5`;
- `F_PE_ELASTIC12D_NO_TARGET_LEAKAGE=PASS`;
- `F_PE_ELASTIC12D_PREDICTOR_DETERMINISM=PASS`;
- `F_PE_ELASTIC12D_EVALUATION_DETERMINISM=PASS`.

## Frozen model

No refit occurred.

`log10(Ssk_cm_inv_pred) =
 -5.213084677584852
 + 1.0383403589566573 * log10(water_content_pct)
 - log10(stress_midpoint_kpa)`.

Stress exponent:
`-1`.

## Five-object result

| BRO ID | Water content (%) | Stress midpoint (kPa) | Observed Ssk (cm^-1) | Predicted Ssk (cm^-1) | |log10 error| | Factor |
|---|---:|---:|---:|---:|---:|---:|
| BHR000000466495 | 44.3 | 23.755 | 1.5754e-5 | 1.3203e-5 | 0.0767 | 1.19 |
| BHR000000466498 | 93.2 | 23.965 | 3.4153e-5 | 2.8331e-5 | 0.0812 | 1.21 |
| BHR000000469044 | 40.8 | 21.740 | 1.8100e-5 | 1.3246e-5 | 0.1356 | 1.37 |
| BHR000000469048 | 53.3 | 24.375 | 2.8019e-5 | 1.5592e-5 | 0.2546 | 1.80 |
| BHR000000469193 | 201.9 | 22.355 | 8.9847e-5 | 6.7773e-5 | 0.1224 | 1.33 |

All five frozen objects satisfy absolute log10 error <=0.30 and therefore also
the preregistered <=0.50 per-object ceiling.

## Primary metrics

- mean absolute log10 error: `0.1340896073`;
- median absolute log10 error: `0.1224444473`;
- maximum absolute log10 error: `0.2545513831`;
- objects <=0.30: `5/5`;
- objects <=0.50: `5/5`.

Preregistered support gate:

- mean <=0.30: PASS;
- maximum <=0.50: PASS.

Classification:

`LOW_STRESS_M5_TRANSFER_SUPPORTED`.

## Bias diagnostic

Every signed error is negative.

- mean signed log10 error: `-0.1340896073`;
- median signed log10 error: `-0.1224444473`.

Thus M5 systematically underpredicts Ssk in this five-object <=25 kPa
falsification set.

The typical underprediction is modest:
roughly a factor `10^0.134 ~= 1.36`.

Per preregistration this bias is recorded but **not corrected**. No intercept or
stress exponent is retuned.

## Relation to the deep holdout

Deep BHR-GT M5 holdout:

- mean object MAE: `0.1379154881` log10;
- maximum object MAE: `0.2306336583` log10.

Low-stress five-object falsification:

- mean absolute error: `0.1340896073`;
- maximum absolute error: `0.2545513831`.

The low-stress mean error is essentially unchanged relative to the deep
independent holdout. The maximum increases only modestly.

This is strong evidence that the frozen inverse-stress M5 relation retains
predictive value well below its original 61 kPa calibration boundary, at least
for the five source-bound R3 unload objects tested here.

## Interpretation

F-PE-ELASTIC12A correctly refused to extrapolate M5 into the root-zone stress
regime without direct evidence.

F-PE-ELASTIC12B then found direct <=25 kPa unload evidence.

F-PE-ELASTIC12C constructed five independent low-stress mechanical Ssk targets.

F-PE-ELASTIC12D now shows that the already frozen M5 relationship survives that
independent low-stress falsification without refit.

Therefore the previous **mechanical stress-domain blocker is removed** for the
tested approximately 19–25 kPa range.

This does not prove the relation down to zero effective stress. The lowest
tested local unload stress is approximately `18.76 kPa`.

## Implication for Pim Dik's 1e-6 cm^-1 proposal

The five measured low-stress targets are:

`1.58e-5 .. 8.98e-5 cm^-1`

with median:

`2.80e-5 cm^-1`.

Within this BHR-GT specimen-scale low-stress population, `1e-6 cm^-1` is
therefore substantially smaller than the directly derived mechanical Ssk.

However, BHR-GT specimen Ssk is not yet a field-scale/root-zone SWAP ELAS
parameter. Scale, stress convention and transfer from specimen metadata to
root-zone soil layers still require qualification.

Thus this result weakens a claim that `1e-6 cm^-1` is a universal physical
value, but it does not by itself reject that value as a pragmatic or
field-effective parameter for some soils.

## Decision

Qualified classification:

`LOW_STRESS_M5_TRANSFER_SUPPORTED`.

The next physical workunit may now use the frozen M5 mechanical relation in a
root-zone **transfer study**, but must first freeze the field effective-stress
mapping and BHR-P water-content semantics.

No production ELAS value is admitted here.

## Remaining boundary

Not yet qualified:

- effective vertical stress assigned to each root-zone layer;
- field/specimen scale transfer;
- treatment as effective stress approaches zero;
- mineral versus organic/peat regime handling;
- BOFEK/Staringreeks ELAS table;
- production default;
- direct use of instantaneous SWAP state as the BHR-GT specimen predictor.
