# Restart v1

Restart v1 is the admitted SWAP5 persistence capability for reconstructing the **committed execution state** required for qualified continuation. It is part of the Status-A denominator, but its claim is deliberately narrower than “serialize everything in memory”.

## What problem Restart v1 solves

A restart point must represent the model state that is authoritative after accepted execution. In SWAP5, that means persistence is tied to the transaction model:

- committed state is persistent authority;
- candidate state belongs to an active attempt until acceptance;
- scratch/workspace is disposable and has no independent persistence authority.

Restart therefore preserves the accepted continuation contract rather than copying arbitrary transient memory.

## Status-A contract

Within the admitted Restart v1 scope, a qualified continuation reconstructed from a restart must preserve the relevant observable and mass-accounting behaviour of uninterrupted execution.

The Status-A authority records Restart v1 as canonically admitted and reports same-tree replay of the restart observable and mass-preservation checks for the pinned scientific production tree.

## Relation to transactions

Restart belongs to the persistence layer, but it depends on transaction ownership. A rejected trial is not a valid restart authority merely because it existed in memory. The restart image is constructed from the state that the execution layer recognizes as committed.

This prevents a failed or retried attempt from silently becoming the starting point of a later run.

## Evidence route

For current review, use the authority chain recorded in [Status-A traceability](../status-a/TRACEABILITY.md):

`committed-state persistence contract -> production implementation in 50346642… -> Restart qualification/admission -> Status-A acceptance -> same-tree restart observable and mass-preservation replay`

Earlier permanent-testbank records remain useful immutable evidence for their own snapshots, but they are not automatically rebound to later canonical heads.

## What Restart v1 does not claim

Restart v1 does **not** establish that:

- every scratch/workspace value is serialized;
- rejected candidate state is persistent authority;
- every future process or execution mode is already restart-safe;
- parallel/concurrent real-physics MultiSWAP restart is admitted;
- arbitrary external backend state is automatically covered.

A new state-owning capability must establish its own persistence dependency before it can inherit the Restart v1 claim.

## Review questions

When reviewing a restart-sensitive change, check:

1. Is the changed value part of committed scientific/execution state or only scratch/candidate state?
2. If it is committed state, is capture/restore ownership explicit?
3. Does uninterrupted versus restarted continuation preserve the capability’s required observable and conservation contract?
4. Does a rejected attempt remain absent from the restart authority?
5. Has the relevant dependency surface changed since the evidence being inherited?

See also [Current Status-A architecture](../status-a/CURRENT_ARCHITECTURE.md) and [Transactional time stepping and acceptance](../numerics/transactional-time-stepping.md).