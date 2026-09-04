# Target component ownership map

**Status:** target architecture contract  
**Snapshot:** 2026-09-04

This page defines the target component boundaries for SWAP5. It complements the [implementation status map](implementation-status.md): this page says **where responsibilities belong**, while the status map says **how far the migration has progressed**.

!!! warning "Not a legacy module map"
    These components are architectural responsibilities, not proposed one-to-one replacements for SWAP 4.3.1 Fortran files. A legacy routine may be split across several target components, and several legacy routines may contribute to one target component.

## Governing ownership rule

A component may use data without owning it. SWAP5 keeps five ownership questions separate:

1. who defines the physical or numerical behaviour;
2. who owns committed persistent state;
3. who owns immutable parameters;
4. who owns temporary solver scratch;
5. who controls system composition and execution policy.

The target answer is deliberately asymmetric:

- committed physical state belongs to the column-state domain and changes only through transaction commit;
- immutable parameter sets are shared and referenced;
- worker scratch belongs to workers/jobs, not columns;
- execution policy belongs to runtime/templates, not physical process modules;
- system composition belongs to runtime/coupler, not the SWAP kernel.

See [Data ownership](data-ownership.md) for the data categories themselves.

## Logical system decomposition

```text
Application / Python orchestration / groundwater model
                         |
                         v
                  +--------------+
                  |  Public API  |
                  +------+-------+
                         |
          +--------------+----------------+
          |                               |
          v                               v
+-------------------+              +--------------+
| Runtime / executor|              |   Adapters   |
| templates, batch, |              | legacy I/O,  |
| policy, workers   |              | serialization|
+---------+---------+              +--------------+
          |
          +--------------------+
          |                    |
          v                    v
+-------------------+   +-------------------+
|      Coupler      |   |  SWAP kernel      |
| windows, tiles,   |   | interval trial    |
| interface residual|   | over [t0,t1]      |
+---------+---------+   +---------+---------+
          |                       |
          |               +-------+-------------------------------+
          |               |       |              |                 |
          |               v       v              v                 v
          |          Surface /  Crop / ET   Drainage /       Soil-water
          |          atmosphere root uptake optional physics solver API
          |                                                   |
          |                                                   v
          |                                           solver implementation
          |
          +--> optional external deep-vadose transfer component

Cross-cutting data domains:
  shared immutable parameters
  committed column state
  forcing
  numerical configuration
  worker scratch
  typed results and diagnostics
```

## Component ownership matrix

