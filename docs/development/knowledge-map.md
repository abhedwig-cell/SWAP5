# Repository knowledge map

## Purpose

This page tells developers and agents where to look for authoritative SWAP5 knowledge. It is a navigation layer, not a new source of architecture or scientific authority.

Do not copy detailed contracts into this page. Link to the owning document instead. This keeps one durable source for each decision, interface, status claim, and qualification result.

## Current Status-A entry point

For present-state questions, begin with the Status-A layer:

- `docs/status-a/CURRENT_STATUS.md` for admitted capability and scope;
- `docs/status-a/CURRENT_ARCHITECTURE.md` for actual current ownership and execution boundaries;
- `docs/status-a/TRACEABILITY.md` for theory / contract → production → qualification → admission → preservation;
- `docs/status-a/FUTURE_SCOPE.md` for deliberately non-admitted work.

These pages are anchored to current Status-A authority `992a5c657bfe10a10100f92e0cb77c4825ae65b6` and scientific production baseline `50346642bd565f79134ea17d5462e544b354998c`.

Older architecture status and component maps dated 2026-09-04 are retained as migration/target-design evidence. They do not override the Status-A layer for current-state claims.

## Four questions to answer first

Before changing SWAP5, separate four questions that are often confused:

1. **What is admitted now?** Read the current Status-A scope and architecture, then the exact target branch/commit.
2. **What should a specific capability mean?** Follow its scientific/architectural contract and accepted decisions through the Status-A traceability map.
3. **What is qualified and preserved?** Read the named capability evidence, canonical admission and preservation authority for the exact dependency surface.
4. **How may the work proceed safely?** Read workstream ownership and the execution/recovery protocol.

A document that answers one question does not automatically answer the others. In particular, target architecture is not implementation evidence, a historical migration status is not current Status-A status, and a passing performance experiment is not physical qualification.

## Knowledge locations

| Question | Primary locations | What they establish |
| --- | --- | --- |
| Repository entry point | `AGENTS.md` | Agent behaviour, first-read order, and repository discipline |
| Current Status-A scope | `docs/status-a/CURRENT_STATUS.md` | Current admitted capability denominator and bounded claims |
| Current architecture / ownership | `docs/status-a/CURRENT_ARCHITECTURE.md` | Actual Status-A state, execution, persistence, orchestration and coupling ownership boundaries |
| Current theory-code-evidence navigation | `docs/status-a/TRACEABILITY.md` | How distributed capability authority connects contract, implementation, qualification, admission and preservation |
| Current future/non-admitted scope | `docs/status-a/FUTURE_SCOPE.md` | Explicit work that is not currently admitted and is not automatically a blocker |
| Architecture invariants / target meaning | `docs/architecture/invariants.md`, accepted ADRs | Normative architectural constraints and accepted design rationale where applicable |
| Historical implementation status | `D3a_IMPLEMENTATION_STATUS_MAP.md`, `docs/architecture/implementation-status.md` | 2026-09-04 migration snapshot; historical evidence, not current Status-A status |
| Target component ownership | `D3b_COMPONENT_OWNERSHIP_MAP.md`, `docs/architecture/component-map.md` | Target-design ownership map; use current Status-A architecture for implemented/current boundaries |
| Migration state/history | `D3c_LEGACY_TO_TARGET_MIGRATION_MAP.md`, `D3d_MIGRATION_SLICES_AND_GATES.md`, `docs/architecture/legacy-migration*.md` | Legacy-to-target migration slices, gates, and historical remaining-work statements in their dated context |
| Parallel work ownership | `docs/development/workstreams.md` | Workstream scope, integration boundaries, and shared-interface cautions |
| Safe execution and recovery | `docs/development/workstream-execution-protocol.md` | Persisted/tested/qualified state model and checkpoint discipline |
| Documentation semantics | `docs/development/documentation.md` | Status labels, architecture-change documentation, and docs validation |
| Verification policy | `docs/verification/principles.md`, `docs/verification/reference-baselines.md` | What counts as reference and qualification evidence |
| Test-bank authority and inventory | `docs/verification/test-bank.md`, `docs/verification/test-bank-catalog.yaml` | Permanent test surfaces, registration status, test classes, traceability fields and lifecycle rules |
| Specific qualification evidence | capability evidence and qualification/integration records on the pinned commit | Scope-specific test and qualification results |
| Permanent/current-head preservation | `docs/status-a/TRACEABILITY.md` and the named capability/permanent-suite authorities | Which immutable, same-tree, moving-current or exact-head evidence protects an admitted capability |
| Performance evidence | `docs/performance/`, `benchmarks/` | Measured performance claims and benchmark definitions within their recorded scope |
| Legacy reference | `docs/legacy/`, `reference/` | Named legacy baseline and preserved reference material |
| Actual executable behaviour | source, tests, build configuration on the exact Git commit | What the checked-out implementation actually contains |

## Authority is contextual

There is no useful single ordering in which one file type always outranks every other file type. Use the authority that owns the question.

