# Restart v1

Restart v1 is the admitted SWAP5 persistence capability for reconstructing the **committed execution state** required for qualified continuation. It is part of the Status-A denominator, but its claim is deliberately narrower than “serialize everything in memory”.

This page describes the frozen Restart-v1 implementation in scientific production baseline `50346642bd565f79134ea17d5462e544b354998c`. It documents the already-qualified contract; it does not define a new persistence format or extend restart semantics.

## Ownership rule

Restart authority follows transaction ownership:

- committed state is persistent authority;
- a checkpoint is captured from committed state;
- candidate state belongs to an active attempt until it is explicitly committed;
- a rejected candidate is discarded rather than promoted to persistence authority;
- solver/Newton/Jacobian scratch and worker warm starts are disposable unless a separately admitted continuation contract says otherwise.

The frozen checkpoint orchestrator makes that split explicit: `fmr_capture_checkpoint` captures a `kernel_checkpoint_t` from `kernel_committed_state_t`; a trial returns a separate `kernel_candidate_state_t`; the candidate is then either committed or discarded.

A restart point therefore represents an accepted continuation boundary, not an arbitrary in-memory instant.

## Two persistence layers

Restart v1 has two typed layers.

### Kernel committed-state persistence

`mod_kernel_committed_persistence` owns a serialization-neutral `kernel_persistence_snapshot_t`. The carrier contains an opaque deep copy of the already-committed state plus:

- state-layout identity;
- kernel persistence schema version;
- committed provenance carried by the opaque committed state, including lineage and revision;
- committed-time binding and the committed time when bound;
- the typed physical continuation state.

For the frozen baseline, `KERNEL_PERSISTENCE_SCHEMA_VERSION = 1`.

The kernel carrier deliberately defines **no file path, byte format or parser**. A trusted adapter may reconstruct a fully decoded typed snapshot, but the kernel persistence module itself performs no I/O and exposes no independent setter for lineage, revision or committed time.

Restore into the kernel is creation of a committed runtime object, not rollback over an existing authority. An already initialized committed target is rejected. Schema and state-layout identity must match, and the reconstructed candidate must preserve its provenance/time invariants before publication.

### FMR Restart-v1 record and bundle

`mod_fmr_committed_restart` exposes the adapter-facing decoded continuation record. It is also serialization-neutral: it is a typed representation that an external adapter may encode or decode, not a byte-level persistence standard.

For the frozen baseline, `FMR_RESTART_SCHEMA_VERSION = 2`.

A restart **bundle** contains:

| Field | Meaning |
| --- | --- |
| `schema_version` | FMR restart schema identity. |
| `parameter_set_identity` | Stable identity of the externally reconstructed immutable parameter registry. |
| `records(:)` | One decoded committed restart record per logical column. |

Each per-column **record** contains:

| Field | Meaning |
| --- | --- |
| `schema_version` | FMR record schema identity. |
| `kernel_schema_version` | Kernel persistence schema expected by reconstruction. |
| `column_id` | Stable logical-column identity. |
| `parameter_ref` | Reference into the externally reconstructed immutable parameter registry. |
| `template_identity` | Full runtime template identity governing compatible state topology. |
| `lineage_id` | Committed transaction lineage provenance. |
| `revision` | Committed-state revision. |
| `committed_time` | Committed model time when time is bound. |
| `time_bound` | Whether committed time is authoritative for the record. |
| `physical_state` | Typed committed physical continuation state. |

The template comparison is not just a single template number. Frozen Restart v1 compares `template_id`, physics topology, vertical layout, state layout, solver interface, optional-state layout, numerical-continuation layout and compatible backend identity.

## What is deliberately not embedded

The restart record does **not** embed:

- the immutable parameter payload itself;
- forcing;
- solver/Newton/Jacobian scratch;
- disposable worker warm starts.

Immutable parameters remain shared runtime configuration. `parameter_set_identity` and each `parameter_ref` bind the decoded restart records to the externally reconstructed parameter registry instead of duplicating immutable parameter data per column.

Forcing is likewise outside the restart record. Qualified continuation therefore requires the surrounding application/runtime to reconstruct the appropriate forcing/configuration context consistently; the restart payload alone does not claim to recreate an entire application environment.

This omission is intentional. It separates committed continuation state from immutable configuration and disposable execution scratch.

## Export path

`fmr_export_committed_restart` constructs a candidate record set and publishes the bundle only after the complete registry passes its checks.

For every logical column, the frozen path requires, among other structural conditions:

1. a positive bundle-level parameter-set identity;
2. a valid one-to-one column/state registry structure;
3. a matching registered template;
4. a positive `parameter_ref`;
5. backend identity compatible with that template;
6. a **ready committed state**;
7. successful kernel committed-state export;
8. consistent committed-time availability and `time_bound` provenance;
9. an available typed physical continuation state;
10. physical-state topology compatible with the template.

If any record fails, the export does not become a successful Restart-v1 bundle. The code builds `candidate_records` first and only moves them into the bundle after all columns pass.

