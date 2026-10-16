# SWAP5 lessons register

## Purpose

This register preserves cross-workstream lessons that should survive individual chats and branches. A lesson can improve governance or future design without authorizing a production change.

Governing policy: [Quality governance after Status A](quality-governance-a-aa.md).

## Tags

- `SWAP_SPECIFIC`
- `GENERAL_MODELLING_PRINCIPLE`
- `ANIMO_RELEVANT`
- `COUPLING_RELEVANT`
- `PUBLICATION_RELEVANT`
- `BACKPORT_TO_SWAP5_GOVERNANCE`
- `FUTURE_ONLY`

## Current lessons

### LR-001 Persist before expensive qualification

Useful implementation state must be persisted before long compilation, regression, benchmark or qualification runs. Implemented, persisted, tested and qualified are different states.

### LR-002 One canonical production truth

Parallel workstreams may exist, but shared production semantics must converge through controlled canonical integration. A branch or chat is not project-wide authority.

### LR-003 Parallel where ownership is disjoint

Parallelize isolated code, evidence, documentation, tests and research. Serialize changes to shared state ownership, transaction semantics, exchange contracts, numerical policy and other shared semantics.

### LR-004 Corrected legacy is not automatically scientific truth

A corrected legacy reference is required for behavioural comparison, but theory, documentation, legacy implementation and SWAP5 behaviour still require explicit reconciliation.

### LR-005 Documentation is qualification evidence

Scientific meaning, applicability, ownership and numerical policy should evolve with the qualified source rather than being reconstructed only at the end.

### LR-006 Preserve the frozen Status-A denominator

Post-Status-A development must not silently rewrite the first Status-A review baseline. Current documentation may explain later authority, but historical qualification claims remain pinned.

### LR-007 Reduce interfaces by modelling ownership, not by hiding dependencies

Legacy argument reduction is useful only when the replacement makes ownership clearer. Moving dependencies into mutable globals or one oversized context object is not modernization.

### LR-008 Precision is explicit numerical policy

Mixed or reduced precision requires dedicated evidence. It is not automatically a refactor or performance-only change.

### LR-009 Backend realization is not application authority

**Origin:** F-GC coupling-semantics reconciliation, 2026-09-20.  
**Tags:** `SWAP_SPECIFIC`, `COUPLING_RELEVANT`, `GENERAL_MODELLING_PRINCIPLE`.

A backend may realize an abstract application contract through an existing numerical boundary option without making that legacy option the application-level authority. Conflating those levels can create an authority-binding defect even when the backend mathematics remains usable.

Current example under investigation: PR #486 distinguishes explicit coupled-groundwater application authority from private Reference realization through `SWBOTB=5`.

### LR-010 Moving branches need explicit control snapshots

**Origin:** PROJECT-CONTROL-01.  
**Tags:** `SWAP_SPECIFIC`, `GENERAL_MODELLING_PRINCIPLE`, `BACKPORT_TO_SWAP5_GOVERNANCE`.

A rapidly moving canonical branch cannot itself serve as a stable mental project map. Routing documents should pin an exact snapshot, identify live-delta rules and preserve earlier snapshots as historical evidence.

## New-entry template

```text
ID:
TITLE:
TAGS:
ORIGIN / WORKSTREAM:
OBSERVATION:
GENERAL LESSON:
CURRENT SWAP5 ACTION:
CROSS-MODEL RELEVANCE:
EVIDENCE / REFERENCES:
STATUS:
```
