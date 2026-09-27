# F-PE-REPRO02 R7 — serialized versus direct solver-request identity

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

R1-R6 localize the difficult-origin divergence above the direct Reference physical-solver entry.

Excluded as causes:

- temporal acceptance;
- nonlinear iteration and backtracking caps;
- minimum-step duration;
- serialized legacy-context binding itself;
- inactive boundary carrier values;
- optional accepted-direction processing.

The direct physical request converges for all six difficult origins at +/-0.001 cm. The serialized participant route fails for 11 of 12 signed nonzero points.

## Question

Does the serialized backend present a solver request that differs from the successful direct P0 request before the first physical solve?

## Method

Use test-only instrumentation only. Do not modify production `src/**`.

For the six difficult PROFILE06 origins and offsets -0.001, 0 and +0.001 cm:

1. capture the direct P0 request immediately before the physical solve;
2. capture the serialized Reference request immediately before its physical solve;
3. compare all solver-relevant request fields and provider-backed inputs.

At minimum compare:

- step duration;
- active node count;
- z, dz and node-distance arrays;
- pressure-head and water-content base state;
- ponding depth and groundwater level;
- top/bottom modes and all boundary carrier values;
- max iterations, max backtracking, conductivity mode/mean method, min step;
- all balance/head/ponding tolerances;
- physical macropore flag;
- source/sink arrays presented by the bound provider;
- constitutive values theta, K, C and dK/dh evaluated at the identical base-state heads;
- top-boundary provider result at the identical request state where queryable.

Use the first serialized attempt at the full 1e-4 day interval as the primary identity comparison. Transaction retries are downstream and must not obscure an initial request difference.

## Interpretation

- If a request/input difference is found and explains convergence divergence, localize it before any repair.
- If all compared physical request fields and provider evaluations are bit-identical, advance to workspace/state-history contamination or hidden legacy-global comparison.
- No production repair is allowed in R7.

## Closure gate

R7 passes as a diagnostic when it produces deterministic field-by-field direct/serialized comparisons for all 18 points and identifies either:

- the first material request divergence, or
- verified identity across the measured request surface.