## Restore path and fail-closed gates

`fmr_restore_committed_restart` restores only into a fresh, uninitialized runtime state registry. It first builds candidate committed states and publishes them to the target registry only after **every** record succeeds.

The frozen restore path rejects, among other cases:

- FMR or kernel schema mismatch;
- missing or mismatching `parameter_set_identity`;
- absent or structurally invalid records;
- duplicate/non-positive column identities;
- an already initialized target state registry;
- a column with no corresponding record;
- template-identity mismatch;
- backend/template mismatch;
- `parameter_ref` mismatch;
- absent physical continuation state;
- physical-state topology incompatible with the template;
- failure of trusted kernel persistence reconstruction;
- failure of kernel committed-state restore or its provenance/layout checks.

Only after the complete candidate registry succeeds does the runtime execute whole-registry assignment to `state_registry`. This is the Restart-v1 atomic-publication boundary: a failed later record cannot leave an earlier record partially published into the authoritative target registry.

## Registered state families

`mod_fmr_restart_state_contract` constrains which typed physical states may be reconstructed for a template. Unknown backends and unknown continuation layouts fail closed rather than being inferred from payload contents.

For the frozen serialized-reference backend, the registered Restart-v1 surface includes the admitted combinations of:

- base physical state;
- restricted Snow optional state;
- restricted soil-temperature optional state;
- Richards temporal-history continuation state where that numerical-continuation layout is selected;
- the restricted fixed-weir surface-water state as its own optional-state topology.

The fixed-weir topology is deliberately separate and is not combined with Richards temporal continuation in this frozen candidate. Optional-state compatibility is checked against the template rather than accepted merely because a decoded polymorphic object exists.

This list is a frozen compatibility surface, not a promise that every future physical-state type automatically becomes restart-safe.

## Relation to transactions and retries

Restart and retry use related ownership concepts but are not the same operation.

Within an interval, the transaction layer may capture a checkpoint, run one or more candidate attempts, commit an accepted candidate, or discard a rejected one. Restart persistence operates on the **committed** side of that boundary. Consequently:

- a failed trial cannot become a restart point merely because it produced a candidate state;
- retry from a checkpoint does not mutate committed restart authority until a candidate is accepted and committed;
- restoring a Restart-v1 bundle creates fresh committed carriers rather than overwriting an already authoritative committed runtime state.

This is the key reason restart exactness is an ownership property as well as a serialization property.

## Qualification and preservation

The completion authority is F-KT16 at `37a91f16078badaa675235f1230d225a21c9e010`, with decision `QUALIFIED_STATE_PERSISTENCE_RESTART_V1_100_PERCENT_COMPLETE`. Its exact-head final qualification records run `34746928353`, job `103696445028`, conclusion `success`, including the independent restart-chain, process-state-completeness, state-ownership/schema-structure and canonical-preservation gates.

The permanent testbank subsequently adopts that authority under stable ID `FTB11-RST-001`. That historical testbank record is snapshot-bound; it is not silently rebound to later heads. Independent preservation evidence includes F-VQ65, whose preservation leg records `restart_serialized_multiswap = PASS`. Current [Status-A traceability](../status-a/TRACEABILITY.md) separately records same-tree restart observable and mass-preservation replay for the pinned Status-A production tree.

The review chain is therefore:

`committed-state ownership -> typed kernel/FMR persistence implementation -> F-KT16 qualification/admission -> permanent preservation role -> Status-A same-tree preservation`

## What Restart v1 does not claim

Restart v1 does **not** establish:

- persistence of mid-transaction trial state or disposable worker scratch;
- a filesystem, file-path or byte-format standard;
- future-major-schema migration compatibility;
- distributed crash-recovery semantics;
- broad deep-vadose or MODFLOW restart qualification;
- automatic restart coverage for arbitrary external backend state;
- universal restart safety for future state-owning capabilities;
- parallel/concurrent real-physics MultiSWAP restart beyond separately admitted scope.

It also does not create new physics or numerical policy. Schema values documented here describe the frozen implementation; they are not a promise of compatibility with an unspecified future schema.

## Review questions

When reviewing a restart-sensitive change, check:

1. Is the changed value part of committed continuation state, immutable configuration, or only candidate/scratch state?
2. If it is committed state, which typed state layout owns it and is that layout covered by the restart-state contract?
3. Does export capture it from committed authority rather than from an in-flight candidate?
4. Can restore validate schema, template/layout identity, parameter identity and provenance before publication?
5. Is publication atomic if one record in a multi-column bundle is invalid?
6. Does uninterrupted versus restarted continuation preserve the required observable and conservation contract?
7. Has the source/template/state dependency surface changed since the qualification evidence being inherited?

See also [Current Status-A architecture](../status-a/CURRENT_ARCHITECTURE.md), [Transactional time stepping and acceptance](../numerics/transactional-time-stepping.md), and the F-DOC28 authority matrix in `integration/f-doc/F-DOC28_AUTHORITY_MATRIX.md`.
