# F-HYDROFIT01 P6B result

Authority remained `integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`.

Run `36405564057` at `6c755d8b28ad8a82470f419cc0601d0d6025df23`: SUCCESS.

## Independent workload discovery

Only representative 0 was inspected during workload selection.

Under the preregistered discovery matrix the selected hardest converged multi-Newton case was:

- initial head: -75 cm;
- bottom head: -75 cm;
- top factor: 0;
- duration: 0.05 d;
- representative-0 nonlinear iterations: 34;
- representative-0 backtracking attempts: 34.

This workload was then frozen before evaluating representatives 1-7.

## Blind comparison

| Rep | Objective | Nonlinear | Jacobian | Linear | Backtrack | Mass residual | Bottom flux |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0.0204242 | 34 | 34 | 34 | 34 | 0 | -1.05050 |
| 1 | 0.2513962 | 29 | 29 | 29 | 29 | 0 | -0.86974 |
| 2 | 0.2247183 | 41 | 41 | 41 | 41 | 0 | -1.27247 |
| 3 | 0.2392429 | 38 | 38 | 38 | 38 | 0 | -1.13323 |
| 4 | 0.2249329 | 32 | 32 | 32 | 32 | 0 | -0.93023 |
| 5 | 0.1895798 | 32 | 32 | 32 | 32 | 0 | -0.99277 |
| 6 | 0.2023272 | 36 | 36 | 36 | 36 | 0 | -1.13106 |
| 7 | 0.2171560 | 38 | 38 | 38 | 38 | 0 | -1.15329 |

All eight runs converged and retained zero reported integrated mass residual.

The nonlinear-iteration range is 29 to 41. The maximum/minimum effort ratio is `41/29 = 1.4138`, approximately 41% more nonlinear iterations in the heaviest case than the lightest case under this probe.

Relative to fit-optimum representative 0:

- lightest representative: 29/34 = 0.853, about 15% fewer iterations;
- heaviest representative: 41/34 = 1.206, about 21% more iterations.

## Interpretation

H4 receives positive evidence in this controlled synthetic experiment: parameter sets inside the same preregistered near-equivalent fit envelope can produce materially different Richards nonlinear effort under a frozen workload.

This is not evidence that representative 1 is physically preferable to representative 2, nor that the 29-versus-41 ordering generalizes to other forcings.

The fit optimum is not the numerical optimum in this probe.

## Scientific consequence

A later solver-aware analysis is now justified, but it should be framed as a Pareto or robustness question among observation-supported parameter sets, not as replacing the physical-data objective with solver speed.

Before any solver-aware estimator is designed, replicate P6B over multiple independently frozen SWAP workloads and, later, real measured soil datasets.
