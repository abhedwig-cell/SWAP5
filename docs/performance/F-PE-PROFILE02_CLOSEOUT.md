# F-PE-PROFILE02 — post-zero-waste performance re-baseline closeout

Date: 2026-09-25

Status: `CLOSED_MEASUREMENT`

Repository: `abhedwig-cell/SWAP5`

Production-source authority:

- F-PE-ZERO-WASTE01 branch: `work/f-pe-zero-waste01`
- authority commit: `f5ba657695156a936cb3dc8e14669f92d333753b`

PROFILE02 measurement authority at closeout:

- branch: `work/f-pe-profile02-rebaseline`
- PR: #609
- pre-closeout head: `ff5928d8c58655df974bcf0945eca46b1b77cc56`

PROFILE02 changes only measurement infrastructure and documentation. No production physics, solver policy, tolerance, water-balance, transaction or practical-mode behavior was changed.

## Closeout question

> After the zero-waste work, which necessary work actually determines SWAP5/MultiSWAP runtime, and how does that ranking change with scale and numerical difficulty?

The answer is now sufficiently supported to freeze a new hotspot map.

## Evidence authorities

### Scale baseline

Current production bootstrap, Reference Richards, optional processes disabled:

- workflow: `F-PE-PROFILE02 post-zero-waste scale baseline`
- current-head run lineage includes successful run `36146849074`
- preregistered N: 1, 100, 1,000, 10,000
- hard mass gate: 1e-12
- all measured columns completed and committed
- no internal retries on the easy/reference scale workload.

The first frozen three-repetition baseline gave:

| N | mean init s | mean interval s | mean us/column |
| ---: | ---: | ---: | ---: |
| 1 | 0.0000324 | 0.0000634 | 63.41 |
| 100 | 0.000428 | 0.001594 | 15.94 |
| 1,000 | 0.003613 | 0.008979 | 8.98 |
| 10,000 | 0.164925 | 0.094714 | 9.47 |

A later same-head paired decomposition run observed a median N=10,000 production cost of 7.910 us/column. The difference is normal shared-runner variation and is why no portable absolute speed claim is made.

On every easy/reference scale row, each column contributed exactly:

- 1 solver call;
- 1 committed substep;
- 3 nonlinear iterations;
- 3 Jacobian builds;
- 3 linear solves;
- 3 HeadCalc calls;
- 3 backtracking attempts;
- 0 internal retries.

The repeated execution curve is approximately linear from N=1,000 to N=10,000. The former large-N orchestration path is no longer the dominant repeated-runtime problem.

### Backend/application decomposition

Current-head O2 paired decomposition:

- workflow run: `36147301816`
- job: `108111543808`
- artifact: `profile02-decomposition`
- five backend/application pairs;
- no post-hoc sample removal.

Median results:

- Reference backend transaction interval: 7,296.956 ns;
- N=10,000 production application cost per column: 7,909.766 ns;
- backend fraction of per-column application cost: 0.922525;
- surrounding application/orchestration fraction: approximately 0.077475.

Therefore, on the easy/reference current-postimage workload, about 92% of repeated per-column time is already inside the Reference backend/transaction interval rather than the large-N application shell.

This is a same-runner workload decomposition, not a universal fraction for every SWAP5 workload.

### Numerical difficulty census

Repository-backed PUB-P2E04 Reference domain:

- materials: B01, B12, O01, O05, O14, O18;
- effective saturation: 0.65, 0.85, 0.98;
- forcing: DRYING, NOMINAL, WETTING;
- coarse dt: 0.0016, 0.0004, 0.0001 day;
- 162 frozen cases;
- 285 actual Reference solves because accepted coarse cases also execute two half solves;
- no RossFast numerical execution.

Qualified run authority:

- successful run lineage includes `36146345572`;
- job `108108353711`;
- artifact `profile02-difficulty-census`;
- GNU Fortran 13.3.0, O2, GitHub-hosted Ubuntu runner.

Result over 162 cases:

- ACCEPTED: 47;
- RETRY_TOTAL_ONLY: 1;
- RETRY_MIXED: 114;
- FAILED_OR_INVALID: 0.

Retry/failure stage:

- coarse: 90;
- first half: 21;
- second half: 4.

Across the 285 actual solves, solve wall time ranged from about 5.9 us to 122.1 us.

Correlation with solve wall time:

