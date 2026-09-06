# Parallel development workstreams

## Purpose

SWAP5 is being rebuilt in several parallel technical threads. Parallelism is useful only when each thread has a clear scope, a known baseline and an explicit integration boundary. Git and the versioned documentation are the system of record. Chat history is supporting working context, not the authoritative source of the current code state.

The coordination rule is therefore:

```text
Git + accepted documentation = source of truth
project/chat context          = working context
individual chat               = temporary workbench
```

## Workstream rule

Every substantial development thread receives a short workstream ID. A workstream owns a technical scope, not a permanent set of files. Two workstreams may eventually touch the same file, but they should not concurrently redesign the same interface without an explicit integration point.

A workstream handoff or pull request records at least:

```text
WORKSTREAM
BASELINE
SCOPE
COMPONENTS/FILES TOUCHED
INTERFACES CHANGED
INVARIANTS AFFECTED
TEST/QUALIFICATION STATUS
DEPENDENCIES / REQUIRED INTEGRATION
NEXT SAFE STEP
```

`BASELINE` should normally be an exact Git commit or accepted tag. A statement such as "latest code" is not sufficient for parallel work.

## Integration rules

1. Do not treat an unmerged chat result as a project-wide fact.
2. Do not change a shared kernel interface silently. Record the decision in an ADR or an explicit interface note before dependent workstreams build on it.
3. Prefer workstreams that can be verified independently and merged in small slices.
4. Rebase or re-read the current integration baseline before a workstream begins a new slice after another stream has changed shared code.
5. A workstream that discovers a confirmed SWAP 4.3.1 bug follows the B0/B1/B2 reference policy. It does not reintroduce the bug in SWAP5 for compatibility.
6. Physical configuration and numerical execution policy remain separate even when a performance workstream is involved.
7. Rejected trials, fallback routes and performance shortcuts remain subject to the hard mass-balance and transactional-state invariants.

## Workstream registry

The exact mapping of existing chat threads to workstream IDs is made at their next integration point, because several current refactoring threads predate this coordination scheme. Until then, the following domains provide the canonical workstream vocabulary.

| ID | Domain | Typical ownership | Concurrent-change caution |
| --- | --- | --- | --- |
| `TX` | Transactional stepping and time orchestration | checkpoint, trial/retry, commit/rollback, generic interval control | shared state/result contracts |
| `HY` | Soil-water solver and hydraulic isolation | `HeadCalc`, Richards solver boundary, hydraulic service interfaces | solver state and Jacobian contracts |
| `RT` | Runtime, MultiSWAP and coupling composition | batching, templates, execution classes, MODFLOW coupling, worker scheduling | kernel API and state layout |
| `DOC` | Architecture, decisions and project documentation | ADRs, invariants, migration/status maps, reference policy | must describe merged or explicitly proposed state accurately |
| `VQ` | Verification and reference qualification | regression harnesses, B0/B1/B2 comparison, mass-balance and transaction gates | should avoid changing production physics while building the oracle |
| `MP` | MultiSWAP performance and batchability | profiling, memory footprint, template homogeneity, bounded-cost evidence | performance experiments must not silently change physics |

The registry is intentionally functional. A chat title or milestone code is not itself a workstream identity.

## Active workstream VQ: Verification and qualification

**Status:** Active  
**Initial baseline:** `40aef01c5c89dc9e02bba50d31c884dcdd2fd2d5`  
**Current slice:** `VQ-1`  
**Integration record:** `docs/verification/vq-1-bootstrap.md`

### Goal

Build an independent verification layer that can increasingly serve as the acceptance gate for SWAP5 migration slices.

### First scope

- establish executable regression cases against the exact B0 baseline and later B1 snapshots;
- encode hard water-balance checks;
- encode transaction checks for rollback, retry and commit;
- add generic-time tests with non-midnight starts and non-day intervals;
- record expected legacy differences through the difference ledger;
- make warm-start correctness independent of the numerical initial guess;
- provide reusable qualification outputs for other workstreams.

### Deliberate exclusions

VQ does not redesign production physics or solver algorithms. When a discrepancy is found, VQ reproduces and classifies it, then hands it to the appropriate implementation or legacy-audit path.

### Why it parallelizes well

Most work is in harnesses, test cases, comparison tooling and evidence. It can proceed while TX/HY/RT change production code, and it reduces the risk that several coding streams drift without a common oracle.

## Proposed new workstream MP: MultiSWAP performance and batchability

**Status:** Proposed

### Goal

Create a measured performance baseline for the new architecture before GPU or aggressive optimization choices are made.

### First scope

- measure CPU time by major solver/process category;
- measure persistent state and worker scratch memory separately;
- quantify cost distributions across large column sets rather than only averages;
- include difficult cases such as heavy-clay/B12-like columns and other known slow regimes;
- test the benefit of homogeneous model templates and execution classes;
- identify where column divergence causes batch slowdown;
- measure the cost and benefit of bounded-cost/fallback routes while enforcing exact water accounting;
- define a CPU baseline that later allows a meaningful GPU offload decision.

### Deliberate exclusions

The first MP phase is measurement-first. It does not introduce a GPU backend and does not alter physical formulations solely for speed.

### Why it parallelizes well

MP can operate mostly through profiling, benchmark drivers and representative configurations. It can provide evidence to RT and HY without competing with their main implementation ownership.

## When to add more workstreams

More parallel threads are useful only when they have a distinct deliverable and do not depend on the same unmerged interface. If coordination overhead or merge conflicts increase, reduce parallelism and integrate first.

As a practical default, four active implementation streams plus one or two mostly independent verification/performance streams is considered a manageable upper range until the integration process proves otherwise.

## Update discipline

At each material integration point, update this page when any of the following changes:

- a workstream becomes active, paused or complete;
- its scope or ownership boundary changes;
- a shared interface dependency is introduced;
- a proposed workstream is accepted;
- an integration gate is reached.

This page coordinates work. The architecture implementation status map remains the evidence-based record of what the project has actually implemented and qualified.