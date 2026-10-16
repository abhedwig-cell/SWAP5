# F-PE-APPROX03 T2B preregistration — intermediate temporal budget screen

Date: 2026-09-26

Status: `PREREGISTERED_EXPERIMENT_ONLY`

Parent:
`F-PE-APPROX03`

Predecessor:
`T2A 2x temporal budget — REJECTED_REFERENCE_ENVELOPE_ROBUSTNESS`

## Purpose

Determine whether a smaller temporal-budget relaxation preserves the work-saving mechanism without reproducing the T2A candidate-only transaction failure.

## Controlling workload

Use the reference-stable B01-wet-plus workload identified before candidate selection:

- material: B01;
- initial regime: `h0=-10 cm`;
- top flux factor: `+5e-5 * K_top`;
- predictor qbot factor: `+5e-5 * K_bottom`;
- requested interval: `1e-4 day`;
- exact temporal budget: `1e-5 cm`;
- exact accepted substeps: 3;
- exact retries: 0;
- complete mass accounting.

The bottom-face prescribed head is materialized with the same B1.10 Darcy mapping used in T2/T2A.

## Budget screen

Test, against the unchanged 1x reference:

- 1.00x = `1.00e-5 cm`;
- 1.25x = `1.25e-5 cm`;
- 1.50x = `1.50e-5 cm`;
- 1.75x = `1.75e-5 cm`;
- 2.00x = `2.00e-5 cm` as the known failed boundary point.

No other control changes.

## Required evidence

Per arm:

- commit / failure status;
- accepted substeps;
- retries;
- nonlinear iterations;
- HeadCalc calls;
- pressure-head profile;
- water-content profile;
- bottom flux;
- storage change;
- canonical mass residual;
- replicated timing for every arm that commits.

## Selection rule

Choose the largest multiplier below 2x that:

1. commits reproducibly on the controlling workload;
2. introduces no retries;
3. reduces accepted solve work;
4. remains speed-positive;
5. keeps mass accounting complete;
6. has bounded state, storage and bottom-flux deviations.

If no multiplier above 1x satisfies these conditions, stop temporal-budget relaxation and close APPROX03 without a production temporal mode.

Any surviving multiplier must still pass a separate cross-material/regime matrix and coupled qualification before production admission.