| Component | Owns | Must not own | Persistent state | Scratch | Primary contracts | Invariants |
| --- | --- | --- | --- | --- | --- | --- |
| **Public API** | Versioned typed request/response contracts; stable entry points for standalone, MultiSWAP and coupling use | File formats, paths, solver internals, MODFLOW cell composition, hidden global state | None | None | `advance`, trial/commit-facing contracts, result/diagnostic types, capability queries | 1, 2, 3, 11, 29 |
| **Legacy and external adapters** | Parsing, validation, unit/format translation, serialization, legacy file compatibility | Physical equations, solver policy, committed model state, coupling logic | None beyond adapter/session bookkeeping | Parsing/serialization buffers only | File/input model → typed API data; typed results → legacy/external output | 2, 21, 29 |
| **Runtime / execution manager** | Model-template registry, column batching, execution classes, worker scheduling, retry policy, resource pools, execution diagnostics | Physical constitutive laws, hidden changes to physics, solver-specific internal arrays, MODFLOW physics | Manages references to committed column state and shared parameters; does not redefine their semantics | Owns/reuses worker scratch pools | template selection, batch execution, retry/fallback routing, commit coordination | 4, 5, 6, 7, 16, 23, 24, 26, 27 |
| **Coupler** | Coupling windows, predictor/corrector orchestration, interface residuals, tile fractions, area-weighted aggregation, external component composition | Soil/crop equations, SWAP solver internals, persistent SWAP state, file I/O | Coupler bookkeeping only; external coupled components may have their own state | Coupling iteration scratch | head/flux exchange, residual evaluation, response tangents, conservative aggregation | 10, 11, 12, 13, 14, 15, 17, 28 |
| **Kernel interval executor** | Deterministic physical trial over `[t0,t1]`; ordering/composition of SWAP physical processes inside one column trial; construction of a trial result | Files, paths, calendar-day assumptions, worker scheduling, MODFLOW tile fractions, persistent mutation of committed state | None internally authoritative; receives a committed starting state and proposes an endpoint | Uses caller/worker-provided scratch through subcomponents | `trial(state0, parameters, forcing, numerics, t0, t1) -> TrialResult` | 1, 2, 3, 7, 8, 9, 13, 21, 29 |
| **Surface and atmospheric boundary physics** | Surface storage/infiltration boundary physics, precipitation/evaporation boundary terms, ponding-related process equations | Calendar scheduling, file input, groundwater-cell composition, Newton arrays | Only physically necessary surface state through the column-state domain | Local temporary process values | surface boundary request/response used by kernel and soil-water interface | 3, 4, 9, 13, 21, 27 |
| **Crop, ET and root-uptake physics** | Crop development where active, potential/actual ET partitioning, root uptake and stress physics | `HeadCalc` arrays, soil-water Jacobian internals, execution policy, file formats | Only active crop/plant physical state through the column-state domain | Temporary canopy/root/stress intermediates | hydraulic query/view + meteorological forcing → sink/source terms and diagnostics | 3, 4, 21, 22, 23, 27 |
| **Drainage, irrigation and optional process physics** | Their own physical flux laws and optional-module state | Solver policy, worker scheduling, direct access to soil-water implementation arrays, unrelated optional-module state | Only state required by each active option | Module-local temporaries | clean hydraulic/process interfaces → flux/source contributions | 3, 4, 21, 22, 23, 27 |
| **Soil-water solver interface** | Solver-independent hydraulic contract used by the kernel and other physics; required endpoint, flux, convergence and sensitivity outputs | One implementation's array layout, file I/O, runtime batching, crop/drainage policy | None by itself | Defines scratch requirements abstractly, not per-column storage | advance/solve trial, hydraulic queries, bottom interface flux/head, tangent output | 14, 20, 21, 22, 25 |
| **Soil-water solver implementation** | Numerical discretisation and nonlinear solve for one solver family; Jacobian/factorisation; constitutive evaluation needed by that solve | Ownership of committed column state, runtime retry policy, external coupling composition, other modules' physics | No permanent solver state unless it is physically required state represented through the common column-state contract | Newton vectors, residuals, Jacobians, factorisations, constitutive intermediates, warm-start numerics | implements soil-water interface; emits solver-attempt status and qualified sensitivities | 5, 7, 8, 14, 20, 22, 23, 24, 25 |
| **Results and diagnostics assembly** | Typed physical results, water-balance terms, solver cost, retries, execution mode, fallback provenance, coupling diagnostics | Changing physics, mutating committed state, hiding failed/rejected trials | None as model state; retained output is caller/runtime responsibility | Aggregation buffers only | kernel/runtime/coupler events → stable result and diagnostic schema | 13, 24, 26 |
| **Optional deep-vadose transfer component** | Its own mass-conserving transfer law and minimal storage such as `S`; groundwater-delivery flux | SWAP soil profile physics, SWAP state, implicit interpretation of every SWAP bottom flux as recharge | Its own explicit transfer storage only when active | Minimal local temporaries | `q_SWAP,bot` → transfer state update → `q_gw`; transition/hand-off contract | 18, 19, 28 |

## Cross-cutting data domains

The table above intentionally does not turn every data category into a software component. The following are logical ownership domains that implementations may realise with objects, structures of arrays, pools or batches.

### Shared immutable parameter domain

Contains soil, crop, drainage and other immutable or effectively immutable parameter sets. Columns reference these by ID or handle where practical.

**Managed by:** runtime/model registry.  
**Consumed by:** kernel and physical modules.  
**Forbidden:** per-column duplication solely for convenience when the data are identical.

### Committed column-state domain

Contains only the physical information required to continue a column. The state is authoritative at a transaction boundary.

