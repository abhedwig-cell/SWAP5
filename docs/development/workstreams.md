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
**Accepted integration baseline:** `ce280e110c637a087d2a1aabd70fca5f1d494e48`  
**Current integration branch:** `vq/vq-1-integration`  
**Current slices:** VQ-1a B0 identity, VQ-1b B0 runner hardening, VQ-1c B1 provenance gate

### Goal

Build an independent verification layer that can increasingly serve as the acceptance gate for SWAP5 migration slices.

### Current scope

- exact B0 archive identity and provisional exact-source execution;
- case-specific B0 regression and repeatability evidence;
- canonical legacy BAL/BLC extraction while explicitly rejecting rounded reports as the future hard mass oracle;
- unrounded, transaction-aware mass-accounting verification contract;
- fail-closed B1 snapshot provenance checking before B0 -> B1 numerical comparison;
- later, transaction, warm-start and generic-time gates against integrated B2/TX interfaces.

### Current integration boundary

VQ changes no production kernel, solver, runtime or coupling physics. The GNU B0 runner is capability-limited and is not declared equivalent to the packaged Intel executable. B1.4 at the accepted integration baseline fails the VQ provenance gate because several stored patch artifacts do not match snapshot-declared hashes and SWAP-007 also declares a B0 preimage hash inconsistent with canonical B0. Numerical B0 -> B1 qualification therefore remains blocked until a provenance-correct immutable B1 snapshot is available.

The proposed unrounded mass-accounting record is a verification interchange contract only. TX/HY/runtime own any production result-interface implementation.

### Deliberate exclusions

VQ does not redesign production physics or solver algorithms. When a discrepancy is found, VQ reproduces and classifies it, then hands it to the appropriate implementation or legacy-reference path.

## Active workstream MP: MultiSWAP performance and batchability

**Status:** Active  
**Accepted baseline:** `3b19f079a0a744e576f752c4b3e0d7e7ac72603b`  
**Current slice:** MP-4, [workload and benchmark catalog](../performance/mp-4-workload-catalog.md)

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

### Current integration boundary

MP-1 defined the measurement architecture and record. MP-2 integrated measurement-only collection and aggregation tooling without changing production interfaces. MP-3A qualified the mechanics of a coarse observation seam in a disposable B0 shadow build, including measurement-disabled versus measurement-enabled equality for selected Hupsel physical outputs.

MP-4 now versions the six benchmark families as an explicit workload catalog. It locks the official Staringreeks 2018 B12 hydraulic row as a `parameter-locked` stress profile but does not invent the missing full executable case. Homogeneous scaling, mixed templates, execution-class routing and optional-physics comparisons remain blocked until their owning RT/HY/VQ interfaces and qualifications exist.

The intended SWAP5 production observer is still pending because no stable integrated TX/HY production source seam is yet available in this repository. Stable template/execution identifiers remain owned by RT, solver phase events by HY, transaction events by TX and correctness/mass-balance gates by VQ.

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
