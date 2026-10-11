# PPA-WU05-C3A-PERF01 preregistration

Date: 2026-10-02
Baseline: 800f6a9b429ed2a392e4c3778951bb92eca042aa

## Question

Measure the runtime cost of the canonically admitted bounded C3A Bartholomeus oxygen route and determine whether exact-preserving software overhead can be removed without changing its admitted physics or ownership.

## Frozen scope

Only oxygen mode 2/type 1, analytical MvG REFERENCE waterfilm, homogeneous serial Reference execution and the already-admitted C3A equations are in scope. No tolerance relaxation, approximate oxygen mode, lookup surrogate, solver-ABI change, state ownership change, restart change or water-ledger change is allowed.

## Measurements

Benchmark the current C3A implementation with repeated evaluations after warm-up. Report wall/CPU time per evaluation and, separately where practical, factor-provider/kernel cost. Use deterministic fixed physical inputs including no-stress, intermediate-stress, full-stress and multi-node vertical propagation cases already represented by the B1.11 oracle.

Timing loops must accumulate outputs so the compiler cannot eliminate the work. Compare like-for-like optimized builds and repeat enough work for stable timing. Runtime ratios are evidence only when repeated measurements agree materially.

## Falsification and preservation

Every optimization must preserve:
- existing C3A application and B1.11 assembled-oracle gates;
- maximum RWU difference <= 1e-4 versus unchanged corrected B1.11 source;
- existing C3A output identity where the current tests require exact replay/O0-O2 identity;
- OFF exact preservation;
- reject/replay/restart and one-water-owner semantics;
- fail-closed unsupported routes.

No optimization is accepted merely because it benchmarks faster.

## Candidate zero-waste targets

1. repeated allocatable scratch creation in runtime view, waterfilm, response-input and factor arrays;
2. redundant validation along the already-validated production call chain;
3. repeated MACRO evaluation after the scalar respiration solve when an exactly equivalent returned value can be reused;
4. avoidable whole-array copies or temporaries.

These are hypotheses, not findings. Profiling/benchmark evidence decides priority.

## Exit

Persist baseline timings, candidate timings, compiler/environment identity, physical preservation results and a conclusion distinguishing measured speedup from architectural cleanliness.