**Managed by:** runtime/column store.  
**Read by:** kernel trial execution.  
**Changed by:** explicit commit of an accepted trial result.  
**Forbidden:** direct mutation by rejected trials, solver scratch, diagnostics or coupler iterations.

### Forcing domain

Contains interval-specific atmospheric, management and imposed-boundary information.

**Owned by:** caller/runtime for the requested interval.  
**Consumed by:** kernel/process modules.  
**Forbidden:** hidden reads from files or global calendars inside the kernel.

### Numerical configuration domain

Contains tolerances, timestep/retry policy, reference/balanced/throughput policy and solver selection where that selection is numerical rather than physical.

**Owned by:** execution template/runtime policy.  
**Consumed by:** kernel/solver through explicit arguments.  
**Forbidden:** silently altering physical module activation or physical parameters.

### Worker-scratch domain

Contains transient Newton, Jacobian, factorisation and constitutive work data.

**Owned by:** worker/job resource pool.  
**Borrowed by:** solver implementation during a trial.  
**Forbidden:** permanent allocation per logical column unless the quantity is true physical state.

## Transaction boundary

The component map makes the transaction boundary explicit:

```text
committed column state
        |
        | read-only physical starting point
        v
runtime selects policy / worker
        |
        v
kernel trial [t0,t1]
        |
        +--> physical modules
        +--> soil-water solver using worker scratch
        |
        v
TrialResult(endpoint, fluxes, diagnostics, sensitivities, attempt status)
        |
   accepted by policy?
      /        \
    yes         no
     |           |
   commit      discard physical endpoint
     |           |
     v           +--> optional numerical warm-start data may be retained
new committed state
```

The runtime may choose retries, smaller steps or a different qualified numerical execution class. It may **not** change the physical model silently. A rejected trial never becomes physical history.

## Coupling boundary

The coupler operates outside the SWAP kernel. For a direct groundwater coupling window it may:

1. select one or more surface tiles and their area fractions;
2. request predictor trials from SWAP columns;
3. exchange head/flux information with the groundwater model;
4. evaluate `H_SWAP - H_MF` and `q_SWAP + q_MF`;
5. use qualified response tangents when available;
6. request corrector/retry trials from the same committed starting state;
7. commit accepted component states only when the coupled window is accepted;
8. aggregate tile fluxes conservatively.

The SWAP kernel therefore never needs to know what fraction of a MODFLOW cell a column represents.

## Hydraulic information boundary

Other physical modules must not know the internal representation of `HeadCalc` or any future Richards solver. They receive hydraulic information through a solver-independent view or query contract.

Typical information may include:

- pressure head or water content at defined locations;
- hydraulic conductivity or capacity when physically required;
- root-zone hydraulic quantities needed by uptake/stress physics;
- drainage-relevant hydraulic values;
- bottom head/flux information;
- accepted endpoint fields needed for results.

This contract should expose physical meaning, not implementation arrays.

## Optionality rule

An optional component or physical module has three consequences only when active:

1. its immutable parameters are referenced;
2. its physically necessary state is present;
3. its compute path and scratch requirements are scheduled.

Inactive macropore, special drainage, deep-vadose or heavy crop functionality must not impose the same persistent memory and execution cost on every MultiSWAP column.

## Component-boundary review questions

Every material architecture change should be checked with these questions:

1. Which component owns this behaviour?
2. Which component owns the affected physical state?
3. Is any temporary numerical data being moved into persistent column state?
4. Does the change introduce a file, calendar, path or MODFLOW assumption into the kernel?
5. Does another physics module now depend on solver internals?
6. Can runtime policy change physics silently?
7. Can a rejected trial mutate committed state or mass accounting?
8. Does optional functionality allocate state or scratch when inactive?
9. Is a new coupling responsibility accidentally being placed inside SWAP?
10. Which core invariants and verification gates prove that the boundary remains valid?

## Relationship to implementation status

This page is normative target architecture. It does **not** claim that every boundary already exists in production code. Current migration progress remains authoritative in the [implementation status map](implementation-status.md).

The next migration-oriented mapping step should connect legacy SWAP 4.3.1 modules and active refactoring units to these target components without assuming one-to-one correspondence.
