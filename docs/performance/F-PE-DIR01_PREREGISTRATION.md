# F-PE-DIR01 — production bottom-head directional tangent exact-cost reduction

Date: 2026-09-26

Status: `PREREGISTERED_NOT_STARTED`

Predecessor:
`F-PE-PROFILE04 — post-admission end-to-end performance rebaseline`

Canonical production authority at preregistration:
`integration/f-ci-canonical@c52454b31d6f5d6ae6ed6af56460f158ddb45008`

## Motivation

PROFILE04 established that the production Reference / transaction route still dominates repeated application runtime and that the MODFLOW groundwater participant explicitly requests an accepted-trajectory bottom-head response tangent.

On the current canonical postimage, the qualified bottom-head fixture measured:

- Reference median: approximately `8.675 us` per interval;
- directional median: approximately `16.208 us` per interval;
- directional / Reference ratio: `1.8684`;
- directional incremental cost: approximately `+86.8%`.

The physical solve count did not change:
- nonlinear iterations per solve remained `1`;
- constitutive evaluations per solve remained `2`;
- the accepted-trajectory service adds no full nonlinear solve.

The isolated tridiagonal backsolve kernel is only about `46.8 ns` for the four-node production-shaped fixture. Three extra backsolves therefore explain only about `0.14 us`, roughly 2% of the measured directional increment. The dominant directional cost is consequently above the raw backsolve kernel, but PROFILE04 does not assume in advance which higher-level component is responsible.

## Question

Can the production-required accepted-trajectory bottom-head tangent be delivered materially cheaper while preserving exactly the same physical solve, accepted trajectory, derivative semantics and transaction ownership?

## Scope

DIR01 owns only the exact directional path.

Candidate cost components to measure before any repair:
1. directional route eligibility and validation;
2. Reference factorization-capture lifecycle;
3. directional constitutive evaluation;
4. tangent RHS construction;
5. tridiagonal backsolve invocation and surrounding data movement;
6. accepted-step accumulation;
7. result allocation, publication and copying;
8. other demonstrably repeated directional orchestration.

No component is selected as the optimization target until measurement identifies it.

## Hard constraints

- No approximate physics.
- No relaxed tolerances.
- No extra nonlinear solves.
- No change to the accepted physical candidate.
- No change to mass-balance semantics.
- No change to bottom-head control-coordinate meaning.
- No degradation of the default non-directional route.
- No speculative optimization without measured attribution.

Any production edit must be justified by a preregistered measurement finding inside DIR01.

## Measurement authority

Primary performance authority:
- same-postimage, paired Reference versus bottom-head directional timings;
- production-shaped groundwater-participant route where practical;
- replicated timing, not one isolated CI run.

Microbenchmarks may localize cost but may not be added arithmetically to claim end-to-end savings.

## Preservation gates

At minimum:
- identical converged physical state;
- identical accepted-step count and interval completion;
- identical response-tangent availability semantics;
- tangent value agreement at the strictest practical floating-point tolerance supported by the existing qualification fixtures;
- zero additional full nonlinear solves;
- unchanged mass-balance gates;
- unchanged non-directional diagnostics and outputs;
- production matrix coverage for the qualified Reference cases.

## Admission rule

DIR01 may admit an exact optimization only when:
1. a measured directional hotspot is identified;
2. the repair removes or reduces that work without changing model meaning;
3. paired replicated timing shows a stable gain above timing noise;
4. all preservation gates pass.

If the remaining directional overhead proves physically or numerically necessary, DIR01 must close without forcing a repair.

## Strategic handoff

Only after DIR01 closes should the performance program decide whether another exact workunit is justified.

If DIR01 leaves no substantial exact overhead, the next phase should be the separately preregistered practical / approximate MultiSWAP performance program. That approximate phase is explicitly outside DIR01.
