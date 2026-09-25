# F-PE-ZERO-WASTE01 dispatch-overhead profiling preregistration

Date: 2026-09-25

## Scope

This experiment measures structural serialized MultiSWAP metadata work before any persistent validated execution-plan design is admitted.

It is measurement-only. It does not change production source, physics, tolerances, transaction semantics, accepted state, fail-closed validation, execution order, receipt semantics or diagnostics contracts.

Pinned source head for preregistration:

`6c2ac0314a85e5c724c1f4f02c7709162740f716`

## Questions

The central question is not how to optimize these routines locally, but why invariant registry work is repeated for every dispatch.

The profiler measures:

1. registry structure validation on a valid unique registry;
2. execution-order construction for canonical, reverse and deterministic mixed input order;
3. per-column diagnostics initialization including the current `allocate(worker_assignments(1))` pattern;
4. receipt-request validation for R=N valid unique receipt ids;
5. receipt-slot lookup for all N executing columns against R=N requested ids;
6. repeated template lookup with up to ten templates.

Column counts are exactly:

- N=100
- N=1,000
- N=10,000

## Source binding

`fmr_build_execution_order` is invoked directly from the current production `mod_fmr_runtime_core`.

The remaining benchmark routines mirror the current private serialized-runtime algorithms and use the actual public runtime-core derived types. They are observation code only and do not establish a new public runtime API.

Exact operation-count terms are emitted with elapsed timing so the structural conclusion does not depend on one GitHub runner.

## Expected structural work

For valid columns, current registry validation performs two duplicate comparisons per column pair:

`N*(N-1)`

column equality checks for `column_id` and `state_handle` combined.

At N=10,000 this is 99,990,000 pairwise equality checks before any physical solve.

Insertion-sort execution-order work is order-sensitive and therefore must not be summarized by one input order.

Receipt validation and slot lookup are measured separately because both contain repeated linear or pairwise searches when R scales with N.

## Interpretation rules

- No post-hoc timing outlier deletion.
- No portable speed claim from this shared runner.
- The profiler can justify a later design experiment but cannot itself admit a persistent validated execution plan.
- Fail-closed validation may only move out of the per-dispatch path if an equivalent identity/revision invalidation contract is established.
- No production repair follows merely because an O(N^2) term exists; measured scale and actual registry lifetime must support the change.
