# F-PE-PROFILE02 — baseline 1 post-zero-waste scale evidence

Date: 2026-09-25

Status: `BASELINE_1_QUALIFIED`

Production-source parent: `f5ba657695156a936cb3dc8e14669f92d333753b`

Measurement head: `a8cb0170b2e4a13eda4242b11fb3776e7616651e`

GitHub Actions authority: run `36145585357`, job `108105808215` = PASS.

Build class: GitHub-hosted Ubuntu runner, O2. Absolute timings are runner-local observations and are not portable speed claims.

## Workload

The baseline uses the cleaned Reference Richards production bootstrap with:

- optional processes disabled;
- initial pressure head -75 cm;
- one short accepted interval;
- exact production transaction path;
- mass tolerance 1e-12;
- no solver-policy, physics or tolerance modification for profiling.

Each N was executed three times in a fresh process, so initialization and one interval are separately measured.

## Measurements

| N | mean init s | median init s | mean interval s | median interval s | mean us/column |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 0.000032427 | 0.000031429 | 0.000063405 | 0.000063940 | 63.405 |
| 100 | 0.000428408 | 0.000431687 | 0.001594267 | 0.001620490 | 15.943 |
| 1,000 | 0.003612518 | 0.003566308 | 0.008979162 | 0.008991502 | 8.979 |
| 10,000 | 0.164925181 | 0.163752822 | 0.094713535 | 0.093860352 | 9.471 |

All 12 runs completed and committed every requested column. Maximum reported mass residual was zero.

## Solver counters

For every column in every scale:

- solver calls: 1;
- accepted substeps: 1;
- nonlinear iterations: 3;
- Jacobian builds: 3;
- linear solves: 3;
- HeadCalc calls: 3;
- internal retries: 0;
- backtracking attempts: 3.

Thus at N=10,000 the interval contains exactly:

- 10,000 solver calls;
- 30,000 nonlinear iterations;
- 30,000 Jacobian builds;
- 30,000 linear solves;
- 30,000 HeadCalc calls;
- 30,000 recorded backtracking attempts;
- no internal retries.

## Interpretation

### Repeated interval cost

The single-column result contains substantial fixed dispatch/process overhead and is not representative of large MultiSWAP throughput.

From N=1,000 to N=10,000, interval runtime is close to linear in participant count and stabilizes near 9–9.5 microseconds per column on this runner. There is no renewed superlinear large-N execution signature in the cleaned route.

This is consistent with the zero-waste closeout: the previously dominant large-N structural work no longer determines repeated execution cost for this workload.

### Initialization

Initialization is approximately 0.165 s at N=10,000, versus approximately 0.095 s for one interval. Setup is therefore larger than one interval at this scale.

That does not make setup the dominant transient cost: it is paid once for a persistent owner, while interval execution repeats. PROFILE02 must keep setup separate rather than fold it into per-window cost.

### Numerical work

The easy/reference workload has a completely regular numerical signature. Runtime growth from N=1,000 to N=10,000 coincides with exact linear growth in nonlinear iterations, Jacobian builds, linear solves and HeadCalc calls.

The baseline therefore shifts the main question from large-N orchestration to the cost of required per-column numerical work.

It does not yet identify which part of a Newton cycle dominates wall time. Constitutive evaluation, matrix/Jacobian construction and tridiagonal solution require current-postimage component measurement.

## What this baseline rules out

For this workload there is currently no evidence that any of the following is a leading repeated-runtime problem:

- pairwise registry validation;
- repeated execution-order construction;
- canonical groundwater plan/topology construction;
- application-context handle uniqueness scanning;
- full application-context cell copying;
- temporary-array plan-view export;
- serialized diagnostic materialization removed by the production owner.

Those remain reopenable only if a different workload activates a materially different route.

## Next measurement gate

Do not optimize yet.

Next PROFILE02 evidence must add:

1. current-postimage component cost for constitutive evaluation and the core nonlinear/linear cycle;
2. numerically easy versus difficult single-column trajectories using repository-backed fixtures;
3. correlation of wall time with nonlinear iterations, Jacobian builds, linear solves, constitutive calls, retries and accepted/rejected work.

Only after those measurements may the hotspot ranking be frozen.
