# F-PE-PROFILE04_CLOSEOUT — post-admission end-to-end performance rebaseline

Date: 2026-09-26

Status: `CLOSED_OBSERVATION_ONLY`

PR:
`#627 — F-PE-PROFILE04: post-admission end-to-end performance rebaseline`

Branch:
`work/f-pe-profile04-end-to-end-rebaseline`

Canonical authority:
`integration/f-ci-canonical@c52454b31d6f5d6ae6ed6af56460f158ddb45008`

Canonical performance admission at PROFILE04 start:
`F-CI110 = CANONICAL_ADMITTED_PRESERVED`

PROFILE04 modified no production source under `src/**`.

## Purpose

PROFILE04 re-established where production-shaped runtime sits after canonical admission of:

- PROFILE02-H03 constitutive tuple reuse;
- ZERO-WASTE B1 exact-P0 core;
- ZERO-WASTE B2 large-N groundwater fast paths;
- PLANVALID01;
- F-AHL50 bounded direct-retention opt-in.

The governing rule was that end-to-end and same-postimage measurements are authority. Historical microbenchmark percentages are not added to manufacture a total speedup claim.

## Measurement classes

Three measurement classes are kept separate throughout this closeout.

### Application / end-to-end-shaped measurements

These include production application initialization and repeated per-column execution. They are used to establish setup scaling and the fraction of repeated application time attributable to the Reference / transaction backend.

### Solver / backend measurements

These execute the serialized Reference backend or the qualified AHL solver fixtures directly. They are used to compare physical solve paths while holding the current postimage fixed.

### Microkernel measurements

These isolate constitutive and tridiagonal kernels. They are localization evidence only. Their percentages are not treated as additive application runtime attribution.

## Setup scaling

### PLANVALID01

Replicated canonical measurement at N=10,000:

- initialization candidate / baseline median ratio: approximately `0.38077`;
- setup reduction: approximately `61.9%`;
- repeated runtime ratio: approximately `1.003`.

PLANVALID01 is therefore a setup optimization. It materially removes large-N validation/setup work without providing or costing meaningful repeated runtime.

### F-AHL50 representation setup

Direct-retention / analytical initialization ratios:

- N=1: approximately `5x` or higher fixed-cost overhead depending on CI run;
- N=100: approximately `1.39-1.52x`;
- N=1,000: approximately `1.11-1.14x`;
- N=10,000: approximately `1.03-1.04x`.

The replicated planning value at N=10,000 is only about 3-4% initialization overhead.

Conclusion: immutable shared representation ownership amortizes the AHL construction cost strongly. Large-N setup is no longer the principal performance problem.

## Repeated exact-P0 gains already admitted

### ZERO-WASTE Reference

Replicated current measurement:

- mean candidate / historical-baseline ratio: approximately `0.722`;
- median ratio: approximately `0.724`;
- repeated Reference speedup: approximately `27-28%`.

### ZERO-WASTE directional

Replicated current measurement:

- mean ratio: approximately `0.757`;
- median ratio: approximately `0.759`;
- repeated directional speedup: approximately `24%`.

These are paired historical-baseline measurements on the qualified Reference/directional fixture. They are not combined arithmetically with AHL50 to claim one synthetic total speedup.

## F-AHL50 same-postimage repeated solver gain

Five independent timing jobs across:

- B01;
- B12;
- O05;
- O14;
- wet / mid / dry states;

give a stable current-postimage result.

Representative five-job medians:

- `0.822293737`;
- `0.845257498`;
- `0.845811822`;
- `0.847454164`;
- `0.850688605`.

Median of job medians:

`0.845811822`

Mean:

`0.842301165`

Planning interpretation:

- approximately `15.5%` repeated solver speedup;
- reasonable replicated job-median band: approximately `14-18%`;
- all 12 production cases remain speed-positive.

Earlier isolated 20%+ CI results are treated as timing variance rather than the central estimate.

PROFILE04 attempted to turn this into a standalone production-application AHL timing. That experimental probe was rejected because the standalone fixtures did not faithfully reproduce the prepared immutable direct-retention execution contract used by the production opt-in. No performance number from those failed probes is retained. The runner was removed again. The replicated same-postimage solver result remains authority for the AHL increment.

## Post-admission repeated application decomposition

