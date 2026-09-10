# F-MR37 — Generic Effective-Forcing Boundary & Parallel DIVDRA Composition Readiness

## Purpose

F-MR37 qualifies the architectural direction required before restricted active DIVDRA may be added to the parallel physical runtime. It does **not** admit parallel DIVDRA execution and does not modify production source.

## Problem reconstructed from current canonical source

The canonical parallel scheduler and worker pool accept `forcing_registry` as read-only shared input. Workers ultimately call `fmr_execute_serialized_physical_column`, which resolves `column%forcing_handle` and passes one selected `fmr_b110_physical_forcing_t` to the physical backend.

The canonically admitted serialized DIVDRA callsite uses a different mechanism: after complete preflight it temporarily materializes `drainage_flux_by_level` in a mutable forcing registry, calls the existing serialized runtime, and removes the temporary row afterwards. This is safe in the qualified serialized scope, but it cannot be copied to the shared read-only parallel forcing registry without either mutating shared data or cloning a much larger forcing registry.

`fmr_b110_physical_forcing_t` contains multiple optional allocatable arrays. Therefore a whole-registry or unconditional whole-forcing deep-copy policy is not admitted as the intended 100k+ column production architecture.

F-MR35 independently demonstrates another route: a distinct root-active parallel pool can duplicate the worker execution path. F-MR37 does not adopt that pattern for DIVDRA because repeating it per optional physical feature would multiply worker-pool implementations and violate the intended single runtime composition architecture.

## Qualified direction

The next structural candidate shall introduce a **generic resolved-column / explicit-effective-forcing execution seam** below registry lookup and above the existing transaction/backend execution path.

The logical split is:

1. registry-facing wrappers validate and resolve template, parameter, forcing and state handles;
2. the shared physical executor receives exactly one resolved parameter object, one explicit effective forcing object and the correct committed state/transaction context;
3. ordinary serialized and parallel V1 callers pass the canonical forcing object unchanged;
4. an optional process composition may construct a worker-local effective forcing object or component overlay and pass that explicit object to the same executor;
5. the physical backend and mass ledger see exactly one forcing object and therefore book each source/sink exactly once.

The exact Fortran procedure names are not frozen by this readiness workunit. The semantic boundary is frozen.

## Effective-forcing ownership and lifetime

An effective forcing is **ephemeral worker/job scratch**. It is not committed column state, not a parameter, and not persisted across accepted windows. Its lifetime is one resolved physical execution attempt unless a later separately qualified optimization safely reuses scratch capacity.

Immutable/base forcing remains owned by the forcing registry. An override must not mutate the base object. Optional override storage is allocated only for active columns/processes and may reuse worker scratch capacity.

For DIVDRA the first qualified override candidate shall be limited to `drainage_flux_by_level`. Other base forcing components must remain observationally identical to the selected canonical forcing. The override must be materialized from the already qualified F-MR33/F-CI33 distribution binding semantics: explicit hydraulic view + immutable distribution parameters + externally supplied positive scalar transfer.

## Transaction contract

All process-specific validation and effective-forcing construction that can fail predictably must occur before checkpoint capture or physical trial. A rejected overlay request must leave committed state, base forcing and result provenance unmodified except for explicit rejection diagnostics.

After the executor begins a physical trial, the existing checkpoint/candidate/commit/discard transaction path remains authoritative and must not be duplicated.

## Mass contract

The effective forcing is a replacement *view of inputs*, not an additional flux ledger. The backend consumes one drainage row and the existing kernel mass accounting books it once. No runtime-side compensating mass term, tolerance relaxation or second drainage booking is permitted.

Mass completeness and zero missing-contribution mask remain hard commit requirements.

## Parallel isolation contract

Each worker may hold its own effective-forcing scratch. No worker writes another worker's effective forcing or the shared base forcing registry. Two columns with distinct forcing handles and/or distinct DIVDRA overrides must not cross-contaminate.

A shared base forcing handle is not inherently forbidden by the generic seam when no conflicting override exists; however the first parallel DIVDRA candidate shall fail closed if two concurrently executable active requests need different overrides for the same shared base handle unless the worker-local explicit-forcing seam makes that independence unambiguous and independently qualified.

## Cost and scaling contract

The intended path must avoid:

- cloning the entire forcing registry per batch or worker;
- cloning all optional forcing arrays for inactive features;
- allocating drainage state on every column;
- one heavy backend/solver instance per logical column;
- a process-specific parallel worker-pool copy for every optional module.

The first structural seam may use a simple explicit object copy only if qualification proves that copying is restricted to the one resolved column and active data, and the follow-up performance work records allocation/copy cost. A full registry deep copy is a hard reject.

## Compatibility contract

The current serialized runtime, parallel V1 runtime and canonically admitted serialized DIVDRA runtime must remain behavior-compatible. A structural refactor must demonstrate exact or qualified-equivalent results for existing admitted paths before parallel DIVDRA is enabled.

Root-active parallel work (F-MR34/F-MR35) is an adjacent workstream. F-MR37 neither supersedes nor canonically admits it. A future unification may route root-active and DIVDRA-active profiles through the same generic resolved-forcing executor, but that requires separate qualification.

## Explicit nonclaims

F-MR37 does not qualify:

- active parallel DIVDRA execution;
- any drainage exchange law;
- fully implicit or trial-state drainage response;
- surface-water-controlled drainage;
- negative/infiltration or multilevel DIVDRA;
- a specific memory optimization or performance target;
- F-MR35 root-active parallel production admission;
- any HeadCalc/Jacobian drainage mutation;
- any production source change.

## Next structural candidate

If F-MR37 closes green, the next candidate should be a separately numbered F-MR workunit implementing only the generic resolved-column / explicit-effective-forcing executor seam. It must first prove ordinary serialized and parallel V1 behavioral preservation with no active DIVDRA. Active parallel DIVDRA should be a subsequent composition workunit, not bundled into the executor refactor.
