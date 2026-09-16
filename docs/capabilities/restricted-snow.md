# Restricted Snow capability

Snow is admitted in SWAP5 Status-A only for the **restricted one-call-daily path** that was independently qualified and canonically closed. This boundary is part of the scientific claim and must remain visible in review documentation.

## Scientific role

The admitted Snow process represents the qualified daily snow-storage/process behaviour used by the current SWAP5 production path. F-DOC20 does not generalize that process to different temporal semantics or introduce a new melt/snow formulation.

The current documentation therefore treats Snow as a bounded scientific capability rather than as evidence that every historical or conceivable Snow execution mode is supported.

## State and accounting

Snow storage and process fluxes participate in the admitted interval accounting contract. Candidate Snow effects produced during a tentative attempt become authoritative only through accepted execution, consistent with the SWAP5 transaction model.

The qualification chain also protects the distinction between internal transfers and external gains/losses so process accounting is not silently double counted.

## Status-A evidence

The restricted Snow capability is contained in scientific production baseline `50346642…`. Its admission/closure authority is the F-PM02 chain together with independent scientific/runtime/MultiSWAP evidence incorporated into Status-A.

Current preservation includes:

- same-tree Snow preservation in the F-GC29 reconciliation; and
- the successful exact-head `F-PM02 Canonical Snow Preservation` workflow on `50346642…`.

Follow [Status-A traceability](../status-a/TRACEABILITY.md) for the current authority path.

## Explicit nonclaims

The admitted Snow capability does **not** claim:

- subdaily Snow execution;
- multi-day aggregation as an equivalent replacement for the qualified daily call;
- arbitrary-duration scaling;
- advanced or redesigned melt semantics;
- automatic validity under future parallel/concurrent real-physics execution;
- scientific validity outside the qualified configuration merely because the same routine is reached.

Those modes remain outside the Status-A denominator unless separately admitted.

## Review questions

For a Snow-sensitive change, verify:

1. Does the execution remain inside the one-call-daily contract?
2. Are storage and process fluxes conserved under the owning Snow accounting contract?
3. Are internal transfers prevented from becoming duplicate external balance terms?
4. Does rejection/rollback remove tentative Snow state and accounting effects?
5. Has any timing or composition assumption changed enough to invalidate inherited evidence?

The broader transaction model is described in [Transactional time stepping and acceptance](../numerics/transactional-time-stepping.md).