| counter | correlation |
| --- | ---: |
| backtracking attempts | 0.996 |
| constitutive evaluations | 0.996 |
| candidate-demand constitutive evaluations | 0.996 |
| nonlinear iterations | 0.940 |
| Jacobian builds | 0.940 |
| linear solves | 0.940 |

The strong constitutive/backtracking correlation does not mean constitutive evaluation alone accounts for 99.6% of time. Candidate hydraulic demand, residual recomputation and backtracking control co-vary structurally.

Case-level mean runtime:

- ACCEPTED: about 32.3 us/case;
- RETRY_MIXED: about 93.0 us/case.

Thus difficult/retry-heavy trajectories cost roughly three times accepted trajectories in this bounded domain before any higher-level application retry sequence is added.

### Hydraulic component refresh

Current-postimage MvG component microbenchmarks confirm that hydraulic evaluation remains real compute work, but call type matters.

Representative measured costs:

4 nodes:

- full tuple: about 0.585 us/call;
- theta-only demand: about 0.171 us/call;
- bottom point-K: about 0.071 us/call.

60 nodes:

- full tuple: about 8.60 us/call;
- theta-only demand: about 2.32 us/call;
- bottom point-K: about 0.079 us/call.

The difficult explicit-conductivity Reference route performs many theta-only candidate demands, not a full theta/C/K/dKdh evaluation on every backtracking candidate. PROFILE02 therefore rejects any hotspot estimate that multiplies total constitutive-call count by full-provider cost.

### Function profile

A coarse `gprof` run at N=10,000 was added as an independent check.

Authority:

- run `36146848694`;
- job `108110038889`;
- artifact `profile02-gprof`.

Because the flat profile includes initialization and repeated execution together, and because the sampling resolution is coarse relative to the approximately 0.1 s run, its percentages are not used as precise repeated-runtime fractions.

It nevertheless establishes two useful facts:

1. the repeated path visibly contains HeadCalc, backend advance, state clone, kernel interval execution and hydraulic-provider work;
2. setup is dominated by serialized execution-plan construction on this N=10,000 fixture.

## Scale conclusion

### Repeated coupling-window work

For N >= 1,000 the easy/reference repeated cost is near-linear in N.

The current same-runner decomposition shows that the Reference backend/transaction interval already accounts for about 92% of N=10,000 per-column application time.

Therefore the next repeated-runtime gains must primarily come from the required per-column numerical path, not from reopening the already-cleaned large-N groundwater/application shell without new evidence.

### One-time setup

Setup is not negligible:

- approximately 3.6 ms at N=1,000 in the first baseline;
- approximately 165 ms at N=10,000 in the first baseline;
- approximately 117 ms at N=10,000 in a later same-head run.

The superlinear-looking growth is supported by source inspection and the coarse function profile.

`fmr_build_serialized_execution_plan()` still calls `execution_plan_registry_valid()`, which performs pairwise duplicate checks over columns and state handles:

`do i = 1,N; do j = i+1,N`.

That is O(N^2) validation in a one-time setup path.

The gprof sample attributed about 0.10 s of the profiled N=10,000 process to serialized execution-plan building. Exact percentages are not claimed because initialization and execution share the same coarse sampling profile.

This is classified as a fresh category-A pure-waste candidate in setup. It does not invalidate the zero-waste closeout for repeated groundwater/application work because it is a different serialized execution-plan validation path.

## Numerical-difficulty conclusion

The central post-zero-waste difficulty result is:

> Runtime difficulty is governed more strongly by candidate work inside backtracking than by the count of outer Newton iterations alone.

Current explicit-conductivity HeadCalc structure explains the observation:

1. one initial/full constitutive tuple is evaluated;
2. each Newton iteration builds one Jacobian and solves one tridiagonal system;
3. each backtracking candidate updates the state;
4. each candidate performs a theta-demand hydraulic evaluation;
5. residual and convergence metrics are recomputed;
6. accepted candidate information can then feed the next iteration.

The dominant difficulty multiplier is therefore a compound of:

- C: solver/backtracking algorithm work;
- D: hydraulic candidate evaluation;
- E: workload-dependent nonlinear difficulty.

No evidence was found that this repeated multiplier is simply category-A software waste.

## Material, moisture and forcing findings

PROFILE02 explicitly rejects several simple hotspot stories.

### O05

