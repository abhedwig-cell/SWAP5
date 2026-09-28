# F-HYDROFIT01 P6C — multi-regime solver-effort replication preregistration

Authority: `integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`

## Purpose

Test whether the P6B solver-effort differentiation among observation-near-equivalent hydraulic parameter sets is specific to one selected workload or recurs across distinct hydraulic regimes.

## Representative set

Use exactly the same 8 deterministic P5B representatives as P6B. No reselection is permitted.

## Workload matrix

Use a fixed matrix chosen before observing P6C outcomes.

Initial/bottom head regimes:

- wet: -10 cm;
- middle: -75 cm;
- dry: -500 cm.

Top-flux factors relative to initial top conductivity:

- -1;
- 0;
- +1.

Durations:

- 0.01 d;
- 0.05 d.

This gives 18 workloads and 144 representative-workload solves.

The previously selected P6B workload (-75, factor 0, 0.05 d) is included and identified as the replication anchor.

## Metrics

For every solve retain:

- convergence status;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- mass residual;
- bottom flux.

For every workload report:

- min, median and max nonlinear iterations across representatives;
- max/min effort ratio when all relevant values are positive;
- representative IDs for minimum and maximum effort;
- whether the fit optimum is minimum, maximum or interior.

Across workloads report:

- count with identical effort across all representatives;
- count with nonzero effort spread;
- count with >=10%, >=20% and >=40% max/min iteration spread;
- per-representative median rank and mean iteration ratio relative to representative 0, only across converged comparable workloads.

## Gates

R0. P6B anchor reproduces its previously recorded 34-iteration optimum and 29-41 representative range within exact integer diagnostics.

R1. All workload definitions are identical across representatives except hydraulic parameters.

R2. Nonconvergence is data, not filtered out.

R3. No workload is removed because it weakens the hypothesis.

R4. No universal 'best parameter set' is claimed from this matrix.

R5. A null replication result is admissible.

## Interpretation

Repeated effort differences across independently fixed regimes strengthen the claim that observation-near-equivalent hydraulic representations can differ numerically.

Changing rank across regimes would instead indicate that numerical convenience is forcing-dependent, which is itself important evidence against a single solver-aware penalty based on one workload.
