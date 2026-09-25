# F-PE-ZERO-WASTE01 — Performance opportunity map

Date: 2026-09-25

Status: `ACTIVE_AUDIT_MAP`

## Purpose

This document is the central opportunity map for the SWAP5 / MultiSWAP zero-waste performance audit.

The governing question for every execution block is:

> Must this work happen, must it happen this often, must it happen for every column, and must it happen at this precision?

This map does not authorize approximation. It separates avoidable work from required physics/numerics and records the next evidence needed before repair.

The preferred optimization ordering is:

1. do not execute unnecessary work;
2. execute necessary work less often;
3. move or initialize less data;
4. execute the same required computation more cheaply;
5. only then consider separately governed application-qualified approximation.

## Relation to active performance work

This map extends, rather than competes with:

- F-PE-PROFILE01: compute-core baseline and runtime attribution;
- F-PE-PROFILE02-H03: constitutive tuple reuse qualification;
- F-PE-ZERO-WASTE01: concrete repair work.

The map is therefore an audit ledger, not a second implementation branch.

## Opportunity classes

Each candidate is assigned one primary action class.

- `AVOID`: the operation or solve is not required on the qualified path.
- `FEWER`: the operation is valid but runs more often or over a broader domain than needed.
- `CHEAPER`: the result is required, but the implementation is unnecessarily expensive.
- `MOVE_LESS`: full-state or full-array movement/initialization exceeds actual demand.
- `PRECOMPUTE`: immutable or slowly varying work can be moved out of the hot path.
- `REUSE`: a previously computed result remains valid under explicit dependency conditions.
- `UNRESOLVED`: evidence is insufficient to classify.

Necessity classification remains the PROFILE01 taxonomy:

- `N1_REQUIRED`
- `N2_REQUIRED_EXPENSIVE_IMPLEMENTATION`
- `N3_CONDITIONALLY_REQUIRED`
- `N4_REDUNDANT`
- `N5_DEAD_OR_NONCONTRIBUTING`
- `NX_UNRESOLVED`

## Current opportunity map

| ID | Execution area | Evidence / observation | Action class | Necessity | Risk | Next gate |
|---|---|---|---|---|---|---|
| ZW-H01 | Reference Richards workspace reset | PROFILE01 observed three full resets per Reference solve. H1/H2 have already reduced the caller-owned route to one required reset. | AVOID / MOVE_LESS | N4 for removed resets | low | complete canonical qualification and persist runtime effect |
| ZW-H03 | Constitutive tuple evaluation | PROFILE02-H03 qualified reuse of already-computed capacity across the first Newton iteration. | REUSE | N4 for duplicate recomputation under unchanged head | low | retain qualified postimage; include in end-to-end ledger |
| ZW-H04 | Provider component granularity | Whole tuple is not globally redundant. Demand is phase-dependent: K, C and theta have different use moments; dK/dh is reserved/zero on admitted swkimpl=0 route. | FEWER / CHEAPER / REUSE | NX to N3 by component and phase | medium | instrument component demand by phase and convergence outcome before ABI change |
| ZW-H05a | Residual whole-array preclear | Removed on the active work branch. `vector_F` fully assigns the active residual range before consumption; poisoned-workspace testing is present. | AVOID / MOVE_LESS | N4 repair implemented | low | complete current CI qualification and persist exact source/result identity |
| ZW-H05b | provider_root_sink preclear | Removed on the active work branch. With provider active the provider overwrites the array; with provider inactive `root_sink_term` returns zero. | AVOID / MOVE_LESS | N4 repair implemented | low | complete current CI qualification, including active/inactive route coverage |
| ZW-H06 | Immutable hydraulic parameter preprocessing | Parameter preprocessing remains a hot-path candidate where immutable transformations can be hoisted from repeated solve/dispatch work. | PRECOMPUTE | N3 candidate | low-medium | measure call count per column/solve and prove invalidation contract |
| ZW-H07 | Serialized registry validation | The branch now contains an optional validated execution-plan path whose `matches` contract can bypass repeated full registry validation. Baseline pairwise validation remains available when no plan is supplied. | FEWER / PRECOMPUTE | N3 repair candidate implemented | medium | qualify invalidation/mismatch rejection and quantify dispatch-scale saving |
| ZW-H08 | Execution-order construction | The branch now persists execution order inside `fmr_serialized_execution_plan_t` and consumes it when a plan is supplied, avoiding per-dispatch reconstruction. | FEWER / PRECOMPUTE | N3 repair candidate implemented | medium | qualify canonical/reverse/mixed order identity and plan mismatch fail-closed behavior |
| ZW-H09 | Receipt validation and lookup | Baseline benchmark at N=R=10,000 measured ~44.7 ms validation plus ~37.8 ms lookup with ~200 million structural comparisons combined. H09 now builds one dispatch-local column-id index and direct `receipt_slot_by_column` map. | CHEAPER / PRECOMPUTE | N2/N3 repair implemented | medium | FMR18 receipt semantics PASS plus indexed scaling benchmark |
| ZW-H10 | Per-column diagnostics allocation | Dispatch preregistration identifies per-column diagnostics initialization including `allocate(worker_assignments(1))`. | FEWER / MOVE_LESS | NX | low-medium | count allocations across N and test stack/fixed/persistent storage alternatives |
| ZW-H11 | Atomic/concurrency tracking on serialized path | Dedicated microbenchmark exists for serialized concurrency counter overhead. | AVOID / CHEAPER | NX | medium | prove whether atomic semantics are required when execution is demonstrably serialized |
| ZW-H12 | State capture capacity / transaction buffers | Capture-capacity lifecycle gate exists; transaction and state movement remain candidate overhead. | FEWER / MOVE_LESS / REUSE | NX to N3 | high | attribute bytes copied per trial/accepted step and prove minimal transaction state |
| ZW-H13 | Runtime dispatch metadata | Serialized MultiSWAP dispatch performs metadata work whose value may be invariant over many steps. | PRECOMPUTE / REUSE | N3 candidate | medium | create explicit validated execution-plan identity/revision contract |
| ZW-H14 | Disabled-process work | PROFILE01 explicitly requires inspection of work performed for disabled physics. | AVOID | NX | low-medium | static + counter audit per optional process family |
| ZW-H15 | Loop-domain overreach | PROFILE01 explicitly targets loops over inactive/unneeded ranges. | FEWER | NX | low-medium | compare active node/layer/process domains against actual loop bounds |
| ZW-H16 | Repeated diagnostics/balance assembly | Diagnostics/accounting is a named compute category and possible repeated-work source. | FEWER / REUSE | NX | medium | trace which balances are required per trial versus accepted state only |
| ZW-H17 | Pack/unpack and representation conversion | PROFILE01 flags representation conversions and state packing as possible pure data movement. | MOVE_LESS / REUSE | NX | medium | byte/call accounting and ownership trace |
| ZW-H18 | Scratch allocation/resizing | Repeated allocate/deallocate and scratch resizing inside hot paths are explicit audit targets. | PRECOMPUTE / REUSE | NX | low | allocation counters and capacity-reuse experiment |
| ZW-H19 | Full solve avoidance under unchanged coupling state | Not yet qualified. In coupled SWAP5-MODFLOW6, a previously qualified response may remain reusable when interface state and all relevant forcing/state dependencies are unchanged within an explicit validity envelope. | AVOID / REUSE | research hypothesis only | high | separate preregistration; never infer from head equality alone |
| ZW-H20 | Local response reuse / tangent-assisted coupling | Existing coupling work suggests response information may reduce repeated full column solves. This is not zero-waste until exact validity is established; otherwise it belongs to application-qualified acceleration. | REUSE / FEWER | NX | high | keep outside zero-waste unless exact dependency proof exists |

