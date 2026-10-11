# MP-2 measurement collector

**Workstream:** MP  
**Baseline:** `5fe6befcd8aba87c22523ec165f1a88f6ffd9027`  
**Status:** PARTIAL  
**Scope:** measurement tooling only; no production SWAP physics or numerical behaviour changed

## Purpose

MP-2 implements the smallest executable measurement layer needed to turn the MP-1 benchmark architecture into reproducible records. The collector is deliberately outside the production kernel. It can be called from future RT, HY and TX observation points without making those components depend on Python or on this specific implementation.

The code lives in `tools/performance/mp_measure.py`. It is a benchmark and qualification tool, not a SWAP kernel API.

## Collector contract

One logical column interval starts with an `IntervalContext`. The context identifies the run, code revision, case, column, model template, physics signature, numerical policy, execution class, discretisation and generic interval `[t0,t1]`. Optional worker and batch identifiers support MultiSWAP analysis.

An enabled recorder can then:

- time one exclusive logical phase at a time;
- increment solver and retry counters;
- record memory observations using the MP-1 categories;
- finish the interval with caller-supplied acceptance and water-balance information;
- emit an `mp-benchmark-record-v1` record compatible with `benchmark-record.schema.json`.

The collector does **not** decide whether the physical interval is accepted. It does **not** compute or relax the water-balance criterion. TX/VQ or another qualified caller supplies those facts.

## Disabled path

`MeasurementCollector(enabled=False)` returns a no-op interval recorder. The disabled recorder:

- does not call the measurement clock;
- stores no records;
- does not inspect or mutate physical inputs or outputs;
- accepts the same observation calls so production hooks need no alternative physical control flow.

This is an important preparation for measuring instrumentation overhead later. MP-2 itself does not yet claim a production overhead number.

## Timing semantics

Timing categories follow MP-1, including constitutive work, residual evaluation, Jacobian build, linear solve, Newton control, process physics, transaction work and runtime/batching.

Within one interval recorder, timed spans are exclusive and may not be nested. This keeps phase totals interpretable as a decomposition rather than a hierarchy with accidental double counting. If later integration requires nested observation, that must be introduced explicitly rather than silently changing the accounting semantics.

The collector uses `time.perf_counter_ns` by default. MP-6 clarified that this is a monotonic **elapsed-time** clock, not process CPU time. Current records therefore carry `timing_clock_kind = monotonic_elapsed`, and aggregate fields use explicit elapsed-time names. Worker-attributed elapsed totals are accounting proxies and must not be interpreted as measured worker CPU utilization.

Actual process CPU time is measured separately by the controlled CPU-baseline tooling introduced in MP-6. Tests may still inject a deterministic clock into the collector.

## Aggregation

`aggregate_records()` produces an initial elapsed-time-oriented summary across interval records:

- interval count and accepted count;
- mass-balance failure count;
- summed measured column-interval elapsed time;
- min, mean, p50, p90, p95, p99 and maximum interval elapsed cost;
- share of total elapsed cost consumed by the slowest 1 percent of intervals;
- phase elapsed totals;
- solver/retry counter totals;
- per-template elapsed distributions;
- per-execution-class elapsed distributions;
- batch divergence as maximum column elapsed cost divided by median column elapsed cost within a batch;
- worker-attributed elapsed totals and maximum-over-mean attributed imbalance.

The JSONL command-line path is intentionally simple:

```bash
python -m tools.performance.mp_measure aggregate records.jsonl
```

These summaries are evidence aids, not optimization gates yet. Thresholds belong in later qualification work after representative reference cases exist.

## Qualification evidence in MP-2

The current unit tests cover:

1. disabled collection performs no clock reads and stores nothing;
2. enabled collection emits the MP-1 record categories;
3. measurement enabled versus disabled leaves a deterministic dummy calculation and its input state unchanged;
4. nested timing spans are rejected so accounting remains exclusive;
5. tail cost, batch divergence and worker-attributed elapsed aggregation are reproducible;
6. records survive JSONL write/read round-trip.

The repository CI compiles the Python tool and runs these tests on Python 3.13.

This is only tooling-level equivalence. It is **not yet** evidence that instrumented SWAP4.3.1 or SWAP5 production execution is bitwise or numerically equivalent with measurement enabled. That requires actual production observation hooks plus VQ physical and mass-balance gates.

## Integration points

### RT

RT should eventually expose stable logical identifiers or events for:

- `template_id`;
- `execution_class`;
- `worker_id`;
- `batch_id`;
- runtime/batching intervals.

MP must consume those observations without taking ownership of scheduling policy.

### HY

HY should provide stable logical observation points for constitutive evaluation, residual evaluation, Jacobian construction, linear solve and Newton control. MP must not depend on `HeadCalc` array names or one Richards implementation's internal layout.

### TX

TX owns retry, timestep-reduction, rollback and commit semantics. MP records their counts and costs but cannot decide whether a retry or trial is accepted.

### VQ

VQ supplies the qualified physical-equivalence and mass-balance acceptance gate. MP performance records from a run that fails VQ remain diagnostic evidence but cannot support a performance qualification claim.

## Invariant review

Affected invariants: **3, 5, 6, 7, 13, 16, 23, 24, 25, 26, 27, 30**.

Expected effect:

- strengthens explicit separation between physical state and measurement scratch;
- provides a worker/batch-compatible observation format without prescribing storage layout;
- keeps physical configuration and numerical execution class distinct;
- makes retries, fallback provenance and cost distributions observable;
- leaves mass conservation and transaction acceptance outside the performance tool.

No architecture invariant is intentionally relaxed.

## Open limitations

MP-2 deliberately does not yet provide:

- production Fortran/C/C++ timing hooks;
- a qualified B12/heavy-clay benchmark fixture;
- actual persistent-state byte accounting from the evolving SWAP5 state types;
- actual worker-scratch byte accounting from the production solver;
- reference, relaxed and fallback cost comparisons;
- instrumentation overhead measurements on SWAP production runs;
- CPU scaling measurements over large homogeneous or mixed batches;
- GPU code or GPU performance claims.

## Next safe step

**MP-3:** connect the collector concept to the first stable production observation seam, preferably one that does not redesign a shared interface. The first production gate should compare measurement disabled and enabled from the same committed state and require identical qualified physical results and water-balance accounting before timing evidence is accepted.
