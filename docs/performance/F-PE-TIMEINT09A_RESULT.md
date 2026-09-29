# F-PE-TIMEINT09A result — blind exact-Newton BDF2 LTE response holdout

Date: 2026-09-29

Status: `CLOSED_EXACT_NEWTON_RESPONSE_NOT_CONSERVATIVE`

Authority:

- canonical base: `integration/f-ci-canonical@5cb278cdc6463b3c88c873917671e60e672370a9`;
- successful holdout Actions run: `36515602583`;
- holdout job: `109237050587`;
- conclusion: SUCCESS.

## Frozen estimator

Unchanged from P0:

`J_final * delta = M * tau_h`

with:

- exact final converged Newton TRIDAG factorization;
- no Jacobian reassembly;
- one additional backsolve;
- no additional nonlinear solve;
- `E9=max|delta|`.

No multiplier or recalibration was applied.

## Blind holdout bank

- B12 and O14;
- infiltration 1, 3 and 5 cm/day;
- R1, R1P5 and R2;
- base mean dt 0.010 and 0.005 d;
- 36 full trajectories.

## Holdout result

Full trajectories:

- 36/36 complete.

Local labels:

- 143 complete;
- 1 unavailable research-label trajectory;
- allowed maximum: 2.

Factorization authority:

- exact factor capture/backsolve succeeds for every complete label;
- no estimator-authority alternative solver use.

Predictivity:

- overall Spearman: `0.9282`;
- R1: `0.9362`;
- R1P5: `0.9374`;
- R2: `0.9173`.

All rank-correlation gates pass.

Scale:

- median actual/E9: `0.7941`;
- minimum: `0.3387`;
- maximum: `1.9247`;
- 100% of positive finite ratios lie within [0.25,2.0].

All scale gates pass.

## Failure of the frozen classifier gate

At the frozen safety threshold:

`E9 <= 0.01 cm`

the holdout contains five false-safe points.

False-safe set:

1. B12, rain 1 cm/day, R1, dt 0.010 d:
   - E9 about 0.00915 cm;
   - actual head error about 0.01165 cm.
2. B12, rain 5 cm/day, R1, dt 0.005 d:
   - E9 about 0.00791 cm;
   - actual head error about 0.01183 cm.
3. B12, rain 1 cm/day, R1P5, dt 0.008 d:
   - E9 about 0.00895 cm;
   - actual head error about 0.01125 cm.
4. O14, rain 5 cm/day, R1P5, dt 0.004 d:
   - E9 about 0.00965 cm;
   - actual head error about 0.01048 cm.
5. B12, rain 1 cm/day, R2, dt 0.006667 d:
   - E9 about 0.00794 cm;
   - actual head error about 0.01080 cm.

Safe coverage remains high:

- actually safe: 89;
- correctly classified safe: 74;
- coverage: about 83.1%.

But the frozen requirement was zero false-safe points.

## Interpretation

Using the exact final converged Newton response operator materially improves mechanistic fidelity and preserves excellent rank correlation.

However, the final-Newton linear response still slightly underpredicts local temporal error in several blind B12/O14 points.

Because:

- the remaining underprediction persists even with the exact Newton Jacobian;
- all scale ratios remain below 2;
- no material/forcing multiplier was preregistered;

the result must not be rescued by fitting a safety factor after exposure.

## Decision

Final classification:

`CLOSED_EXACT_NEWTON_RESPONSE_NOT_CONSERVATIVE`.

The response-estimator family stops here under the preregistered rule.

The required successor is an embedded integrator-pair study rather than another response approximation.
