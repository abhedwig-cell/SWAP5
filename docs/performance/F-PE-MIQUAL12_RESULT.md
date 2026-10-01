# F-PE-MIQUAL12 result — serialized manager component-cost attribution

Date: 2026-10-01

Status:

`QUALIFIED_MIQUAL12_DISTRIBUTED_ADAPTER_OVERHEAD`

Qualification authority:

- workflow run: `36828566685`;
- job: `110259691430`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@7db09b56deb99decf32f47d2deed72710a04e8b5`

## Profiling workload

The frozen MIQUAL09 equilibrium workload was reused:

- 40,000 external committed intervals;
- external full-half transaction;
- 120,000 moving-interface adapter solve calls;
- N=16 full accepted state;
- n=13 reduced solve;
- 100% reduced routing;
- zero fallback/bypass;
- exact final physical state.

MIQUAL12 instrumentation is diagnostic-only and intentionally perturbs the hot path. Absolute total runtime is therefore not compared with MIQUAL09.

## Component CPU attribution

Cumulative CPU time over 120,000 manager solve calls:

- eligibility + saturated-tail discovery: 0.105323 s;
- reduced-request preparation/base-state slicing: 0.092600 s;
- reduced provider preparation/binding: 0.093745 s;
- reduced nonlinear solve: 0.598915 s;
- tail reconstruction + full rematerialization: 0.111259 s;
- finalization + selected-result publication: 0.102607 s.

Attributed total:

`1.104449 s`

Attributed non-solver adapter CPU:

`0.505534 s`

The reduced solve accounts for about 54.2% of attributed adapter CPU.

The five non-solver phases account for approximately:

- eligibility/tail: 20.8% of non-solver adapter CPU;
- reduced request: 18.3%;
- provider prepare: 18.5%;
- reconstruct/materialize: 22.0%;
- finalize/publish: 20.3%.

No single non-solver phase is clearly dominant.

## Interpretation

The remaining production-shaped manager overhead is distributed across the adapter composition path rather than being controlled by one residual hotspot.

This explains why MIQUAL10 and MIQUAL11 each recovered only part of the original penalty.

A sequence of isolated micro-optimizations is therefore unlikely to be the shortest route to net speedup. The next candidate should reduce repeated composition overhead as a group while preserving the same manager semantics.

The profiling calls themselves add substantial overhead, so their absolute timings must not be used as a speed benchmark. Only the phase attribution within this instrumented run is qualified.

## Classification

`QUALIFIED_MIQUAL12_DISTRIBUTED_ADAPTER_OVERHEAD`

## Consequence

Open a separately preregistered fused zero-waste runtime candidate that targets the measured distributed composition class as a whole.

Candidate scope may combine:

- persistent reduced request/view metadata;
- persistent provider bindings where shape/parameter identity is unchanged;
- direct full-candidate population without redundant intermediate copies;
- reduced repeated diagnostic/result copying.

It may not change:

- moving-interface physics;
- accepted-state authority;
- reconstruction equations;
- eligibility envelope;
- fallback/bypass semantics;
- numerical tolerances.

The unchanged MIQUAL06 gate and MIQUAL09 paired benchmark remain the qualification authority.

## Production boundary

MIQUAL12 instrumentation is diagnostic-only and not admission-ready.

`LEGACY_NUMERICS` remains production default.
