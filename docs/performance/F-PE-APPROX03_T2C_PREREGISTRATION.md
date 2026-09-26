# F-PE-APPROX03 T2C preregistration — 1.25x cross-material qualification

Date: 2026-09-26

Status: `PREREGISTERED_EXPERIMENT_ONLY`

Parent:
`F-PE-APPROX03`

Predecessor:
`T2B — intermediate temporal budget screen`

## Candidate

T2C fixes the model temporal-indicator budget at:

`1.25e-5 cm`

Reference:

`1.00e-5 cm`

No other numerical control changes.

## Why T2C exists

The controlling B01-wet screen showed:

- 1.25x commits 9/9;
- 1.50x, 1.75x and 2.00x fail 9/9;
- 1.25x reduces accepted substeps from 3 to 2;
- median runtime gain approximately 16.1%;
- state errors remain tiny;
- terminal bottom-flux deviation is already approximately 10.45%;
- storage-change deviation approximately 1.35%.

The purpose of T2C is therefore not to prove that 1.25x is acceptable, but to determine whether the observed exchange sensitivity generalizes across soil/regime space.

## Matrix

Use 24 paired cases:

- B01, B12, O05, O14;
- wet: h0 = -10 cm;
- mid: h0 = -75 cm;
- dry: h0 = -500 cm;
- plus and minus forcing orientation.

Forcing is scaled to local conductivity:

- plus: top factor = +5e-5, predictor-qbot factor = +5e-5;
- minus: top factor = -5e-5, predictor-qbot factor = -5e-5.

Requested interval:

`1e-4 day`

The prescribed bottom-face head is materialized from predictor qbot through the same B1.10 Darcy mapping used by the production coupling route.

## Metrics

Per paired case:

- replicated runtime;
- accepted substeps;
- retries;
- nonlinear iterations;
- HeadCalc calls;
- pressure-head error;
- water-content error;
- terminal bottom-flux error;
- storage-end and storage-change error;
- canonical mass residual;
- signed bottom-flux error.

## Decision rule

T2C is rejected if:

- any reference-stable case fails only in the candidate arm;
- candidate retries increase materially;
- bottom-flux error materially exceeds the controlling-case ~10.45% level;
- signed flux error shows a systematic directional bias;
- or runtime/work benefit is too sparse to justify the physical deviation.

T2C may proceed to application-shaped and coupled qualification only if the broad matrix demonstrates a coherent practical envelope.

No production opt-in is admitted by this preregistration.