PROFILE04 added an observation-only same-postimage decomposition using the production application fixture and the serialized Reference backend.

At N=10,000:

- application median: `9326.7994 ns/column`;
- Reference / transaction backend median: `8667.1928 ns/interval`;
- Reference backend share: `92.927835%`;
- residual application-wrapper share: `7.072165%`.

At N=1,000:

- application median: `9206.272 ns/column`.

The N=1,000 and N=10,000 values are close, confirming that repeated per-column cost is no longer dominated by large-N setup/context scaling.

### Diagnostic path equivalence

For the application fixture, each column reports:

- one application solver execution;
- three accepted internal solves from the full-half transaction interval;
- three nonlinear iterations;
- three Jacobian builds;
- three linear solves;
- three headcalc calls;
- zero internal retries.

Thus the Reference-backend comparison is aligned with the actual internal transaction path. The old PROFILE02 observation that about 92.3% of per-column application cost sat in the Reference / transaction interval remains valid on the new canonical stack, now freshly measured at about 92.93%.

This number was re-measured. It was not inherited from PROFILE02.

## New hotspot map

### 1. Reference / Richards / transaction route

Approximately 93% of repeated application runtime is still inside the Reference / transaction backend.

This is the dominant default repeated-execution block.

### 2. Application, groundwater-context and outer orchestration

Only about 7% remains outside the Reference backend in the N=10,000 application fixture.

PROFILE04 therefore finds no evidence that general application/context orchestration is currently the principal repeated-runtime target.

This does not mean every groundwater operation is free. It means the measured outer repeated application layer is now small relative to the solve backend after B2 and PLANVALID.

### 3. Nonlinear / candidate work

The qualified application fixture performs three internal Reference solves for the full-half interval and shows:

- one nonlinear iteration per internal solve;
- no internal retry amplification.

There is no evidence in this fixture for a retry/backtracking pathology large enough to justify a candidate/backtracking optimization workunit on PROFILE04 evidence alone.

The diagnostic field reports one accepted backtracking attempt per nonlinear step, but zero internal retries. PROFILE04 does not reinterpret those accepted attempts as failed backtracking work.

### 4. Constitutive hydraulics

Isolated four-node analytical MvG kernel medians:

- full constitutive evaluation: approximately `590 ns`;
- demand-routed constitutive evaluation: approximately `701 ns`.

The Reference fixture reports two constitutive evaluations per internal solve. With three internal solves per application interval, constitutive evaluation is clearly a material part of the Reference backend.

A rough microkernel scale of six evaluations is of order 3.5-4.2 us against an approximately 8.7 us Reference interval. This is localization evidence only. It is not an inclusive percentage claim because the real solve uses in-context dispatch, demand routing and surrounding solver work.

F-AHL50 already attacks part of this cost and gives about 15.5% same-postimage repeated solver gain within its qualified envelope.

### 5. Linear / tridiagonal solve

Isolated tridiagonal solve median:

`54.996 ns`

Three such solves are only about `0.165 us`, roughly 2% of the measured Reference interval.

The linear solve is therefore not a credible next dominant exact optimization target.

### 6. Directional response / tangent

This is the strongest new finding.

The production groundwater participant explicitly requests:

- `accepted_trajectory_direction%requested = .true.`;
- control coordinate: bottom head.

PROFILE04 therefore measured the actual bottom-head directional route, not only the earlier bottom-flux timing fixture.

Bottom-head result:

- Reference median: `8674.9500 ns/interval`;
- directional median: `16208.2952 ns/interval`;
- ratio: `1.868402146`;
- incremental cost: approximately `+86.84%`.

A separate bottom-flux measurement gave a very similar result:

- ratio: `1.886236799`;
- incremental cost: approximately `+88.62%`.

The effect is therefore not specific to the bottom-flux fixture.

The physical solve diagnostics remain unchanged:

- nonlinear iterations per solve: `1`;
- constitutive evaluations per solve: `2`;
- no extra full nonlinear solve is introduced by the directional request.

The isolated tridiagonal backsolve median is only:

`46.820 ns`

Three extra backsolves are therefore about `0.140 us`, less than 2% of the measured approximately `7.53 us` bottom-head directional increment.

