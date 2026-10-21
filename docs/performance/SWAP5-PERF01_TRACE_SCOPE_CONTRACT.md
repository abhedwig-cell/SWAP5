# PERF01 transaction-scoped flux-history reclamation

Proposed execution-storage correction on canonical
`969aa918f0104546ec4ca2372feccf37b0145627`. No numerical tolerance, equation,
trial order, physical state, serialized restart or acceptance decision changes.
The goal is to reclaim successful trace records belonging only to rejected trial
branches once the internal transaction contexts that can reference them expire.

## Scope lifetime and ownership

Add an opaque `transaction_scratch_scope_t` token and two default-no-op model
methods, `begin_scratch_scope` and `end_scratch_scope`. The public
`execute_reference_interval` signature stays unchanged. Its wrapper opens a
scope, runs the original transaction body unchanged, then closes the scope
**after that body's local contexts have been destroyed**. Every ordinary return,
including invalid requests, exhaustion and model-certificate execution, crosses
this wrapper. A fatal process stop does not promise cleanup.

Only the private Reference backend overrides these hooks. Its token contains
the current trace generation and the highest allocated entry at scope entry.
An inactive trace uses an inert token. Scope tokens are transient owner metadata,
not physical state, a restart field or a handle for another model.

At close, all entries at or below the entry watermark remain untouched. This
preserves externally retained checkpoints and sibling branches, including
checkpoints belonging to a surrounding kernel transaction. The surviving active
chain above the watermark is moved, without copying or modifying payload values,
into a contiguous suffix. Its predecessor indices and the private active tail
are remapped. All other newly created suffix payloads are deallocated. Active
trace count and physical outcomes are unchanged. Previously allocated spare
arena capacity may remain allocated; payload storage for abandoned new branches
does not accumulate across these transactions.

Temporary contexts created inside the private transaction body cannot escape
that body. Models that need to publish such a context must provide another
scope policy rather than enable this Reference-only implementation. Nested
scopes protect everything created before their own watermark. Compaction must
not run while the closing scope's internal contexts remain live. A caller must
not create a scope on one model and close it on another, close twice or cross
generations. Invalid generations/watermarks fail closed. Existing stale/invalid
context checks remain binding.

This deliberately does not trace arbitrary external context lifetimes or
collect pre-watermark garbage. It avoids reference-counting finalizers and
unsafe rollback-time truncation. Allocation remains proportional to retained
history plus one scope's trial suffix, not strictly constant with simulation
length. Excessive accepted substeps still need separate numerical/cost handling.

## Selected qualification

1. Direct O0 checked/O2 lifecycle tests: success, retry exhaustion, invalid
   requests and certificate route; default hooks preserve existing models.
2. Real private Reference scope collection: payload identity, surviving suffix,
   pinned siblings, failure rollback, empty trace, nested scopes and invalid
   token/context rejection. Existing immutable-branch test remains unchanged.
3. Fresh current column builds O0/O2 and original input/grid/budget/restart
   assertions; exact physical bytes/work against the pinned unchanged-numerics
   dry32 failure, including external failed-window clocks.
4. Paired512MiB resource control and scoped dry32 replay. Scope reclamation must
   restore the original numerical failure instead of exhausting trace memory.
   A generated rounding experiment remains separate and unqualified.
5. Original analytic policy/runtime drivers and current matrix/pond thermal
   O0/O2 physical/restart/rollback/refinement preservation where the changed
   transaction closure executes. Frozen predecessor authorities remain exact;
   current admission requires an explicit source-bound successor.

Relevant invariants:3,5,7,13,22,23,24,25,26. No RossFast scope expansion, relaxed
mass criteria, master promotion or full-day dry qualification is implied.
Full F-CI and long low-air stress are not selected solely for no-op inherited
hooks; the changed Reference route and shared transaction lifecycle receive
fresh targeted native proof. Expected builds tens of seconds, bounded model
probes120s or less, with explicit address-space limits on resource experiments.
