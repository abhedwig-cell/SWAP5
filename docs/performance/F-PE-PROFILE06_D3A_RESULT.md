# F-PE-PROFILE06 D3A result — O05 difficult-case mapping

Date: 2026-09-26

Status: `ROBUST_BUT_NOT_DIFFICULT`

## Mapping tested

Test-only FGC44 mapping:

- material: O05;
- initial top-node pressure head: -10 cm;
- coupling window: 1e-3 day;
- predictor qbot: 0 cm/day;
- top flux: 0 cm/day;
- exact/default production tolerance policy;
- max nonlinear iterations unchanged at 16;
- live SWAP + MODFLOW6 prepared-solve architecture unchanged.

The corresponding direct Reference workload required 14 nonlinear iterations.

## Result

Six independent exact/default live coupled replicas were run.

All six completed the live coupled solve and publication path.

In every observed coupled outer iteration:

- solver status: converged;
- nonlinear iterations: 2;
- Jacobian builds: 2;
- linear solves: 2;
- backtracking attempts: 2;
- internal retries: 0.

Each coupled run required four outer coupling iterations, but the maximum Richards corrector burden per outer iteration remained 2 nonlinear iterations.

The D3A CI job is intentionally marked failed because the preregistered difficulty criterion required at least 4 nonlinear iterations in one corrector trial.

## Interpretation

The direct difficult workload does not remain difficult after mapping into the current mode-5 coupled geometry.

The reason is structural:

- the predictor constructs a local response around an interface-consistent origin;
- the symmetric MODFLOW fixture keeps the coupled head close to that predictor origin;
- the prescribed-head corrector therefore receives only a small displacement and converges in two nonlinear iterations.

This is not a solver or coupled robustness failure.

## Decision

Do not test A1/A2C timing on D3A because it would reproduce the same easy-corrector limitation as PROFILE05R2.

Proceed to D3B:

- retain O05, h0=-10 cm and the 1e-3 day coupling window;
- vary only a finite groundwater-head bias around the predictor origin;
- use exact/default first;
- select the smallest stable bias that produces at least 4 corrector nonlinear iterations.

No model code changes are permitted.