Conclusion: the dominant directional overhead is not the raw tridiagonal backsolve. It lies higher in the accepted-trajectory tangent path, potentially among constitutive directional evaluation, factorization-capture lifecycle, RHS/data preparation, accepted-step accumulation, allocation/publication or other orchestration. PROFILE04 deliberately does not select one of these without a dedicated measurement.

### 7. Transaction / checkpoint / candidate machinery

Transaction work remains inside the approximately 93% Reference-backend block, but PROFILE04 has no observation-only evidence that cleanly separates all checkpoint/clone/candidate cost from physically necessary solver work.

Adding production instrumentation solely to obtain that split would violate the PROFILE04 observation-only boundary.

Because a much clearer exact hotspot exists in the production-required directional route, PROFILE04 does not broaden itself to instrument transaction internals.

## Timing variance and uncertainty

CI timing variance is non-negligible.

The AHL repeated benchmark showed individual jobs that could suggest more than 20% speedup, while replicated five-job aggregation converged near 15.5%.

For that reason:

- replicated medians are used for planning;
- isolated outliers are not promoted to performance authority;
- kernel timings are used only for localization;
- no historical microbenchmark percentages are added together.

The 92.93% backend share and approximately 87-89% directional increment were obtained from current-postimage measurements and are sufficiently large that ordinary CI timing noise does not change the qualitative hotspot ordering.

## How much faster is the new canonical production stack?

PROFILE04 supports the following measured statements, and no stronger synthetic claim:

1. the admitted ZERO-WASTE exact-P0 Reference path is approximately 27-28% faster than its qualified historical baseline;
2. the admitted ZERO-WASTE directional path is approximately 24% faster than its qualified historical baseline;
3. F-AHL50, when explicitly enabled inside its qualified envelope, adds approximately 15.5% same-postimage repeated solver speedup, with a replicated planning band of about 14-18%;
4. PLANVALID removes about 62% of large-N setup cost in the replicated N=10,000 comparison while leaving repeated runtime essentially neutral;
5. AHL50 representation initialization adds only about 3-4% setup at N=10,000.

PROFILE04 does **not** add 27-28% and 15.5% to claim a 40%+ application speedup. Those measurements have different baselines and scopes. A single combined historical-baseline-to-current-plus-AHL application wall-clock ratio has not been measured with a fixture that satisfies the production AHL preparation contract.

That limitation is explicit rather than hidden behind arithmetic composition.

## Remaining exact performance headroom

For the default non-directional path, much of the remaining repeated runtime is now genuine Reference/Richards work. The outer application layer is small and the linear solve is already tiny. Constitutive work remains material but has already received a successful exact acceleration through F-AHL50.

For the intended SWAP5-MODFLOW6 coupled path, however, one large exact hotspot remains unresolved: the required accepted-trajectory bottom-head directional tangent nearly doubles the Reference interval cost.

That overhead is too large to dismiss as a few-percent residual.

Therefore PROFILE04 does **not** recommend opening practical / approximate mode immediately.

## Exactly one recommended next workunit

Preregistered:

`F-PE-DIR01 — production bottom-head directional tangent exact-cost reduction`

Preregistration:
`docs/performance/F-PE-DIR01_PREREGISTRATION.md`

DIR01 must first decompose the directional increment and only then optimize a measured component. It must preserve the physical solve, accepted candidate, derivative meaning, mass balance and non-directional path.

No second exact workunit is recommended by PROFILE04.

## Decision after DIR01

If DIR01 materially reduces the directional overhead, rebaseline the coupled production route once.

If DIR01 demonstrates that the remaining directional and Reference costs are predominantly necessary solver work, that is the appropriate point to open the separately preregistered practical / approximate MultiSWAP performance phase, where bounded numerical deviation may be traded explicitly for larger runtime gains.

## Closure statement

F-PE-PROFILE04 is closed.

The post-admission hotspot map is sufficiently strong to carry the next performance decision:

- large-N setup is largely solved;
- approximately 93% of default repeated application runtime remains in Reference / transaction execution;
- the raw linear solve is small;
- constitutive work is material and already partially accelerated by F-AHL50;
- application/context wrapper overhead is small;
- production-required bottom-head directional tangent is the clearest remaining exact hotspot, adding approximately 87% to the Reference interval without adding a full nonlinear solve.

The only next exact performance workunit recommended by PROFILE04 is F-PE-DIR01.
