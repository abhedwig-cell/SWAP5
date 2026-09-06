# MultiSWAP measurement and benchmark architecture

**Workstream:** MP  
**Slice:** MP-1  
**Status:** Active measurement contract, implementation pending  
**Baseline:** `40aef01c5c89dc9e02bba50d31c884dcdd2fd2d5`  
**Scope:** CPU measurement architecture for large MultiSWAP runs without performance-driven changes to physical formulations

## Purpose

MP starts by making computational cost observable before choosing optimizations. The first phase does not change SWAP physics, numerical tolerances, fallback semantics or model topology for speed. It defines what must be measured, how results are attributed to columns and batches, and which evidence is required before later performance changes can be judged.

This page is a measurement contract, not a claim that the final MultiSWAP runtime, storage layout or execution classes already exist. The current implementation status remains authoritative in the architecture status map.

## Governing rules

1. Physical output and water accounting are authoritative. Measurement may add observation overhead but must not change accepted physical results.
2. Persistent column state, shared immutable parameters and worker scratch are measured separately.
3. Timing is attributed to stable logical categories rather than current legacy routine names, so the benchmark survives refactoring.
4. Per-column cost distributions are retained. Averages alone are insufficient for MultiSWAP because slow columns can dominate batch makespan.
5. Physical configuration and numerical execution policy remain separate dimensions in every benchmark record.
6. Normal, relaxed and fallback execution are reported explicitly. A fallback path is never counted as a performance success unless it remains within its qualification envelope and closes the water balance.
7. CPU measurements form the reference baseline for later SIMD or GPU decisions. GPU work is outside MP-1.

## Measurement layers

MP uses two measurement layers.

### Low-overhead counters

These counters are intended to be cheap enough for representative large runs:

- accepted solver intervals;
- Newton iterations;
- residual evaluations;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- timestep reductions and retries;
- alternative linear-solver uses;
- execution-class transitions;
- normal, relaxed and fallback interval counts;
- process-call counts where the process is optional or materially expensive.

### Timed spans

Timed spans provide inclusive or exclusive CPU and wall-clock time for major categories. The implementation must define whether a span is inclusive or exclusive and must not mix the two silently.

Required top-level timing categories are:

| Category | What it measures |
| --- | --- |
| `constitutive` | soil hydraulic constitutive evaluations and related derivatives/interpolation needed by the solver |
| `residual` | assembly/evaluation of the nonlinear residual excluding constitutive time when exclusive timing is available |
| `jacobian` | Jacobian/coefficient construction excluding the linear solve |
| `linear_solve` | tridiagonal or alternative linear-system solution |
| `newton_control` | Newton convergence checks, step control and backtracking not included above |
| `soil_water_other` | remaining soil-water solver work not represented by the preceding categories |
| `surface_atmosphere` | surface storage, top-boundary and atmosphere-side process work |
| `crop_et_root` | crop, evapotranspiration and root-uptake work |
| `drainage_irrigation` | drainage and irrigation process work |
| `macropore` | macropore physics when active |
| `thermal` | soil heat/frost process work when active |
| `solute` | solute process work when active |
| `crop_growth_nutrients` | crop-development and nutrient/soil-management work when active |
| `transaction` | checkpoint, rollback, commit and state-copy work |
| `runtime_batching` | template classification, queueing, worker dispatch, batch packing/unpacking and scheduling overhead |
| `diagnostics` | benchmark and runtime diagnostic assembly overhead |
| `other_kernel` | remaining kernel work that cannot yet be assigned more precisely |

The category set is intentionally solver-implementation independent. A full Richards solver and a future coarse solver can populate the same high-level record even when their internal kernels differ.

## Memory accounting

Memory is reported by ownership and lifetime, not only as process RSS.

### Persistent per-column state

For each model template, report:

- physical state bytes per column;
- optional-module state bytes per active column;
- bookkeeping bytes required per logical column;
- parameter-reference bytes per column;
- checkpoint bytes if a committed-state checkpoint requires additional storage;
- warm-start bytes separately from authoritative physical state.

Shared immutable parameters are reported once per unique parameter object and must not be amortized into per-column state without also reporting the unamortized total.

### Worker scratch

For each worker-compatible template, report:

- reserved scratch bytes;
- peak scratch bytes used;
- Jacobian/factorisation bytes;
- Newton/residual-vector bytes;
- constitutive/intermediate bytes;
- temporary allocation count during a trial;
- scratch resize count.

The key scaling test is that heavy solver scratch grows with active workers or jobs, not with the total number of logical columns.

### Process-level memory

Peak resident memory remains useful as an external cross-check, but it is not a substitute for ownership accounting. A benchmark report should therefore contain both internal byte accounting and process-level peak RSS where the platform allows it.

## Per-column benchmark record

