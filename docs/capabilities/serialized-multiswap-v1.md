# Serialized MultiSWAP v1

Serialized MultiSWAP v1 is the admitted SWAP5 orchestration capability for executing multiple qualified real-physics column contexts **serially** while preserving the same transaction, state-ownership and mass-accounting rules that apply to one qualified column.

It is an execution/composition capability, not a new soil-water equation and not a parallel-runtime claim.

## Frozen Status-A boundary

For the first Status-A review package, this page is bounded to:

- Status-A authority `992a5c657bfe10a10100f92e0cb77c4825ae65b6`;
- scientific production baseline `50346642bd565f79134ea17d5462e544b354998c`;
- scientific production tree `3b085d7dea3d3f3fce42ad9d8f259a8350205846`.

The main frozen multi-column orchestration owner is `src/runtime/mod_fmr_serialized_multiswap_runtime.f90`. `mod_fmr_runtime_core.f90` owns the logical column/template contracts and deterministic ordering, while `mod_fmr_serialized_reference_backend.f90` owns the qualified per-column reference-physics backend. Restart and optional-state semantics are dependencies with their own qualification authorities; they are not redefined here.

## Runtime objects and ownership

A logical column is runtime metadata. In the frozen runtime it carries stable identities and handles such as:

- `column_id`;
- `template_id`;
- `parameter_ref`;
- `state_handle`;
- `forcing_handle`;
- execution class;
- backend identity.

The template separately identifies physical topology, vertical/state layout, solver interface, optional physical-state layout and numerical-continuation layout.

This separation is deliberate. A logical column does not become a container for all model memory. Immutable parameters and forcing remain registry-owned inputs; mutable accepted physical state is reached through the column's state handle; numerical workspace remains backend/worker-local and non-persistent.

That distinction is central to the MultiSWAP architecture: increasing the number of logical columns does not require one persistent Richards/Newton/Jacobian workspace per column.

## Registry preflight

Before the serialized physical loop begins, `fmr_run_serialized_physical_multiswap` validates the request and registry structure. The frozen route fails closed for invalid dispatch structure rather than entering physical execution with ambiguous ownership.

The preflight includes the structural relationship among logical columns, templates and committed-state handles. In particular, a mutable committed-state entry cannot be claimed by more than one logical column in the same request.

Optional accepted-commit receipt requests are also validated as a complete sparse request before backend initialization or any physical trial. Expected request-structure failures are therefore precommit failures.

This preflight must not be confused with whole-batch atomic commit. It validates the batch structure before execution; it does not turn all column commits into one indivisible transaction.

## Deterministic serialized execution order

The frozen runtime builds an explicit execution order before dispatch. Ordering is deterministic:

1. ascending `template_id`;
2. within the same template, ascending `column_id`.

The runtime then traverses that order serially. `batch_size` partitions the ordered list for runtime accounting, but the admitted v1 physical route still executes one qualified physical column at a time.

The runtime diagnostic `max_simultaneous_real_physical_solves` belongs to this serialized execution surface; the Status-A claim is not a concurrency claim.

## One authoritative transaction path per column

Registry resolution and physical transaction ownership are kept separate. The registry-facing layer resolves the selected template, parameter set, forcing and committed state. The resolved objects then cross into one authoritative physical transaction body.

For each column, the frozen composition reuses the existing transaction lifecycle:

`committed origin -> checkpoint -> candidate trial/retry -> commit or reject -> updated committed authority`

The runtime does not create an alternative MultiSWAP scientific state machine. Candidate state remains tentative. On successful commit, the committed revision/time and mass result become the column's accepted output. If commit is rejected, the candidate does not become committed authority.

This is also why MultiSWAP does not own separate process physics: the per-column backend remains responsible for the already-qualified physical solve, while the transaction/kernel layer remains responsible for acceptance and publication.

## Column isolation

F-MR42 closes the frozen v1 capability with per-column mutable-state isolation as part of its denominator. The architecture separates:

- per-column committed physical state;
- shared immutable parameter/template information;
- per-request forcing;
- worker/backend-local numerical scratch.

A rejected trial in one column therefore has no authority to overwrite another column's committed state. The serialized composition also does not promote orchestration metadata into a second scientific state authority.

This is a bounded isolation claim for the admitted serialized runtime. It is not proof of arbitrary shared-state safety under concurrent threads or processes.

## Column result and aggregate diagnostics

Each dispatched column has its own result and diagnostics, including its column identity, dispatch ordinal, admission/commit state, solver counters, committed revision/time and mass accounting.

The runtime also constructs aggregate diagnostics from the column diagnostics. The frozen types include, among other fields:

- number of columns and templates;
- batches;
- attempts, retries and failures;
- work distribution and cost summaries;
- aggregate unrounded mass residual.

The more specific serialized batch diagnostics additionally track requested/admitted/executed/committed/rejected columns, physical solve count, deterministic collection, effective interval and maximum absolute column mass residual.

These diagnostics report the composed execution. They do not create a second acceptance criterion that can override the per-column transaction or mass gates.

## Mass-accounting boundary

