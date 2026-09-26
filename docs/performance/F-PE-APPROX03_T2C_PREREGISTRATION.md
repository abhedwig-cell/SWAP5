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

## Near-zero flux interpretation

Bottom-flux sensitivity must not be judged from a raw relative error alone when the reference flux is close to zero.

For every paired case report all of:

- absolute terminal bottom-flux error [cm/day];
- relative terminal bottom-flux error against the exact reference;
- predictor-scaled terminal flux error using `max(abs(reference bottom flux), abs(predictor qbot))` as the physical scale;
- absolute interval bottom-exchange error, `abs(delta qbot) * dt` [cm].

The raw relative error remains reported for transparency, but it is not by itself a rejection criterion in near-zero-flux cases. The predictor-scaled and absolute exchange measures are the interpretation authority there.

This rule is fixed before T2C matrix results are inspected.


## Reference-domain calibration amendment

The first fixed-window T2C attempt failed in the exact/reference B01-wet-minus arm. This does not classify the 1.25x candidate.

A single requested interval is therefore not used as authority across all material/regime combinations.

Before any further candidate comparison, T2C performs a reference-only calibration with:

- forcing magnitude fixed at `5e-5` of local conductivity;
- both plus and minus orientations;
- candidate budget never evaluated during selection;
- interval grid: `2e-5`, `5e-5`, `1e-4`, `2e-4`, `5e-4`, `1e-3 day`.

For each material/regime/orientation, select the largest interval that under the exact `1e-5 cm` budget:

1. commits;
2. has complete mass accounting;
3. has zero retries;
4. requires at least two accepted substeps.

If no such interval exists, classify that case as `NO_TEMPORAL_WORKLOAD_IN_GRID` and do not use it to claim candidate benefit.

The 1.25x candidate is then evaluated only on the frozen per-case intervals selected by this reference-only rule.

This amendment prevents candidate behavior from influencing workload selection.