For **current Status-A scope**, the release-readiness/current canonical acceptance authority and later capability-specific canonical closures are decisive. Earlier migration and target-design records remain historical evidence only.

For **accepted meaning and design**, capability scientific contracts, architecture invariants, ADRs, and accepted interface contracts are authoritative within their declared scope. Source code that violates an accepted current contract indicates an implementation problem unless a later accepted decision changed that contract.

For **current implementation**, the exact Git commit and its source are decisive. The Status-A current architecture/status pages make that state navigable, but no narrative page may claim code that is absent from the named postimage.

For **qualification**, the named evidence is decisive only within its declared scope. A unit test, regression run, numerical qualification, conservation gate, restart gate, current-head preservation run and performance measurement establish different things.

For **work ownership and safe sequencing**, the workstream and recovery protocols apply. A chat instruction may initiate work, but it does not silently supersede accepted repository contracts.

## Conflict and staleness rule

When sources appear inconsistent:

1. Confirm the exact branch and HEAD commit.
2. Confirm that all compared documents belong to that repository state.
3. Identify which question each source is meant to answer: current scope, design/contract, implementation, qualification/preservation, or workflow.
4. For a current Status-A claim, prefer the current release-readiness/canonical acceptance authority over earlier migration snapshots.
5. For a capability-specific claim, follow the owning contract and evidence chain from `docs/status-a/TRACEABILITY.md`.
6. If an accepted current document is stale relative to implementation/evidence, record and repair the inconsistency. Do not resolve it by inventing a new interpretation.
7. If chat context conflicts with repository state, repository state wins.

Historical evidence remains valid as history, but it does not become evidence for a newer postimage without an explicit qualification or preservation link.

## Task-oriented read paths

### Soil-water solver or solver interface work

Read, at minimum:

- `docs/status-a/CURRENT_STATUS.md` and `docs/status-a/CURRENT_ARCHITECTURE.md` for the current admitted boundary;
- `docs/architecture/invariants.md`, especially the invariants on transactional stepping, mass conservation, alternative soil-water solvers, hydraulic interfaces, physical options versus numerical policy, and reference mode;
- relevant accepted solver/interface contracts and qualification/admission records;
- the production binding and tests on the exact target commit.

Do not infer a research-solver contract from production implementation details. If independent solver development needs a stable seam, that seam must be explicit and versioned.

### Transaction, restart, or committed/trial-state work

Read:

- `docs/status-a/CURRENT_ARCHITECTURE.md` and the applicable traceability rows;
- transactional and state-related architecture invariants;
- applicable ADRs in `docs/decisions/`;
- restart/rollback qualification and preservation evidence;
- source and tests for committed versus trial ownership on the exact commit.

Never treat a rejected trial as harmless merely because final output looks correct. State ownership and rollback are separate correctness properties.

### Top or bottom boundary work

Read the current admitted boundary contract, its canonical admission and qualification/preservation evidence before reading implementation details as design intent. Then trace production bindings and all dependent solver paths.

Boundary behaviour can touch physics, numerics, transaction semantics, coupling, restart, and mass accounting at once. A local green test is therefore not enough unless the accepted work-unit gate says it is.

### Verification work

Start with `docs/status-a/TRACEABILITY.md`, `docs/verification/principles.md`, `docs/verification/reference-baselines.md` and `docs/verification/test-bank.md`. Use `docs/verification/test-bank-catalog.yaml` to locate the registered permanent test surfaces and their central traceability status. Preserve the distinction between legacy reproduction, corrected-reference qualification, hard conservation, restart/transaction correctness, current-head preservation and performance measurement.

Do not change production physics while constructing an oracle unless the work unit explicitly transfers ownership to an implementation stream.

### Performance work

Start with the current Status-A bounds, the relevant performance contract and applicable workstream ownership. Preserve correctness gates independently from timing evidence. A faster path is not qualified merely because its outputs look close in one benchmark, and F-PE11 is not a blanket whole-model or MultiSWAP speed claim.

### Documentation or architecture work

Read `docs/status-a/` first, then `docs/development/documentation.md`, the existing ADR index, affected invariants, and the relevant historical/target documents. Mark text explicitly as current/admitted, historical, target architecture, proposed or qualified where that distinction matters.

Do not rewrite a historical conclusion into a modern one. Add a supersession notice and point to current authority when historical wording can otherwise be mistaken for present state.

## Claim discipline

Use precise verbs:

- **exists** means the artifact is present on the named commit;
- **implemented** means the behaviour is present in the implementation;
- **persisted** means the relevant postimage is recoverable from Git;
- **tested** means the declared test completed against that postimage;
- **qualified** means the required acceptance gates completed and evidence is versioned;
- **canonical** means the project has admitted that state through its accepted integration process.

Do not collapse these terms into one another.

## Maintaining this map

Update this page only when the repository gains a new class of authority, relocates an existing authoritative source, or changes the normal read path materially.

Do not update it for every work unit. Work-unit detail belongs with the work unit. The goal is for this page to remain small, stable, and useful even as implementation work continues rapidly.