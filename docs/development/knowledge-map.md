# Repository knowledge map

## Purpose

This page tells developers and agents where to look for authoritative SWAP5 knowledge. It is a navigation layer, not a new source of architecture or scientific authority.

Do not copy detailed contracts into this page. Link to the owning document instead. This keeps one durable source for each decision, interface, status claim, and qualification result.

## Four questions to answer first

Before changing SWAP5, separate four questions that are often confused:

1. **What should the system mean?** Read architecture invariants, accepted ADRs, and accepted interface contracts.
2. **What is implemented now?** Read the exact branch and commit, source code, implementation-status records, and current integration artifacts.
3. **What is qualified?** Read verification policy and the named evidence for the exact claim.
4. **How may the work proceed safely?** Read workstream ownership and the execution/recovery protocol.

A document that answers one question does not automatically answer the others. In particular, target architecture is not implementation evidence, and a passing performance experiment is not physical qualification.

## Knowledge locations

| Question | Primary locations | What they establish |
| --- | --- | --- |
| Repository entry point | `AGENTS.md` | Agent behaviour, first-read order, and repository discipline |
| Architecture meaning | `docs/architecture/invariants.md` | Normative target architecture constraints |
| Accepted design rationale | `docs/decisions/` | Accepted architecture decisions and their reasons |
| Architecture overview | `docs/architecture/overview.md` | System decomposition and architectural context |
| Implementation status | `D3a_IMPLEMENTATION_STATUS_MAP.md`, `docs/architecture/implementation-status.md` | Evidence-based status of implemented architecture |
| Component ownership | `D3b_COMPONENT_OWNERSHIP_MAP.md`, `docs/architecture/component-map.md` | Current component and responsibility boundaries |
| Migration state | `D3c_LEGACY_TO_TARGET_MIGRATION_MAP.md`, `D3d_MIGRATION_SLICES_AND_GATES.md`, `docs/architecture/legacy-migration*.md` | Legacy-to-target migration slices, gates, and remaining work |
| Parallel work ownership | `docs/development/workstreams.md` | Workstream scope, integration boundaries, and shared-interface cautions |
| Safe execution and recovery | `docs/development/workstream-execution-protocol.md` | Persisted/tested/qualified state model and checkpoint discipline |
| Documentation semantics | `docs/development/documentation.md` | Status labels, architecture-change documentation, and docs validation |
| Verification policy | `docs/verification/principles.md`, `docs/verification/reference-baselines.md` | What counts as reference and qualification evidence |
| Specific qualification evidence | `docs/verification/`, work-unit evidence under `integration/` | Scope-specific test and qualification results |
| Performance evidence | `docs/performance/`, `benchmarks/` | Measured performance claims and benchmark definitions |
| Legacy reference | `docs/legacy/`, `reference/` | Named legacy baseline and preserved reference material |
| Active work-unit state | `integration/` | Versioned work-unit status, handoff, contract, and qualification artifacts |
| Actual executable behaviour | source, tests, build configuration on the exact Git commit | What the checked-out implementation actually contains |

## Authority is contextual

There is no useful single ordering in which one file type always outranks every other file type. Use the authority that owns the question.

For **accepted meaning and design**, architecture invariants, ADRs, and accepted contracts are authoritative. Source code that violates them indicates an implementation problem unless an accepted decision has changed the design.

For **current implementation**, the exact Git commit and its source are decisive. Status maps help locate and interpret that state, but they must not be used to deny code that is visibly present or claim code that is absent.

For **qualification**, the named evidence is decisive only within its declared scope. A unit test, regression run, numerical qualification, conservation gate, restart gate, and performance measurement establish different things.

For **work ownership and safe sequencing**, the workstream and recovery protocols apply. A chat instruction may initiate work, but it does not silently supersede accepted repository contracts.

## Conflict and staleness rule

When sources appear inconsistent:

1. Confirm the exact branch and HEAD commit.
2. Confirm that all compared documents belong to that repository state.
3. Identify which question each source is meant to answer: design, implementation, qualification, or workflow.
4. Prefer the owning accepted authority for that question.
5. If an accepted document is stale relative to implementation, record and repair the inconsistency. Do not resolve it by inventing a new interpretation.
6. If chat context conflicts with repository state, repository state wins.

Historical evidence remains valid as history, but it does not become evidence for a newer postimage without an explicit qualification link.

## Task-oriented read paths

### Soil-water solver or solver interface work

Read, at minimum:

- `docs/architecture/invariants.md`, especially the invariants on transactional stepping, mass conservation, alternative soil-water solvers, hydraulic interfaces, physical options versus numerical policy, and reference mode;
- the HY ownership and current integration boundary in `docs/development/workstreams.md`;
- relevant accepted solver/interface contracts and work-unit status under `integration/`;
- relevant verification evidence under `docs/verification/`;
- the production binding and tests on the exact target commit.

Do not infer a research-solver contract from production implementation details. If independent solver development needs a stable seam, that seam must be explicit and versioned.

### Transaction, restart, or committed/trial-state work

Read:

- transactional and state-related architecture invariants;
- applicable ADRs in `docs/decisions/`;
- TX workstream ownership and integration artifacts;
- restart and rollback qualification evidence;
- source and tests for committed versus trial ownership on the exact commit.

Never treat a rejected trial as harmless merely because final output looks correct. State ownership and rollback are separate correctness properties.

### Top or bottom boundary work

Read the current accepted boundary contract, its integration status, and qualification evidence before reading implementation details as design intent. Then trace production bindings and all dependent solver paths.

Boundary behaviour can touch physics, numerics, transaction semantics, coupling, restart, and mass accounting at once. A local green test is therefore not enough unless the accepted work-unit gate says it is.

### Verification work

Start with `docs/verification/principles.md` and `docs/verification/reference-baselines.md`. Preserve the distinction between legacy reproduction, corrected-reference qualification, hard conservation, restart/transaction correctness, and performance measurement.

Do not change production physics while constructing an oracle unless the work unit explicitly transfers ownership to an implementation stream.

### Performance work

Start with the MP ownership in `docs/development/workstreams.md` and the relevant `docs/performance/` contract. Preserve correctness gates independently from timing evidence. A faster path is not qualified merely because its outputs look close in one benchmark.

### Documentation or architecture work

Read `docs/development/documentation.md`, the existing ADR index, the affected invariants, and current implementation status. Mark new text explicitly as Baseline, Target architecture, Proposed, or Qualified where that distinction matters.

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