Every accepted or rejected interval contributes a record that can be aggregated to column, template, execution-class and run level. The machine-readable field contract is defined in `benchmark-record.schema.json`.

Minimum identity fields are:

- benchmark run ID and code revision;
- case ID and column ID;
- model-template ID;
- physical configuration signature;
- numerical policy ID;
- execution class (`normal`, `relaxed`, `fallback`, or implementation-defined qualified extension);
- soil/profile identifier where available;
- number of vertical nodes;
- interval `[t0,t1]`;
- worker ID and batch ID when applicable.

Minimum outcome fields are:

- accepted/rejected status;
- mass-balance residual and pass/fail result;
- Newton, backtracking and retry counts;
- timed category totals;
- persistent-state and scratch bytes where available;
- fallback provenance if used.

## Required cost distributions

For every large-column benchmark, report at least:

- count;
- mean;
- median/p50;
- p90;
- p95;
- p99;
- maximum;
- standard deviation or another explicit dispersion measure;
- share of total CPU time consumed by the slowest 1 percent of columns;
- fraction of columns with one or more retries;
- fraction of intervals entering relaxed or fallback execution.

A throughput number without the corresponding tail distribution is incomplete MultiSWAP evidence.

## Batch-divergence metrics

Homogeneous templates are intended to reduce divergence, but MP measures that claim rather than assuming it.

For each batch, retain:

- batch size;
- minimum, median and maximum per-column solver work;
- minimum, median and maximum Newton count;
- retry incidence;
- execution-class splits;
- worker busy time and idle time where measurable;
- batch makespan.

For lockstep or SIMD-like batches, also report an estimated lockstep efficiency:

```text
sum(per-column work) / (batch_size * max(per-column work))
```

The exact work unit may be CPU time, Newton iterations or another explicitly named cost proxy. The unit must be consistent within a comparison.

For dynamically scheduled CPU workers, report load imbalance separately, for example maximum worker busy time divided by mean worker busy time. Do not interpret the lockstep metric as worker-scheduling efficiency.

## Benchmark families

### MP-B01: single-column decomposition

Purpose: establish the timing and counter decomposition for one representative reference-mode column.

Required evidence:

- all mandatory solver timing categories populated;
- counters reconcile with the solver control flow;
- measurement on/off produces identical qualified physical output;
- water balance remains within the VQ acceptance rule.

### MP-B02: homogeneous scaling

Purpose: measure one model template at increasing column counts.

Initial sizes should include at least a small correctness batch, a cache-scale batch and a large throughput batch. Exact sizes depend on the available runtime, but the final qualification set must include a scale relevant to hundreds of thousands of logical columns.

Report throughput, memory scaling, tail cost and worker utilization.

### MP-B03: mixed-template runtime overhead

Purpose: separate the cost of runtime classification and multiple template queues from the kernel cost itself.

Compare equivalent work arranged as homogeneous template batches against the same population presented in a mixed order. Physics and numerical policy stay unchanged.

### MP-B04: difficult-column tail

Purpose: quantify heavy-clay/B12-like and other known slow regimes as a cost distribution problem rather than an anecdotal single run.

The SWAP 4.3.1 distribution contains B12 hydraulic parameters in `Staringreeks_2018.csv`, but the inspected distribution does not contain a dedicated executable B12 benchmark fixture. Creating and qualifying that fixture is therefore a required follow-up before MP may claim B12 coverage.

Report B12-like columns separately from the surrounding population, including their share of total CPU time, Newton iterations, retries and contribution to batch makespan.

### MP-B05: execution-class routing

Purpose: measure normal, relaxed and fallback routing once those runtime classes are implemented and VQ-qualified.

This benchmark is blocked in MP-1 because the current architecture documents these classes as target behaviour rather than a qualified production runtime. MP may define the record fields now but must not invent performance results for non-existent paths.

### MP-B06: optional-physics cost

Purpose: prove that inactive optional functionality does not impose the same memory or compute cost as active functionality.

Compare otherwise compatible templates with and without optional modules such as macropores, special drainage, thermal or solute processes. This is a resource-accounting comparison, not permission to change physics for speed.

## CPU reference baseline

Every performance result intended for comparison must record enough environment information to reproduce the CPU context:

- exact code commit;
- benchmark-schema version;
- compiler and version;
- optimization/debug flags;
- linked math/runtime libraries where material;
- CPU model and logical/physical core count;
- memory capacity;
- operating system;
- worker/thread count;
- affinity or pinning policy if used;
- benchmark repeat count and warm-up policy;
- whether file I/O is excluded from the timed region;
- wall-clock and CPU-time clock sources.

The first baseline is CPU-only. Later GPU evidence must compare against an equivalent qualified CPU workload and must not change the physical problem merely to improve accelerator utilization.

## Legacy SWAP 4.3.1 instrumentation map

