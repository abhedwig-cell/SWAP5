# F-PE18 — Current Richards workspace lifetime measurement

Date: 2026-09-16

Status: `RECONCILE_COMPLETE_MEASUREMENT_PENDING`

## Scope

F-PE18 follows F-PE17 and addresses one new current-SWAP5 performance question only:

**Does the admitted typed Richards execution route recreate allocatable reference-workspace storage per solve even though the workspace type itself supports exact-shape reuse, and is that overhead material enough to justify a separately qualified lifetime change?**

Protocol:

`RECONCILE -> MEASURE -> CLASSIFY -> IMPLEMENT_IF_JUSTIFIED -> QUALIFY -> CLOSE`

This is a current-code measurement and decision workunit. It is not an S11 port.

Explicit exclusions:

- no Energy Balance work;
- no RossFast work;
- no new Richards physics;
- no solver-tolerance change;
- no mass-policy or transaction-policy change;
- no hidden shared mutable scratch;
- no persistent per-column physical state;
- no worker-lifetime change before baseline measurement;
- no speedup claim from static inspection alone;
- no whole-model or MultiSWAP speedup claim unless directly measured in that path.

## Live authority

Branch created from current canonical:

- canonical branch: `integration/f-ci-canonical`;
- canonical commit: `8f592dcc1651913b2b24356fd6379e7fafa817a4`;
- canonical tree: `199824d7bb7388718674e4898e1aa45ea6d56c31`;
- current canonical successor is documentation-only F-PE13 preservation relative to the preceding scientific source surface;
- Status-A authority remains `992a5c657bfe10a10100f92e0cb77c4825ae65b6`;
- scientific production baseline remains `50346642bd565f79134ea17d5462e544b354998c`.

Work branch:

`work/f-pe18-richards-workspace-lifetime-measurement`

## Why this is not duplicate work

### F-PE08

F-PE08 qualified removal of duplicated A23BU HeadCalc scratch from the canonical reference-workspace route. It reduced a known worker payload while preserving the F-MR20 v1 scientific matrix. It did not establish the lifetime of `reference_richards_legacy_workspace_t` across typed task-2 solves.

### F-PE09

F-PE09 qualified exact-shape reuse of worker parameter and forcing storage and reported runner-bound paired timing improvement within its frozen scope. It did not qualify persistence/reuse of the Richards/Newton workspace itself.

### F-PE17

F-PE17 established that the historical S11 ownership architecture is already conceptually superseded by current SWAP5: solver history and active-sized numerical workspace are explicitly separated. F-PE17 explicitly left **current workspace allocation lifetime and reuse** as the next performance decision surface.

Therefore F-PE18 is a new bounded decision surface rather than a reopened historical workunit.

## Static current-code finding

### Workspace type supports reuse

Current source:

`src/solver/mod_reference_richards_workspace.f90`

Current blob at F-PE18 start:

`74f99556005ae39614f9df678467b1e19097bae2`

`initialize_reference_workspace(workspace, active_nodes)` only releases and reallocates its allocatable payload when:

```fortran
workspace%active_nodes /= active_nodes .or. .not. allocated(workspace%residual)
```

With a surviving same-shape workspace object, repeated initialization therefore reuses allocated storage and performs reset only.

The workspace owns 24 allocatable arrays. For ordinary compact `tridag_gamma(n)` storage its payload accounting is:

```text
real elements    = 23*n + 2
integer elements = n
logical elements = 2*n + 3
```

The source already exposes `reference_workspace_payload_bytes()`.

### Current typed task-2 lifetime is call-local

Current typed adapter:

`src/adapter/mod_b110_production_soil_water_task2.f90`

The admitted task-2 routine declares:

```fortran
type(reference_richards_legacy_workspace_t) :: workspace
```

as a local automatic object and passes it to the solver for that invocation.

`reference_richards_legacy_workspace_t` contains:

```fortran
type(reference_richards_workspace_t) :: richards
type(a23bu_worker_context_t) :: legacy_worker
```

Current binding source:

`src/adapter/mod_reference_richards_legacy_binding.f90`

Within each solve it calls:

```fortran
call initialize_reference_workspace(ws%richards, n)
call reset_reference_workspace(ws%richards)
```

Because the containing adapter workspace is call-local, its allocatable components do not survive the task-2 procedure return. The reuse capability inside `initialize_reference_workspace` therefore cannot span successive admitted task-2 calls on the current route.

This is a static hotspot finding only. It does **not** yet establish material runtime cost or justify changing ownership.

### Sensitivity-specific resizing

For the prescribed-qbot sensitivity route, current code may temporarily expand `tridag_gamma` from `n` to `2*n` and later compact it back to `n` in the same solve. This creates an additional allocation/deallocation opportunity that should be measured separately from ordinary workspace lifetime.

F-PE18 will not conflate the normal-route lifetime question with sensitivity-specific factorization capture.

## Measurement contract

Before any production mutation, F-PE18 must establish reproducible current measurements for at least:

1. **workspace micro-cost**, comparing fresh call-local construction against same-shape persistent reuse using the production workspace routines;
2. **admitted solver-path cost**, if an existing source-bound solver fixture can exercise equivalent fresh-versus-reused workspace ownership without changing physics;
3. ordinary route separately from sensitivity-capture where practical.

Record, as applicable:

- compiler and flags;
- runner/hardware metadata;
- active node count;
- repetitions and warmup policy;
- wall time;
- CPU time where practical;
- workspace payload bytes;
- number of initialization cycles;
- allocation/reallocation event count where directly observable or source-bound count where not;
- solver iterations/calls for full-path measurements;
- scientific output/checksum and mass result for full-path measurements;
- variation across repetitions.

Timing must use paired A/B ordering or A/B/A where practical. Performance measurement follows scientific equivalence for any executable full-path candidate.

## Classification gate

F-PE18 must end the MEASURE phase in one of these states:

- `NO_MATERIAL_HOTSPOT`: lifetime overhead is too small or irrelevant in representative admitted execution;
- `B_EXACT_LIFETIME_CANDIDATE`: measurable avoidable overhead exists and a worker/job-owned reuse change can preserve exact semantics without broadening ownership;
- `MEASUREMENT_INCONCLUSIVE`: available runner/fixture cannot support the claim;
- `SEPARATE_SURFACE_REQUIRED`: the apparent cost is actually dominated by request/provider materialization or sensitivity-specific resizing and needs another bounded decision surface.

No implementation is allowed merely because static source inspection found fresh allocation.

## Next permitted action

1. Recover existing current solver/performance fixtures that instantiate `reference_richards_legacy_workspace_t` or exercise the admitted typed task-2 route.
2. Prefer reusing those fixtures over constructing a new scientific case.
3. Add measurement-only harness code if necessary; do not modify production source during MEASURE.
4. Persist measured evidence before deciding whether IMPLEMENT is permitted.