## First-order priority

### Tier A — bounded exact waste already evidenced

1. finish H01/H05 current CI qualification and freeze their exact postimage;
2. qualify H07/H08 execution-plan identity, invalidation and large-N saving;
3. quantify and remove remaining hot-path allocations/zeroing where overwrite-before-read or persistent-capacity proofs are available.

These are preferred because they do not require approximation and have narrow semantic surfaces.

### Tier B — structural MultiSWAP overhead

4. H09 receipt lookup/validation;
5. H10 diagnostics allocation/materialization;
6. H11 serialized atomic tracking;
7. reprofile structural dispatch overhead after the execution-plan tranche.

This tier can dominate large-N coupled runs even if single-column profiling shows small effects.

The main target is not merely a faster local loop. The target is moving invariant validation and planning out of every dispatch while retaining fail-closed behavior through explicit identity/revision invalidation.

### Tier C — repeated solver/process work

9. H04 phase-specific constitutive demand;
10. H06 immutable parameter preprocessing;
11. H12 transaction/state movement;
12. H14-H18 disabled-process, loop-domain, diagnostics and data-movement audits.

### Tier D — avoid the solve

13. H19/H20 only after exact zero-waste and exact acceleration are sufficiently closed.

A full Richards solve must not be skipped merely because a previous response looks similar. Exact reuse requires explicit dependency identity. If tolerance-based or approximate reuse is needed, it belongs to the later application-qualified performance line.

## Large-N scaling rule

Single-column percentages are insufficient for MultiSWAP.

For metadata or orchestration work the audit must report operation count as a function of number of columns N and requested receipts R, not just elapsed CI time.

Example already preregistered:

`registry duplicate comparisons = N*(N-1)`

At N=10,000 this equals:

`99,990,000`

equality checks before physical solve.

This makes structural complexity a qualification concern independently of noisy shared-runner timing.

## Scientific separation

Three performance claims must remain separate.

### P0 zero-waste

Same intended numerical/physical solution. Work was unnecessary.

### P1 reference-preserving acceleration

Implementation or representation changes may produce floating-point-level differences but remain tightly qualified against the reference equations and accepted trajectory.

### P2 application-qualified acceleration

Approximation is allowed only under a separately preregistered error budget based on coupled quantities such as cumulative water balance, ET, recharge, capillary flux, drainage and groundwater response.

P2 must not be used to excuse unresolved P0 waste.

## End-to-end performance ledger requirement

Each admitted repair must eventually record:

- exact source commit;
- workload;
- compiler and flags;
- operation/call-count delta;
- local runtime delta;
- whole-run runtime delta;
- accepted-state equivalence or qualified numerical error;
- interaction with previously admitted optimizations.

Speedups must not be added arithmetically across independent experiments.

## Immediate execution order

The next bounded sequence for F-PE-ZERO-WASTE01 is:

`H01/H05 qualify -> H07/H08 execution-plan qualify -> H09 receipt indexing qualify -> H10/H11 dispatch micro-overhead -> reprofile -> select next dominant exact-waste target`

After every material tranche, reprofile. Optimization changes the runtime distribution; stale hotspot rankings must not govern later work.

## Strategic boundary

Sequential Steady State or other reduced representations are not treated as a required destination.

The decision point is deferred until the measured cost of a cleaned, exact or reference-preserving SWAP5 column is known under realistic SWAP5-MODFLOW6 / MultiSWAP workloads.

The relevant comparison is then total coupled cost, not solver microbenchmarks in isolation.
