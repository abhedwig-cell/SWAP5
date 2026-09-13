# SWAP5 agent instructions

These instructions apply repository-wide. They are an execution routing contract, not a new source of scientific or architectural authority.

## Source of truth

Use repository state and accepted versioned documentation as the source of truth. Chat history, prompt summaries and uncommitted reasoning are working context only.

Before material work:

1. identify the work unit and its declared scope;
2. resolve the live baseline and record the exact commit SHA;
3. read the applicable accepted documentation and work-unit evidence;
4. identify affected architecture invariants, interfaces and verification gates;
5. report an authority conflict instead of resolving it silently.

Do not assume that a SHA copied into a prompt is still current when the task explicitly asks for current or canonical state. Re-read the relevant ref first.

## Repository map

Start with these documents, then narrow to task-specific authority:

- `docs/development/workstreams.md`: workstream scope, ownership and integration rules;
- `docs/development/workstream-execution-protocol.md`: checkpoint, persistence and recovery rules;
- `docs/development/agent-workunit-handoff.md`: agent handoff and completion contract;
- `docs/architecture/invariants.md`: normative architecture invariants;
- `docs/architecture/data-ownership.md`: data ownership boundaries;
- `docs/architecture/component-map.md`: component boundaries and ownership map;
- `docs/decisions/`: accepted architecture decisions;
- `docs/verification/principles.md`: verification and reference-chain rules;
- `docs/verification/`: qualification contracts and evidence;
- `integration/`: versioned work-unit status, integration and qualification artifacts.

A task-specific contract, ADR, status record or qualification artifact may be more specific than this routing file. `AGENTS.md` does not override it.

## Scientific and architectural discipline

- Do not introduce or change scientific behaviour unless the work unit explicitly places that change in scope.
- Do not silently change shared interfaces, state ownership, restart semantics, transaction semantics, numerical policy or coupling contracts.
- Rejected trials must not contaminate committed state.
- Mass conservation remains a hard requirement on accepted paths.
- Keep physical configuration separate from numerical execution policy.
- Alternative solver or research paths must not silently become production authority.
- When code, documentation and a declared authority disagree, surface the discrepancy and preserve evidence. Do not choose the convenient interpretation.

## Work unit versus execution unit

A scientific or engineering work unit does not have to fit in one agent run. Split execution into meaningful, recoverable phases when useful, without changing the work unit's scientific scope.

Before a long, expensive or timeout-sensitive operation, follow `docs/development/workstream-execution-protocol.md`: persist the useful postimage first and make the next incomplete action explicit.

After an interruption, resume from Git and versioned status/evidence. Do not reconstruct completed work from chat memory when a repository checkpoint exists.

## Change discipline

- Work on the work-unit branch or isolated worktree, never by silently advancing an integration or canonical ref.
- Keep scope narrow. Record dependencies instead of opportunistically fixing unrelated findings.
- An execution agent may prepare commits and pull-request evidence, but adoption into an integration/canonical branch is a separate review decision unless the task explicitly grants that authority.
- Preserve rejected or inconclusive results when they are relevant to later qualification.
- Do not label work `tested` or `qualified` until the named gates have actually completed against the persisted postimage.

## Verification

Use the verification commands and gates named by the applicable work unit and repository documentation. Do not invent a substitute test and call it equivalent.

For documentation-only changes, the repository documentation workflow currently defines:

```bash
python tools/docs/check_docs.py
mkdocs build --strict
```

If a required gate cannot run in the available environment, report it as not run or blocked, with the reason. Do not convert absence of evidence into a pass.

## Completion handoff

A material handoff must make the next reviewer or agent able to continue without reconstructing the session. Report at least:

```text
WORK UNIT
BASELINE
WORKING BRANCH / HEAD
SCOPE COMPLETED
FILES / COMPONENTS TOUCHED
INTERFACES CHANGED
INVARIANTS AFFECTED
TEST / QUALIFICATION STATUS
UNRESOLVED FINDINGS OR AUTHORITY CONFLICTS
NEXT SAFE STEP
```

For the fuller input, checkpoint and completion templates, use `docs/development/agent-workunit-handoff.md`.