O05 is included as a repository-backed O05 comparison. It is not uniquely expensive.

Mean solve time in the census was approximately:

- B01: 49.0 us;
- B12: 38.3 us;
- O01: 41.7 us;
- O05: 39.1 us;
- O14: 40.9 us;
- O18: 48.9 us.

The realized nonlinear trajectory is a better runtime predictor than the O05 label itself.

### Wet versus dry

Within this frozen domain:

- Se=0.65: mean about 38.7 us/solve;
- Se=0.85: mean about 41.8 us/solve;
- Se=0.98: mean about 48.3 us/solve.

So this evidence does not support the generic claim that the driest state is always the runtime bottleneck.

### Time step

Within this specific frozen P2E04 domain the smallest tested dt was the most expensive regime.

That is an empirical property of this exact state/forcing/tolerance construction. PROFILE02 does not generalize it into a statement that smaller timesteps intrinsically make Richards solving harder.

### Forcing label

DRYING, NOMINAL and WETTING means were close compared with the spread caused by the realized solver trajectory. Forcing label alone is therefore not a useful runtime predictor here.

## New post-zero-waste hotspot map

The map distinguishes one-time setup from repeated coupling-window cost.

### Repeated-runtime ranking

| rank | hotspot | class | evidence-based interpretation |
| ---: | --- | --- | --- |
| 1 | Reference candidate/backtracking cycle | C + D + E | strongest difficulty amplifier; backtracking/candidate-demand count correlates ~0.996 with solve time |
| 2 | regular Reference Newton cycle | C + D | on easy workloads every column still performs required Jacobian, linear solve and hydraulic work; backend/transaction interval is ~92% of large-N per-column application cost |
| 3 | remaining transaction/state/application work around backend | B + F | measurable but much smaller on easy large-N route; roughly 8% outside backend in paired decomposition |
| 4 | optional source/sink/process work | E | not activated by the easy baseline; no current evidence that it outranks the hydraulic solver path |
| 5 | remaining allocation/copy overhead | B/F or A only when proven | no fresh evidence of a leading repeated-runtime allocation/copy hotspot after zero-waste cleanup |

This ranking applies to the measured current Reference workloads. It is not a universal ordering for every optional-physics configuration.

### One-time setup ranking

| rank | hotspot | class | interpretation |
| ---: | --- | --- | --- |
| 1 | serialized execution-plan registry validation/build | A + F | confirmed O(N^2) pairwise validation and substantial N=10,000 setup time |
| 2 | remaining production bootstrap initialization | B + F | nonzero but not yet decomposed enough to justify another workunit |

## What is no longer interesting without new evidence

PROFILE02 closes the following as non-priority targets:

- GWPLAN01-class repeated groundwater plan construction;
- GWTOPO01-class repeated topology construction;
- GWCTX01 participant-handle pairwise scan already removed from the groundwater context;
- GWCTX03 old full owned-context representation;
- GWVIEW01 temporary typed-array plan-view export;
- previously removed redundant resets, copies, registry checks and diagnostic materialization;
- generic large-N orchestration as a repeated-runtime explanation;
- O05 as a special standalone runtime target;
- 'dry soil' as a generic runtime target;
- forcing label by itself;
- linear-solve count by itself as the explanation of difficult-case cost;
- oxygenstress as a production hotspot: the relevant repository authority remains review-only/not production-qualified;
- a new RossFast development line merely because Reference becomes expensive;
- any practical/approximate implementation inside PROFILE02.

These items may be reopened only by new workload-specific runtime evidence.

## F-AHL relation

F-AHL remains the owner of adaptive hydraulic representation.

PROFILE02 strengthens, rather than duplicates, that line:

- hydraulic evaluation is part of the dominant repeated solver path;
- difficult trajectories amplify candidate theta-demand calls strongly;
- the economically relevant F-AHL performance target is therefore not only the cost of a full hydraulic tuple;
- F-AHL should separately report cost and exactness for:
  - initial/full tuple;
  - candidate theta-only demand;
  - capacity demand/reuse;
  - accepted/terminal evaluation.

Any lookup/interpolant implementation remains in F-AHL.

## RossFast relation

RossFast remains production-admitted and is useful as an alternative algorithmic comparison.

PROFILE02 does not need a new RossFast patch to establish the current Reference hotspot map. The present evidence already shows where Reference time expands: nonlinear candidate/backtracking work.

