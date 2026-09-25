# F-PE-PROFILE02 — difficulty and component evidence

Date: 2026-09-25

Status: `DIFFICULTY_1_QUALIFIED`

Production-source parent: `f5ba657695156a936cb3dc8e14669f92d333753b`

PROFILE02 measurement head: `c32138980d3e6685a81585c02d662e4f4445bf40`

## Authorities

Numerical difficulty:

- GitHub Actions run `36146345572`;
- job `108108353711`;
- artifact `profile02-difficulty-census`;
- Ubuntu 24.04 GitHub-hosted runner;
- GNU Fortran 13.3.0;
- O2 measurement build;
- result: PASS.

Current-postimage constitutive component refresh:

- GitHub Actions run `36146345661`;
- job `108108355136`;
- artifact `profile02-component-cost`;
- same runner class and compiler family;
- result: PASS.

Two earlier difficulty workflow attempts failed during explicit runner dependency closure before model execution. They are harness failures, not numerical observations:

1. missing `mod_drainage_extended_exchange`;
2. missing `mod_b110_root_sink_provider`.

No production source was changed to repair those failures.

## Difficulty domain

PROFILE02 reuses the already repository-governed PUB-P2E04 Reference-Richards census instead of inventing a new difficult fixture.

The domain contains 162 cases:

- materials: `B01`, `B12`, `O01`, `O05`, `O14`, `O18`;
- effective saturation: 0.65, 0.85, 0.98;
- forcing: DRYING, NOMINAL, WETTING;
- coarse dt: 0.0016, 0.0004, 0.0001 day;
- fixed Reference Richards solver;
- fixed production tolerances from the PUB-P2E04 authority;
- no RossFast numerical execution.

For an accepted coarse solve, the frozen census also evaluates two half steps. Therefore the 162 cases generated 285 actual Reference solves.

PROFILE02 adds wall-clock timing and reads already-existing solver diagnostics. It does not alter the solve request.

## Census outcome

Of 162 cases:

- 47 end as ACCEPTED;
- 1 ends as RETRY_TOTAL_ONLY;
- 114 end as RETRY_MIXED;
- 0 are FAILED_OR_INVALID.

Failure/retry stage:

- coarse solve: 90 cases;
- first half: 21 cases;
- second half: 4 cases.

The purpose here is performance characterization, not re-adjudication of the PUB-P2E04 numerical acceptance domain.

## Main result: difficulty is backtracking-dominated

Across all 285 actual solves:

| quantity | correlation with solve wall time |
| --- | ---: |
| backtracking attempts | 0.996 |
| constitutive evaluations | 0.996 |
| constitutive candidate-demand evaluations | 0.996 |
| nonlinear iterations | 0.940 |
| Jacobian builds | 0.940 |
| linear solves | 0.940 |

The near-identical backtracking and constitutive correlations are structurally explainable from the current Reference HeadCalc route: every backtracking candidate updates hydraulic state through a constitutive demand evaluation before residual re-evaluation.

For the measured domain, the dominant difficulty amplifier is therefore **candidate work inside backtracking**, not merely the number of outer Newton iterations.

A simple descriptive fit over this one runner and this domain,

`solve_seconds ~= intercept + slope * constitutive_evaluation_count`,

explains about 99.3% of observed solve-time variance. This is attribution evidence, not a portable per-call cost model and not proof that constitutive evaluation alone consumes 99.3% of runtime. The count co-varies with residual and backtracking-control work.

## Runtime distribution

Across 285 solves:

- minimum: 5.889 microseconds;
- median: 14.452 microseconds;
- mean: 42.716 microseconds;
- 75th percentile: 90.586 microseconds;
- maximum: 122.083 microseconds.

This is a roughly twenty-fold spread between the cheapest and most expensive observed solve.

At case level, including all coarse/half solves belonging to a frozen PUB-P2E04 case:

| terminal class | cases | mean total runtime per case | mean backtracking attempts | mean constitutive evaluations |
| --- | ---: | ---: | ---: | ---: |
| ACCEPTED | 47 | 32.31 us | 14.38 | 17.38 |
| RETRY_TOTAL_ONLY | 1 | 54.26 us | 19.00 | 21.00 |
| RETRY_MIXED | 114 | 92.99 us | 89.12 | 90.37 |

Thus a retry-heavy case costs approximately three times an accepted case on this bounded domain before any higher-level timestep retry policy is added.

## Which conditions are expensive?

### Time-step level in this frozen domain

| coarse dt day | actual solves | mean solve runtime | median | mean iterations | mean backtracks |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0.0016 | 157 | 13.717 us | 9.534 us | 4.803 | 7.490 |
| 0.0004 | 74 | 64.424 us | 80.750 us | 12.676 | 60.743 |
| 0.0001 | 54 | 97.279 us | 98.648 us | 16.000 | 96.000 |

The smallest dt is the hardest regime in this particular fixed-flux/tolerance census. This must not be generalized into a claim that smaller timesteps make Richards solving intrinsically harder. It is an empirical property of this frozen P2E04 forcing/state/tolerance construction.