The inspected SWAP 4.3.1 source is useful for identifying current logical cost boundaries. It is not the target component layout.

| Logical metric | Legacy observation point |
| --- | --- |
| constitutive evaluations | `headcalc.f90` calls to `watcon`, `hconduc`, `moiscap`, `dhconduc` and conductivity averaging |
| residual | `headcalc.f90` `vector_F` |
| Jacobian | `headcalc.f90` `jacobian_F` |
| linear solve | `headcalc.f90` call to `tridag`; rare fallback through `alternative_solver` using `bandec`/`banbks` |
| Newton/backtracking | `headcalc.f90` nonlinear iteration and backtracking loops |
| soil-water transaction/retry | `soilwater.f90` state save/reset plus the retry loop in `swap.f90` around `SoilWaterStateVar(2)` and `TimeControl(5)` |
| process costs | process calls around the soil-water step in `swap.f90`, including root extraction, bottom boundary, drainage, frost, heat, solute and crop processes |

Several arrays in legacy `headcalc` are local numerical work arrays, while many other hydraulic arrays remain globally stored. MP does not infer final target ownership from that legacy placement. Ownership is measured against the SWAP5 state/scratch contract as migration proceeds.

## Instrumentation qualification before performance conclusions

MP-1 defines the following gate for the measurement layer itself:

1. measurement enabled versus disabled gives the same VQ-qualified physical endpoint and water balance for the same input;
2. rejected trials remain excluded from committed physical history while their cost is still recorded;
3. retry, Newton, Jacobian and linear-solve counters reconcile with known control flow on small inspectable cases;
4. per-column records aggregate consistently to template and run totals;
5. memory accounting distinguishes persistent state, shared parameters and worker scratch;
6. scratch poisoning/randomization tests from ADR-0003 remain result-independent;
7. benchmark metadata identifies the exact code revision and CPU environment;
8. measurement overhead is quantified before fine-grained timing comparisons are used.

No hard percentage limit for instrumentation overhead is set in MP-1. That threshold should be based on measured overhead after the first implementation, not guessed in advance.

## Integration points

### RT runtime workstream

MP consumes template IDs, execution-class IDs, batch IDs, worker IDs and scheduling events from RT. MP must not define RT scheduling semantics through the profiler. If MP needs a new runtime-visible identifier, that is an explicit RT/MP integration point.

### HY soil-water workstream

MP needs solver phase boundaries and counters but does not expose `HeadCalc` internal arrays as public contracts. HY owns the solver interface. MP instrumentation should attach to stable solver events or an internal instrumentation adapter.

### TX transactional workstream

MP records checkpoint, retry, rollback and commit cost. It must not alter transaction ordering or keep physical state alive merely for profiling convenience.

### VQ verification workstream

VQ supplies the correctness gate for benchmark runs. MP results are performance evidence only when the corresponding physical run passes the relevant mass-balance and reference qualification checks.

## Invariant review

Affected invariants: **3, 4, 5, 6, 7, 8, 13, 16, 23, 24, 25, 26, 27, 30**.

Expected effect: **strengthens/compliant**. MP-1 adds observability and a benchmark contract without changing physical or numerical behaviour.

Evidence in this slice: architecture and measurement contract only. No production performance claim is qualified yet.

Open risks:

- the final SWAP5 runtime and solver event interfaces are not yet integrated, so instrumentation hooks remain an integration dependency;
- a dedicated qualified B12 benchmark fixture is still missing;
- excessive fine-grained timing can distort small kernels, so instrumentation overhead must be measured before interpreting micro-timings.

## Workstream handoff

```text
WORKSTREAM
MP

BASELINE
40aef01c5c89dc9e02bba50d31c884dcdd2fd2d5

SCOPE
Define the measurement and CPU benchmark architecture for MultiSWAP without changing production physics.

COMPONENTS/FILES TOUCHED
docs/performance/multiswap-measurement-architecture.md
docs/performance/benchmark-record.schema.json
docs/development/workstreams.md
mkdocs.yml

INTERFACES CHANGED
No production kernel, solver, runtime or coupler interface. New benchmark-record contract only.

INVARIANTS AFFECTED
3, 4, 5, 6, 7, 8, 13, 16, 23, 24, 25, 26, 27, 30

TEST/QUALIFICATION STATUS
Documentation/measurement contract defined. Instrumentation implementation and runtime qualification pending.

DEPENDENCIES / REQUIRED INTEGRATION
RT for stable template/execution/batch identifiers; HY for solver phase events; TX for transaction events; VQ for correctness and mass-balance gates.

NEXT SAFE STEP
MP-2: implement the smallest non-invasive CPU measurement collector and aggregator around stable logical events, then qualify measurement-on versus measurement-off equivalence before collecting optimization evidence.
```
