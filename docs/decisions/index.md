# Architecture Decision Records

Architecture Decision Records, ADRs, capture decisions that are difficult to infer reliably from code alone.

An ADR records:

- the problem context;
- the accepted decision;
- consequences and trade-offs;
- affected architecture invariants;
- implementation and verification implications.

## Status values

- **Proposed**: under discussion.
- **Accepted**: current design direction.
- **Superseded**: replaced by a later ADR.
- **Rejected**: considered but deliberately not adopted.

## Current records

| ADR | Decision | Status |
| --- | --- | --- |
| [ADR-0001](ADR-0001-one-kernel-io-outside.md) | One kernel, I/O outside | Accepted |
| [ADR-0002](ADR-0002-transactional-time-stepping.md) | Transactional time stepping | Accepted |
| [ADR-0003](ADR-0003-worker-owned-scratch.md) | Worker-owned scratch | Accepted |
| [ADR-0004](ADR-0004-multiswap-execution-templates.md) | MultiSWAP execution templates | Accepted |
| [ADR-0005](ADR-0005-reference-baseline-chain.md) | B0/B1/B2 reference baseline chain | Accepted |
