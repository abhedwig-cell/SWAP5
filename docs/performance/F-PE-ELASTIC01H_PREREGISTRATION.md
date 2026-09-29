# F-PE-ELASTIC01H — descriptor holdout falsification

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_HOLDOUT_RESULTS

Parents:
- F-PE-ELASTIC01R
- F-PE-ELASTIC01D

## Frozen holdout set

Open exactly the four pre-existing BOFEK holdout cases:

- B12/POND
- O14/MOIST
- O14/WET
- O14/POND

No additional cases or coefficient tuning are allowed before these outcomes are recorded.

## Frozen coefficient

Test only `ELAS = 1e-6` against the current ELAS-off Reference.

No coefficient refinement may be performed on holdout data in this workunit.

## Prospectively frozen predictions

### B12/POND

B12 has very low near-saturation contrast:
`ELAS / C_native(-0.001 cm) ~= 0.0031`.

Prediction:
- converges;
- no O05-like dtmin failure;
- physical response is smooth and small relative to O05;
- no substantial deterministic-work benefit is expected.

### O14/MOIST and O14/WET

O14 has intermediate near-saturation contrast:
`ELAS / C_native(-0.001 cm) ~= 1.21`.

Prediction:
- both converge;
- response is larger than B12 if positive heads activate ELAS;
- no extreme O05-like solver-path discontinuity is expected.

If the state remains entirely below h=0, negligible ELAS response is expected.

### O14/POND

Prediction:
- converges at `1e-6`;
- shows material physical storage/runoff redistribution;
- does not reproduce O05's nonconvergence at `1e-6`;
- numerical work may change, but no direction is preregistered.

## Falsification criteria

The descriptor hypothesis is weakened materially if:

1. B12/POND fails at dtmin under `1e-6`;
2. O14/POND fails at dtmin under `1e-6` despite its much smaller near-saturation contrast than O05;
3. O14 shows O05-like abrupt failure without a comparably large ELAS/native-capacity contrast;
4. B12 shows an unexpectedly large solver-path transition.

Physical trajectory differences alone do not falsify ELAS because ELAS is real storage physics.

## Claim boundary

This is a four-case falsification of a mechanistic descriptor hypothesis, not validation of a production soil rule.
