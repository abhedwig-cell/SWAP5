# F-HYDROFIT01 P6 — SWAP numerical probe preregistration

Authority: `integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`

## Question

Do hydraulically distinct parameter sets that are near-equivalent with respect to the fitted observations produce materially different numerical effort or robustness in the same SWAP5 Richards problem?

## Inputs

Use only the deterministic P5B representatives from the primary objective envelope.

Representative 0 is the fit optimum. Other representatives are selected solely for function-space coverage before any SWAP runtime/solver metric is observed.

## Frozen SWAP experiment

All representatives must use exactly the same:

- vertical discretization;
- initial pressure-head profile;
- atmospheric/boundary forcing;
- simulation interval;
- numerical configuration;
- solver implementation;
- transaction/retry policy;
- non-hydraulic process configuration.

Only the mapped hydraulic parameter vector changes.

The first probe should be a short deterministic canonical-compatible column case that exercises both wet and drying response but does not intentionally trigger unrelated optional physics.

## Primary numerical metrics

Record for every representative:

1. accepted interval/step count;
2. rejected/retried attempt count;
3. total nonlinear iteration count if exposed by the selected harness;
4. minimum accepted timestep;
5. mean accepted timestep;
6. terminal/final state completion status;
7. water-balance residual/closure metric already authoritative for the harness.

Wall-clock runtime is secondary because CI timing noise can dominate a small single-column experiment.

## Constitutive explanatory metrics

For the same representative, report from the P5B function grid:

- maximum and integrated spread in theta relative to optimum;
- maximum and integrated absolute difference in log10 K;
- selected simple stiffness descriptors from theta/C/K only if defined before observing solver outcomes.

No post-hoc stiffness score may be invented to maximize correlation.

## Gates

N0. Every run completes or its failure/retry outcome is preserved as data.

N1. Non-hydraulic inputs are byte/field identical across representatives.

N2. Representative selection is independent of solver outcomes.

N3. If numerical effort differs, report absolute metrics and ratios to representative 0; do not call the fastest set physically superior.

N4. Water-balance/state validity remains a separate axis from speed/effort.

N5. A null result, no material numerical difference, is a valid outcome and must be retained.

## Interpretation

P6 can show that observation-near-equivalent hydraulic fits have different SWAP numerical consequences under the frozen probe.

It cannot establish that one parameter set is physically more correct, nor that the same numerical ranking generalizes across forcing, profiles, grids or solver configurations.

A solver-aware fitting or Pareto objective remains prohibited until P6 evidence justifies a separate experiment.