### Moisture state

| effective saturation | actual solves | mean solve runtime | median | mean iterations | mean backtracks |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0.65 | 100 | 38.745 us | 9.064 us | 7.920 | 34.550 |
| 0.85 | 97 | 41.781 us | 12.889 us | 8.701 | 37.196 |
| 0.98 | 88 | 48.259 us | 27.441 us | 10.455 | 43.091 |

Within this domain the near-saturated 0.98 state is more expensive on average than the drier 0.65 state. PROFILE02 therefore does **not** support a blanket claim that the driest hydraulic states are the runtime bottleneck.

### Material

| material | actual solves | mean runtime | median | mean iterations | mean backtracks |
| --- | ---: | ---: | ---: | ---: | ---: |
| B01 | 42 | 48.985 us | 29.309 us | 10.429 | 43.000 |
| B12 | 51 | 38.289 us | 9.354 us | 7.294 | 34.843 |
| O01 | 49 | 41.655 us | 13.880 us | 8.837 | 36.918 |
| O05 | 51 | 39.098 us | 14.782 us | 8.882 | 33.784 |
| O14 | 46 | 40.907 us | 15.654 us | 8.978 | 36.174 |
| O18 | 46 | 48.850 us | 15.133 us | 9.717 | 45.130 |

`O05` is explicitly present and can serve as the repository-backed O5-like comparison requested by PROFILE02. It is not uniquely expensive in this census. B01 and O18 have larger mean solve cost, and individual worst cases are distributed over several materials.

Material identity therefore matters, but much less cleanly than the actual backtracking trajectory.

### Forcing

Mean solve runtime is 44.106 us for DRYING, 43.167 us for NOMINAL and 40.893 us for WETTING. On this domain forcing label alone is a weak predictor compared with the realized solver trajectory.

## Constitutive component refresh

Current-postimage microbenchmarks confirm that the MvG provider remains a real compute component.

Full-provider cost:

- 4 nodes: 0.587 us/call;
- 20 nodes: 2.943 us/call;
- 60 nodes: 8.581 us/call;
- 200 nodes: 28.583 us/call;
- 1,000 nodes: 144.763 us/call.

The H04 demand microbenchmark also shows that the Reference path's candidate demand calls are materially cheaper than a full hydraulic tuple evaluation. For example at 4 nodes:

- full provider: 0.585 us/call;
- theta-only demand: 0.171 us/call;
- bottom point K: 0.071 us/call.

At 60 nodes:

- full provider: 8.601 us/call;
- theta-only demand: 2.315 us/call;
- bottom point K: 0.079 us/call.

This matters for F-AHL interpretation. PROFILE02 must not multiply full-provider cost by total constitutive-call count. Most difficult-candidate calls in the measured explicit-conductivity Reference path request water content only.

## Current HeadCalc demand structure

Source-path reconciliation confirms:

1. one full constitutive evaluation initializes the conductivity tuple;
2. each Newton iteration builds one Jacobian and executes one tridiagonal solve;
3. each backtracking candidate requests water content through `evaluate_demand(... WATER_CONTENT ...)` on the measured explicit-conductivity path;
4. the residual is then re-evaluated for that candidate;
5. capacity can be obtained separately/reused for the accepted candidate.

Hence the expensive difficulty multiplier is a compound:

`candidate hydraulic demand + residual recomputation + backtracking control`.

This is classified primarily as:

- C: solver/numerical algorithm work;
- D: constitutive/hydraulic evaluation;
- E: workload/difficulty-dependent work.

There is currently no evidence that this multiplier is category A pure software waste.

## Negative findings

The current evidence does not support these tempting shortcuts:

- `O05` is not a unique runtime hotspot;
- the driest state in the chosen domain is not the most expensive average state;
- linear-solve count alone does not explain difficult-case cost;
- forcing label alone does not explain difficult-case cost;
- total constitutive-call count must not be valued at full-provider cost;
- oxygenstress must not be characterized as a current production runtime hotspot because the repository authority still marks the relevant oxygen migration as review-only/not implemented.

## Implication for F-AHL

F-AHL remains directly relevant, but PROFILE02 narrows the target.

If F-AHL reduces cost of theta(h) candidate evaluations while preserving derivative consistency for the accepted Newton path, the value can be amplified strongly in high-backtracking regimes.

PROFILE02 does not open or implement a competing lookup representation.

The highest-value F-AHL performance evidence would therefore report cost separately for:

- initial/full hydraulic tuple;
- candidate theta-only demand;
- capacity demand/reuse;
- accepted/terminal evaluation.

## Remaining measurement needed before rank freeze

One issue remains before final ranking:

The easy large-N baseline is end-to-end per interval, whereas the P2E04 difficulty census times the direct Reference solver. PROFILE02 must still reconcile the fraction of easy-route time attributable to the solver versus surrounding transaction/application work on the **current postimage**.

A bounded current-postimage direct-solver/application paired measurement is sufficient. No new optimization should be implemented before that comparison.
