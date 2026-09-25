# F-PE-ZERO-WASTE01 — second tranche checkpoint

Date: 2026-09-25

Source head: `565819c346cea94e294e76830a2ad33e155668a4`

Status: `QUALIFIED_SECOND_TRANCHE_CHECKPOINT`

## Scope

This checkpoint supersedes the earlier runtime ranking for the active zero-waste branch.

The branch has moved materially since the first tranche checkpoint. Candidate selection after this point must use the current post-cleanup runtime distribution rather than the older ~10% checkpoint.

The governing rule remains:

> work that is not needed for the requested result should not execute.

No approximation, tolerance relaxation, accepted-state change or water-balance concession is admitted by this checkpoint.

## Broad paired runtime against original zero-waste baseline

Workflow run: `36122864825`.

Reference route:

- mean candidate/baseline ratio: `0.748655628`;
- median ratio: `0.758560660`;
- mean shared-runner speedup: `25.134437%`;
- mean delta: `-1869.809560 ns/interval`;
- verdict: PASS.

Directional route:

- mean candidate/baseline ratio: `0.776945911`;
- median ratio: `0.777784507`;
- mean shared-runner speedup: `22.305409%`;
- mean delta: `-4767.732820 ns/interval`;
- verdict: PASS.

These are workload-specific shared-runner observations, not portable universal SWAP5 speedup claims.

## Exact-zero-work state

Current PROFILE01/FKT22 evidence remains:

- workspace full resets per solve: 0;
- workspace zeroed bytes per solve: 0;
- workspace full resets per full/half interval: 0;
- workspace zeroed bytes per interval: 0;
- nonlinear iterations per solve: 1 on the H03 workload;
- constitutive evaluations per solve: 2;
- O0/O2 physical/runtime identity: PASS;
- poisoned-workspace equivalence: PASS.

The H03 constitutive pattern is now:

- initial full evaluations: 1;
- candidate full evaluations: 0;
- candidate demand evaluations: 1;
- candidate capacity-only evaluations: 0 on the one-iteration workload;
- terminal candidate evaluations: 1;
- candidate-capacity reuse: 0.

This means terminal-candidate capacity waste has already been removed on the qualified `SWKIMPL=0` route. Capacity is only materialized when a later Newton iteration actually needs it.

## Structural MultiSWAP cleanup

Qualified work now includes:

- validated execution-plan reuse;
- repeated O(N²) registry validation removal on the production bootstrap owner;
- persistent canonical execution order;
- pre-resolved template indices;
- indexed receipt validation/lookup;
- suppression of unused worker-assignment diagnostics;
- suppression of unused column/summary diagnostics on the production bootstrap route;
- suppression of serialized concurrency atomics when those diagnostics are not requested;
- accelerated groundwater participant handle resolution;
- exact fallback behavior retained for generic/untrusted callers.

Large-N structural improvements are complexity changes, not merely CI timing changes.

## Parameter configuration tranche

### H21

Repeated object allocation/deallocation and equal-shape geometry reallocation were removed while still overwriting all current values.

No parameter-value caching was introduced by H21.

### H22A

Production bootstrap establishes an explicit immutable-owner contract for prepared hydraulic parameters.

Trusted mode skips the O(24*N) raw/prepared compatibility scan while generic callers remain untrusted.

### H22B

On the trusted immutable-owner route the backend borrows the already prepared hydraulic representation only for the duration of the kernel trial.

No borrowed pointer survives `run_trial`.

Generic callers retain owned-copy/fresh-preprocess semantics.

Qualification evidence includes trusted/untrusted physical identity, stale-cache fallback and A-B-A prepared-binding replay.

## Constitutive demand results

### Positive

Demand-specialized provider work has produced measurable gains.

H04C isolated paired observation:

- Reference mean speedup: ~0.51%;
- directional mean speedup: ~1.70%.

### Negative

The intuitive replacement of the initial full provider call by `conductivity + capacity` demand is rejected.

Component evidence showed the narrower K+C path slower than the current full provider implementation:

- N=60: full ~8.66 us, K+C ~9.83 us;
- N=200: full ~28.69 us, K+C ~33.08 us;
- N=1000: full ~143.43 us, K+C ~164.24 us.

Therefore the initial full call remains.

## Directional tranche

### HDIR03A

Base-state accepted-step constitutive demand was narrowed to conductivity-only where only conductivity is consumed.

Qualification remains green.

### HDIR04

Trajectory ownership transfer via `move_alloc` was rejected and rolled back.

Although component copy/allocation costs were measurable, isolated directional paired runtime was neutral-to-negative:

- mean candidate/parent ratio: `1.002118524`;
- mean speedup: `-0.211852%`.

Do not reopen HDIR04 without materially different evidence.

### HDIR05

The accepted post-backsolve state direction now uses a theta-only directional capability.

The base-state full theta+K direction remains unchanged because K direction is required for the tangent.

Differential production-capability evidence:

- 144 branch/boundary cases;
- 0 mismatches against the full directional oracle.

Isolated parent/candidate directional paired result:

- mean candidate/parent ratio: `0.949138524`;
- median ratio: `0.942166610`;
- mean shared-runner speedup: `5.086148%`;
- mean delta: `-893.565940 ns/interval`;
- verdict: PASS.

This is a qualified positive P0 candidate.

## Transaction/state movement

Fresh full/half state materialization remains semantically required for exact current transaction isolation.

Earlier copy-cost characterization showed state materialization small relative to total runtime and did not justify clone-elimination work.

Directional attempt-context capture is also not classified as pure waste:

- accepted trajectory state can mutate inside `advance`;
- an outer transaction rejection must restore the previous accepted trajectory;
- therefore pre-attempt trajectory context is required on the directional route.

No further ownership-transfer candidate is admitted from current evidence.

## Groundwater forcing reuse

Several forcing-buffer/persistent-forcing reuse candidates were tested and rolled back because freshness semantics were not safely preserved.

Negative results are retained as evidence.

Do not reintroduce persistent forcing reuse without an explicit generation/freshness contract.

## Current P0 interpretation

For the qualified H03 application-host workload, the obvious high-confidence P0 waste has been substantially reduced.

Remaining work should not be selected from stale micro-hotspot lists.

The next exact audit should prioritize only candidates with new evidence in one of these classes:

1. disabled-process work still executed on production profiles;
2. loops over inactive domains;
3. repeated representation conversion or packing;
4. scratch allocation/resizing that survives current persistent-capacity work;
5. coupled groundwater orchestration overhead that remains after registry/forcing cleanup;
6. multi-iteration workloads where the one-iteration H03 demand pattern is not representative.

The directional path should not receive further vector ownership/copy work without stronger evidence. Current exact demand narrowing has already produced the material gain.

## Phase boundary

P0 is not declared globally complete for every SWAP physics combination.

However the H03/production-bootstrap exact-cleanup route is now mature enough that further micro-optimization must compete against:

- multi-iteration exact solver improvements;
- RossFast;
- ROM;
- coarser spatial/vertical schematization;
- later application-qualified P2 acceleration.

The next candidate must therefore demonstrate either:

- clearly avoidable exact work on a realistic production path; or
- material runtime significance after current cleanup.

Small code changes that merely reduce apparent operation count but do not improve measured runtime should be retained as negative evidence, not accumulated in production.
