# SWAP5 lessons register

## Purpose

This register captures lessons that should survive individual chats and workstreams. Its purpose is to distinguish improvements that belong in current SWAP5 governance from ideas that are useful only for future model modernisation such as ANIMO.

The register is governed by [Quality governance: Status A to Status AA](quality-governance-a-aa.md).

## Classification

Each lesson should use one or more of these tags:

- `SWAP_SPECIFIC`
- `GENERAL_MODELLING_PRINCIPLE`
- `ANIMO_RELEVANT`
- `COUPLING_RELEVANT`
- `BACKPORT_TO_SWAP5`
- `FUTURE_ONLY`

A lesson tagged `BACKPORT_TO_SWAP5` does not itself authorize a production-code change. Production changes still require the relevant architecture and qualification gates.

## Current lessons

### LR-001 Persist before expensive qualification

**Tags:** `GENERAL_MODELLING_PRINCIPLE`, `ANIMO_RELEVANT`, `BACKPORT_TO_SWAP5`

Useful implementation state must be persisted before long compilation, regression, benchmark or qualification runs. Implementation, persistence, testing and qualification are separate states.

### LR-002 One canonical production truth

**Tags:** `GENERAL_MODELLING_PRINCIPLE`, `ANIMO_RELEVANT`, `BACKPORT_TO_SWAP5`

Parallel workstreams may exist, but long-lived competing production baselines create provenance and merge debt. Shared production semantics must converge through controlled canonical integration.

### LR-003 Parallel where ownership is disjoint

**Tags:** `GENERAL_MODELLING_PRINCIPLE`, `ANIMO_RELEVANT`, `BACKPORT_TO_SWAP5`

Parallelize tests, evidence, documentation, analysis and isolated components aggressively. Serialize changes to shared state layout, kernel contracts, transaction semantics, numerical policy and other common semantics.

### LR-004 Corrected legacy is not automatically scientific truth

**Tags:** `GENERAL_MODELLING_PRINCIPLE`, `ANIMO_RELEVANT`, `BACKPORT_TO_SWAP5`

A corrected legacy reference is necessary for behavioural regression, but theory, documentation and implementation must still be reconciled independently.

### LR-005 Documentation must be qualification evidence

**Tags:** `GENERAL_MODELLING_PRINCIPLE`, `ANIMO_RELEVANT`, `BACKPORT_TO_SWAP5`

Model documentation should not be reconstructed only after coding is complete. Scientific meaning, implementation mapping, applicability, parameters, variables and evidence must evolve with the qualified source.

### LR-006 Design for Status A to Status AA maturity

**Tags:** `GENERAL_MODELLING_PRINCIPLE`, `ANIMO_RELEVANT`, `BACKPORT_TO_SWAP5`

Status A is an intermediate milestone. Development should preserve the provenance, traceability, uncertainty evidence, reviewability and management information needed for later Status AA maturity.

### LR-007 Reduce interfaces by modelling ownership, not by hiding dependencies

**Tags:** `GENERAL_MODELLING_PRINCIPLE`, `ANIMO_RELEVANT`, `FUTURE_ONLY`

Large legacy argument lists should be audited before they are replaced. Modern data structures should make coherent ownership explicit rather than moving dependencies into mutable global state or one oversized context object. For current qualified SWAP5, this principle is diagnostic unless a concrete defect or approved architecture change requires production modification.

### LR-008 Precision is explicit numerical policy

**Tags:** `GENERAL_MODELLING_PRINCIPLE`, `ANIMO_RELEVANT`, `BACKPORT_TO_SWAP5`

Kinds, mass-accounting precision and exchange precision should be explicit. Mixed-precision or lower-precision execution is an evidence-requiring numerical-policy change, not a transparent implementation cleanup.

## New-entry template

```text
ID:
TITLE:
TAGS:
ORIGIN / WORKSTREAM:
OBSERVATION:
GENERAL LESSON:
CURRENT SWAP5 ACTION:
ANIMO OR COUPLING RELEVANCE:
EVIDENCE / REFERENCES:
STATUS:
```
