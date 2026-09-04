# ADR-0001: One kernel, I/O outside

**Status:** Accepted  
**Date:** 2026-09-04  
**Affected invariants:** 1, 2, 16, 21, 28, 29

## Context

Legacy SWAP is distributed and invoked as a file-oriented model. The new architecture must also support MultiSWAP and coupled use without creating separate physics implementations for each application.

Embedding parsing, filenames, file units or output formatting in the computational kernel would make reuse, testing and in-memory coupling harder. Maintaining separate kernels would create divergence in physical behaviour and verification.

## Decision

Maintain one SWAP computational kernel. It accepts typed parameters, state, forcing and numerical configuration and returns typed results.

All file-oriented functionality, including legacy `.swp` inputs and traditional output formats, remains outside the kernel in adapters or translation layers.

Standalone execution, MultiSWAP and coupled execution invoke the same kernel through different runtime or application layers.

## Consequences

Positive consequences:

- one physical implementation to verify;
- in-memory coupling without temporary files;
- easier unit and regression testing;
- legacy compatibility can evolve independently from kernel internals.

Costs and constraints:

- legacy global state and I/O calls must be disentangled incrementally;
- adapter contracts become explicit software components;
- not all existing routines can move into the kernel unchanged.

## Verification implications

Standalone adapter execution and direct in-memory execution must be compared on qualified reference cases. Differences caused only by the route into the kernel are defects, not separate model behaviour.
