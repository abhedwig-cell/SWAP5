# ADR-0004: MultiSWAP execution templates

**Status:** Accepted  
**Date:** 2026-09-04  
**Affected invariants:** 6, 16, 23, 24, 25, 26, 27

## Context

High-throughput MultiSWAP benefits from homogeneous batches because model topology, active modules, discretization and solver paths determine memory layout, branch behaviour, vectorization potential and runtime predictability.

Forcing every column through one maximally general layout wastes memory and computation. Forcing physically different columns into one homogeneous path would be incorrect.

## Decision

The runtime may define a limited number of model templates or execution classes. A template can fix:

- active physical modules;
- vertical discretization structure;
- soil-water solver implementation;
- numerical policy;
- persistent state layout;
- compatible worker scratch layout.

Columns within a template retain individual parameter references, forcing and dynamic state.

If a column requires different physics, it moves to a different template. If it is numerically difficult, it may move to a relaxed or fallback execution class without silently changing physical configuration.

## Consequences

Positive consequences:

- homogeneous memory access and solver paths;
- better cache use and opportunities for SIMD or GPU execution;
- bounded-cost handling of difficult columns;
- optional functionality costs only the columns that use it.

Costs and constraints:

- runtime must classify columns and manage multiple queues;
- template count must remain controlled;
- migration between numerical classes requires diagnostics.

## Verification implications

A column moved between numerical execution classes must remain physically equivalent within the qualification envelope. Reference mode remains the authority for qualification, and every fallback path must preserve water balance.