A future Reference-versus-RossFast comparison is useful only if it asks a bounded question such as whether the alternative algorithm changes the number or cost of difficult candidate trajectories under the same physical envelope.

RossFast is not selected as a PROFILE02 follow-up workunit.

## Later practical/approximate mode

PROFILE02 identifies where a later explicit error budget could buy runtime most effectively:

- fewer nonlinear/candidate evaluations;
- fewer rejected/retried temporal trials;
- cheaper hydraulic representation;
- potentially coarser temporal/nonlinear acceptance only under separately governed physical-error qualification.

The data argue against spending that error budget first on large-N infrastructure that now represents only a small part of repeated per-column cost.

No approximation is implemented here.

## Selected next exact performance workunits

Exactly two follow-up workunits are selected.

### 1. F-PE-PLANVALID01 — serialized execution-plan exact validation

Purpose:

Remove or replace the O(N^2) pairwise duplicate validation in `execution_plan_registry_valid()` while preserving:

- exact validity semantics;
- duplicate detection;
- state-handle bounds;
- failure timing/observable contract unless explicitly qualified;
- execution order and template mapping;
- zero physics/numerical change.

Why selected:

- direct current-postimage runtime evidence exists;
- source complexity is explicit;
- setup growth is superlinear-looking;
- this is category-A pure waste and therefore comes first under the SWAP5 performance strategy.

Acceptance must measure setup at N=1, 100, 1,000 and 10,000 and verify that repeated interval runtime and all result semantics are unchanged.

### 2. F-PE-NEWTON-CANDIDATE01 — exact candidate/backtracking path reduction

Purpose:

Decompose and reduce exact work per Reference backtracking candidate without changing:

- Newton mathematics;
- line-search/backtracking policy;
- tolerances;
- convergence/failure timing;
- water balance;
- accepted/rejected trajectory semantics.

The first audit target is the current compound:

`candidate theta demand -> residual recomputation -> convergence/backtracking control`.

This workunit may identify reusable/cached exact quantities or cheaper exact control/data movement, but it must not create a competing hydraulic approximation.

If the dominant exact saving lies inside theta/C/K representation, implementation is handed to F-AHL.

Why selected:

- it is the strongest measured repeated-runtime difficulty amplifier;
- retry-heavy cases cost about three times accepted cases in the frozen census;
- it attacks repeated work rather than one-time infrastructure;
- it is compatible with the exact-first strategy.

## Measurement limitations

1. Absolute runtimes come from shared GitHub-hosted runners and are not portable machine claims.
2. The main scale fixture is an easy/reference hydraulic workload with optional processes disabled.
3. The P2E04 difficulty domain is broad enough to expose strong nonlinear variation but is not a complete climatological/field workload.
4. O05 is a repository material identifier; PROFILE02 does not relabel it as a soil textural class without separate authority.
5. The gprof profile has coarse sampling resolution and mixes setup with repeated execution. It is supporting evidence only.
6. PROFILE02 did not construct a new production oxygenstress workload because current repository authority does not justify one.
7. PROFILE02 did not implement or benchmark a new approximate mode.
8. The repository-wide F-CI canonical workflow run `36147601740` failed only in `current-restricted-canonical-preservation`; all listed frozen historical authorities in that run passed. A direct compare from the production parent `f5ba657...` to the PROFILE02 closeout head contains only added `.github/workflows/`, `docs/performance/` and `tests/fpe/` files and no `src/` or `reference/` changes. PROFILE02 therefore did not introduce a production-source delta that can explain that preservation failure. The PR remains measurement-closed, not a canonical production admission; the moving-preservation failure belongs to upstream/base reconciliation.

## Final state

```text
RECONCILE       = COMPLETE
BIND AUTHORITY  = COMPLETE
PREREGISTER     = COMPLETE
MEASURE         = COMPLETE
DECOMPOSE       = COMPLETE
RANK            = COMPLETE
SELECT          = COMPLETE
CLOSE           = COMPLETE

PRODUCTION OPTIMIZATION IN PROFILE02 = NONE
NEXT EXACT WORKUNITS                 = 2
  1. F-PE-PLANVALID01
  2. F-PE-NEWTON-CANDIDATE01
```

The old hotspot map is superseded for the measured post-zero-waste Reference/MultiSWAP route.
