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
**Current qualified corrected-reference snapshot:** `B1.5p1`  
**Current slices:** VQ-1a through VQ-1c3 complete; next integration target is B1 -> B2 reference qualification

### Goal

Build an independent verification layer that increasingly serves as the acceptance gate for SWAP5 migration slices.

### Current scope

- exact B0 distribution and source identity;
- capability-limited exact-source GNU B0 execution and case-specific regression evidence;
- canonical legacy BAL/BLC normalization while explicitly rejecting rounded reports as the future hard mass oracle;
- unrounded, transaction-aware mass-accounting verification contract;
- fail-closed B1 snapshot, patch-artifact and canonical B0-preimage identity gates;
- deterministic byte-aware reconstruction of `B1.5p1` from exact B0;
- broad B0 -> B1 control edges;
- source-bound targeted qualification of all five admitted B1 corrections;
- explicit expected-difference registration for B0 -> B1.5p1.

### Current integration boundary

VQ changes no production kernel, solver, runtime or coupling physics. The GNU B0 runner is capability-limited and is not declared globally Intel-equivalent.

Historical B1.2-B1.5 remain immutable failed-provenance audit records. `B1.5p1` is the provenance-repaired replacement definition with the same five intended corrections. Independent VQ qualification now establishes:

```text
snapshot/provenance identity              PASS
canonical B0 preimages                    PASS
stored patch identities                   PASS
deterministic B1.5p1 reconstruction       PASS
all corrected-target SHA-256 gates        PASS
broad B0 -> B1 control edges              PASS
all five correction-triggering gates      PASS
```

VQ therefore qualifies `B1.5p1` as the numerical/behavioural corrected-reference oracle for B2 regression. This does not make rounded legacy `.BAL/.BLC` a machine-precision mass oracle. Hard mass conservation remains a separate fail-closed gate through the unrounded B2 accounting contract.

The proposed unrounded mass-accounting record is a verification interchange contract only. TX/HY/runtime own the production result-interface mapping.

### Deliberate exclusions

VQ does not redesign production physics or solver algorithms. When a discrepancy is found, VQ reproduces and classifies it, then hands it to the appropriate implementation or legacy-reference path.

### Why it parallelizes well

Most work is in harnesses, test cases, comparison tooling and evidence. It can proceed while TX/HY/RT change production code, provided reference identities and interface dependencies are re-read at each integration point.

## Active workstream MP: MultiSWAP performance and batchability

**Status:** Active  
**Accepted baseline:** `8eb863eadbae5f505188d2d6d9404c66fd1b1446`  
**Current slice:** MP-8, [isolated performance-runner contract](../performance/mp-8-isolated-runner-contract.md)

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

MP-4 versions the six benchmark families as an explicit workload catalog. It locks the official Staringreeks 2018 B12 hydraulic row as a `parameter-locked` stress profile but does not invent the missing full executable case. Homogeneous scaling, mixed templates, execution-class routing and optional-physics comparisons remain blocked until their owning RT/HY/VQ interfaces and qualifications exist.

MP-5 revalidated MP-B01 with clean byte-safe shadow builds and 18 interleaved paired cycles. It corrected a CRLF-sensitive shadow-injection tooling defect, versioned raw timing evidence and a deterministic summary, and found the measured top-level observer delta unresolved above the approximately 1.56% two-standard-error wall-time noise scale of the non-dedicated test host.

MP-6 separates monotonic elapsed time from actual child-process CPU time and introduces a predeclared CPU-baseline qualification protocol. A 1% resolution target led, from the MP-5 pilot, to 44 predeclared paired runs. With the child pinned to one logical CPU, all physical output hashes remained identical, but the measured child-CPU detection floor was about 2.57%, so the current shared host failed the 1% resolution gate.

MP-7 makes host quality an explicit admission gate. A baseline-only preflight across all five visible CPUs selected CPU3 deterministically because its child-CPU CV was about 0.81%. A separate ten-pair pilot fixed the final experiment at 21 pairs before examining the final effect. All 42 final runs preserved the qualified BAL/BLC hashes and no measured sample itself experienced cgroup throttling. The final child-CPU MDE improved to about 1.35%, but still failed the 1% target. In addition, the broader qualification window accumulated two cgroup throttling events (65,370 microseconds). The current shared host is therefore explicitly rejected for a 1% CPU baseline; no observer-overhead estimate or production CPU baseline is admitted.

MP-8 makes the missing performance infrastructure explicit. It defines a versioned isolated-runner contract, machine probe, operator-attestation boundary and manual self-hosted readiness workflow. The repository currently has no repository-visible `self-hosted` performance-runner configuration, while account-level runner inventory is not observable through the repository connector, so readiness is recorded fail-closed as `INFRASTRUCTURE_PENDING`. A future runner must prove CPU/cgroup/frequency/SMT/reference provisioning readiness first and then repeat the full MP-7 1% admission protocol; contract readiness alone cannot establish a CPU baseline.

The intended SWAP5 production observer is still pending because no stable integrated TX/HY production source seam is yet available in this repository. Stable template/execution identifiers remain owned by RT, solver phase events by HY, transaction events by TX and correctness/mass-balance gates by VQ. B12 remains `parameter-locked` until VQ provides a complete qualified difficult-column fixture. `B1.5p1` is now available as the qualified corrected-reference oracle for later B2/performance correctness comparisons, but that does not relax MP's independent hard mass-balance requirements.

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
