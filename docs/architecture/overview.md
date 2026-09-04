# Target architecture overview

## Status

This page describes the target modular SWAP architecture. It is not a description of the current SWAP 4.3.1 module graph.

For the evidence-based migration state of each major capability, see the [implementation status map](implementation-status.md). That map is the authoritative place for distinguishing `TARGET`, `PARTIAL`, `IN_PROGRESS` and qualified implementation evidence.

For normative ownership boundaries between API, runtime, coupler, kernel, process physics and the soil-water solver, see the [target component ownership map](component-map.md).

For the file-by-file route from the 63-file SWAP 4.3.1 source baseline into those target responsibilities, see the [legacy-to-target migration map](legacy-migration.md).

## System boundary

SWAP is treated as a computational component that advances one or more soil-plant-atmosphere columns over a generic time interval `[t0, t1]`. The kernel receives typed data and returns typed results. It does not read or write model files.

A useful logical decomposition is:

```text
Application / Python orchestration / MODFLOW coupling
                       |
                 Public SWAP API
                       |
        +--------------+--------------+
        |                             |
  Runtime / coupler                 Adapters
  batching, windows,          legacy files, parsing,
  retry orchestration          serialization, output
        |
        v
+---------------------------------------------------+
|                  SWAP kernel                      |
|                                                   |
|  surface + atmosphere + crop + root uptake       |
|  drainage + optional physics                     |
|  soil-water solver interface                     |
|  transactional step contract                     |
+---------------------------------------------------+
        |
        +--> persistent column state
        +--> shared immutable parameters
        +--> worker-owned scratch
        +--> typed results and diagnostics
```

Optional system components such as a deep-vadose transfer zone remain outside the SWAP kernel. The runtime or coupler decides how components are composed.

## One kernel, several execution contexts

The same kernel supports:

- standalone SWAP;
- many-column MultiSWAP execution;
- Waterwijzer-like applications;
- direct or indirect coupling to groundwater models such as MODFLOW.

These are not separate physics implementations. Differences belong in orchestration, adapters, numerical policy or composition.

## Explicit data ownership

The architecture distinguishes:

- immutable parameters;
- persistent dynamic state;
- forcing over a requested interval;
- numerical configuration and policy;
- results and diagnostics;
- temporary solver scratch.

The separation is important for rollback, cheap reruns, memory scaling and thread-safe execution. See [Data ownership](data-ownership.md).

## Generic time model

The kernel advances over `[t0, t1]`. Calendar days, months and years are not fundamental computational units. Internal solver steps, forcing intervals, coupling windows, events and reporting intervals may all differ.

A calendar boundary is only a hard boundary when a physical process or an external contract requires it.

## Transactional stepping

A trial step never corrupts the last accepted physical state. Each step follows the logical sequence:

```text
checkpoint committed state
        |
        v
trial / retry / alternative step size
        |
   accepted?
    /    \
  yes     no
  |        |
commit   rollback
```

Numerical trial information may be reused as a warm start, but a corrector always represents the correct committed physical starting state.

## MultiSWAP execution

MultiSWAP is a primary execution mode, not a wrapper around hundreds of thousands of heavyweight standalone solver instances.

Columns can be grouped into homogeneous model templates or execution classes. A template may fix model topology, active physical modules, vertical discretization structure, soil-water solver, numerical policy and state layout. Individual columns retain their own parameter references, forcing and dynamic state.

A difficult column may be moved to a relaxed or fallback numerical execution class without silently changing its physical model.

## Groundwater coupling

For direct SWAP-MODFLOW coupling, the intended interface contract is:

```text
H_SWAP = H_MF
q_SWAP = -q_MF
```

Small head residuals are allowed only within a qualified convergence tolerance. Interface flux must remain conservative. Water may not disappear because a coupling iteration or fallback path was used.

The solver should expose interface sensitivities such as `dh_b/dq_b` efficiently, preferably from the same Jacobian or factorization used by the nonlinear solve. Finite-difference perturbation runs remain a reference or fallback mechanism rather than the default production path.

## Alternative soil-water solvers

Other SWAP modules must consume hydraulic information through a clean soil-water interface. They must not depend on internal arrays from one specific `HeadCalc` or Richards implementation.

This keeps room for full Richards, coarse Richards and qualified reduced-order alternatives while preserving shared crop, ET, drainage, irrigation and surface physics.

## Verification consequence

Architecture changes are not complete when they compile. They must be checked against the [core invariants](invariants.md) and the [verification principles](../verification/principles.md), including hard water-balance closure.