Mass conservation remains a hard qualified property of the serialized capability. F-MR42 records hard water-mass conservation and accepted-commit accounting in the v1 denominator, and the Status-A preservation authority includes same-tree replay of the serialized observable and aggregate-mass behaviour.

The aggregate diagnostics sum/report the already-owned column accounting; they are not a substitute for the underlying per-column mass completeness and acceptance contracts.

No tolerance is broadened by MultiSWAP merely because several columns are composed.

## Batch failure semantics

A useful boundary is what Serialized MultiSWAP v1 **does not** do.

Registry/request failures detected before the loop fail before physical execution. Once the serialized loop has started, however, column transactions are completed individually. A previously accepted column is not retroactively rolled back merely because a later column is rejected.

Therefore the frozen v1 capability establishes deterministic serialized composition with isolated per-column transaction authority; it does **not** establish an all-columns-or-nothing batch transaction.

Any future whole-batch atomic publication contract would be a separate capability and would require separate qualification.

## Restart and continuation state

Serialized MultiSWAP depends on the admitted Restart v1 and typed optional-state contracts.

At a committed restart boundary, continuation authority belongs to committed per-column state and its identity/provenance. Solver/Newton/Jacobian scratch is deliberately excluded from persistent continuation state and may be recreated after restart.

Optional physical state is conditional. The frozen runtime recognizes admitted layout identities such as base state, Snow, restricted soil temperature and restricted fixed-weir surface-water state. An inactive optional process does not force every logical column to carry that process's persistent state.

For the detailed persistence contract, see [Restart v1](restart-v1.md).

## Generic time

The serialized runtime accepts an explicit interval `[t0,t1]`. F-MR42 records generic interval and committed-time semantics as part of the completed v1 capability: Serialized MultiSWAP itself does not introduce a fundamental one-day or midnight assumption.

Process capabilities may still have their own separately admitted temporal boundaries. For example, a process-specific one-call-daily restriction is not erased merely because the outer MultiSWAP runtime uses generic intervals.

## Qualification and preservation chain

F-MR42 is the completion authority for the fixed Serialized MultiSWAP v1 denominator. Its decision is `QUALIFIED_SERIALIZED_MULTISWAP_V1_100_PERCENT_COMPLETE`; its final qualification run succeeded on the validated F-MR42 head.

F-MR42 does not manufacture new independent evidence. It reconciles the qualified dependency chain, including:

- F-MR05 / independent F-VQ15 for the serialized real-physics foundation;
- F-MR19, independent F-MQ29 and F-CI35 for committed restart composition;
- F-MR41 and F-CI48/F-CI48P for typed optional-state ownership;
- F-CI49/F-CI49P for transaction composition preservation.

Historical permanent-testbank authority F-TB11 registers `FTB11-MSW-001` and adopts Serialized MultiSWAP v1 via F-MR42 for its own pinned snapshot. For the later frozen Status-A production tree, [Status-A traceability](../status-a/TRACEABILITY.md) records same-tree serialized-observable and aggregate-mass replay. The historical F-TB11 snapshot is not silently rebound to later heads.

## Relationship to later capabilities

Later or adjacent work must remain separate from this frozen claim.

In particular, post-Status-A direct-groundwater MultiSWAP compositions, RossFast routing, mixed backend execution, parallel-worker semantics and performance/scaling work do not retroactively enlarge Serialized MultiSWAP v1. They may reuse parts of this architecture, but each requires its own admission and preservation authority.

## Explicit nonclaims

Serialized MultiSWAP v1 does **not** claim:

- parallel or concurrent real-physics execution;
- arbitrary thread-safe or process-safe shared scientific state;
- whole-batch atomic commit/rollback;
- automatic rebatching or execution-class switching;
- worker scaling, SIMD/GPU or 100k-column throughput qualification;
- a general performance speedup;
- RossFast or mixed Reference/RossFast MultiSWAP inside the frozen Status-A denominator;
- unrestricted direct-groundwater or MODFLOW MultiSWAP semantics;
- that future newly admitted process state is automatically MultiSWAP-safe;
- general filesystem/byte-format restart interchange or cross-version migration;
- mid-transaction/trial-state restart;
- persistence of solver/Newton/Jacobian scratch.

Those are separate capability decisions.

## Review questions

When reviewing a MultiSWAP-sensitive change, ask:

1. Does every logical column still resolve to exactly one authoritative mutable committed-state owner?
2. Are immutable parameters, forcing, committed state and numerical scratch still separate ownership classes?
3. Does registry validation still fail closed before physical work for structural ambiguity?
4. Does each column still use the admitted checkpoint/trial/retry/commit-or-reject lifecycle?
5. Can rejected candidate state leak into committed state or another column?
6. Is deterministic serialized ordering preserved where the v1 claim depends on it?
7. Are aggregate diagnostics reporting already-authoritative column outcomes rather than becoming a second acceptance authority?
8. If new persistent process state is introduced, is its restart and MultiSWAP isolation dependency explicitly qualified?
9. Is a performance or concurrency change being mistaken for an expansion of the frozen serialized semantics?

See [Current Status-A architecture](../status-a/CURRENT_ARCHITECTURE.md) for the broader runtime ownership model and [Restart v1](restart-v1.md) for committed-state persistence.