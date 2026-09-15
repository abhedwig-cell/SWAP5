# Workstream execution and recovery protocol

## Purpose

Long-running development, verification and qualification work must remain recoverable when a tool, test runner, chat session or execution environment stops unexpectedly. Git is the durable system of record. Chat reasoning, an uncommitted worktree and transient tool state are not recovery points.

The governing rule is:

```text
persist early, test second
```

This protocol applies to all SWAP5 workstreams and work units, including F-CI and F-MQ.

It operates together with the [Status A to Status AA quality governance](quality-governance-a-aa.md). The execution protocol protects recoverability; the quality policy additionally governs scientific traceability, documentation, precision policy, parallel ownership and long-term model-quality evidence.

## Required state model

A work unit must distinguish these states explicitly:

- **implemented**: the intended change exists in a working tree or generated artifact;
- **persisted**: the recoverable postimage and its status metadata are committed to Git;
- **tested**: the declared focused checks have completed successfully against that persisted postimage;
- **qualified**: all gates required for admission of the work unit have completed successfully and their evidence is versioned;
- **blocked**: the next required action cannot currently be completed and the dependency is recorded.

These states are not interchangeable. In particular, a checkpoint commit is not evidence that a change is tested or qualified.

## Mandatory checkpoint before timeout-sensitive work

Before starting a timeout-sensitive or otherwise expensive operation, the preceding useful work must already be recoverable from Git.

Examples include:

- full or broad compilation runs;
- regression suites;
- long SWAP reference runs;
- MultiSWAP scale, concurrency or isolation tests;
- performance benchmarks;
- large repository-wide analyses or transformations;
- any operation whose interruption would otherwise require reconstructing non-trivial work.

A checkpoint must contain, directly or through versioned work-unit metadata:

```text
WORKSTREAM
WORK UNIT
BASELINE
CHECKPOINT COMMIT
FILES / ARTIFACTS PERSISTED
IMPLEMENTATION STATUS
TEST STATUS
QUALIFICATION STATUS
DOCUMENTATION / QUALITY STATUS
SHARED CONTRACT CHANGE
NEXT EXPENSIVE ACTION
RECOVERY POINT
DEPENDENCIES / BLOCKERS
```

The checkpoint commit may be temporary in the eventual history. It must nevertheless be complete enough to resume safely.

## Lightweight checks before a checkpoint

Short structural checks may run before the checkpoint when they are cheap and reduce the risk of persisting a trivially broken postimage. Examples are syntax checks, schema validation or a small focused unit test.

They do not replace the checkpoint. Long or broad gates run only after the useful postimage has been persisted.

## Remote persistence

When work is being performed in a local or disposable environment, a local commit alone is not the strongest recovery boundary. Before a costly operation, the checkpoint should also be pushed to the workstream branch unless there is a documented reason not to do so.

For work performed directly through the GitHub repository interface, a successful repository commit already provides remote persistence.

## Work-unit status record

Material work units should maintain a versioned status record close to their other integration or qualification artifacts. Existing workstreams may keep their current naming convention, for example:

```text
integration/f-ci/F-CI07_STATUS.json
integration/f-mq/F-MQ01_STATUS.json
```

The exact serialization may differ, but the record must make the recovery boundary unambiguous. At minimum it must state:

```text
work_unit
baseline
checkpoint_commit
implemented
persisted
tested
qualified
documentation_status
shared_contract_change
next_action
recovery_point
blockers
```

A status record must not claim `tested` or `qualified` before the corresponding gate has actually completed.

For a material parallel workstream that can affect a shared integration surface, the status or handoff record must also identify its merge contract as defined in the quality governance policy: owned production surface, read-only shared contracts, interfaces permitted to change, interfaces held fixed, dependencies, expected integration point and required qualification.

## Recovery after interruption

After a timeout, aborted tool call, lost runner or interrupted chat, resume from repository state rather than reconstructing from memory.

Recovery order:

1. Re-read the current workstream branch and exact HEAD commit.
2. Read the latest work-unit status record and recovery point.
3. Confirm that the referenced checkpoint postimage exists in Git.
4. Preserve already-persisted source and evidence.
5. Re-run only the action that was incomplete or whose result was not durably recorded.
6. Do not repeat source reconstruction or redesign merely because the previous execution session disappeared.
7. If repository state and chat history disagree, repository state wins.

A normal recovery statement should be concrete, for example:

```text
Work unit: F-CI07
Recovery commit: <sha>
Persisted: yes
Focused tests: passed
Qualification gate: incomplete
Next action: rerun qualification gate from the persisted postimage
```

## Commit discipline

Checkpoint commits should use a recognizable message, for example:

```text
checkpoint(F-CI07): persist trial capsule before regression
checkpoint(F-MQ01): persist deterministic harness before scale gate
```

Final qualification commits remain separate when useful. Checkpoint commits may later be squashed or reorganized during canonical integration, provided the qualified lineage remains reconstructible.

## Shared-semantics integration rule

Parallel development is permitted only while ownership and integration boundaries remain clear. The operational rule is:

```text
parallel where ownership is disjoint
serial where semantics are shared
```

Changes to shared state layout, canonical kernel/time contracts, transaction semantics, exchange types, numerical policy, mass-accounting infrastructure or common solver/runtime interfaces require an explicit integration point. A workstream must not silently widen its local scope when it discovers that one of these shared contracts must change.

## Documentation and scientific traceability at closeout

Before a material work unit is declared fully closed, determine whether it changes any of the following:

- scientific or formal model meaning;
- parameter or variable semantics;
- state ownership;
- coupling or exchange contracts;
- numerical or precision policy;
- applicability or operational behaviour.

If it does, the corresponding canonical documentation or discrepancy record must be updated, or the documentation/quality status must remain explicitly open. Passing executable tests alone is not sufficient to erase a known documentation gap.

## Relation to architecture invariants

This is a development and qualification execution protocol. It does not change SWAP physics, numerical policy, transactional semantics, runtime semantics or the Core Architecture Invariants.

The architecture invariants define what the system must mean. This protocol defines how development work is persisted and recovered safely while reaching that system. The Status A to Status AA quality governance defines how scientific traceability, evidence, documentation and model-quality maturity are accumulated without retrospectively reconstructing them.

## Minimum rule for every new work unit

No material work unit is allowed to depend on a long-running gate while its only useful postimage exists in transient chat state or an uncommitted worktree.

Before such a gate starts, answer all three questions with a concrete repository reference:

1. What exact postimage is safe?
2. At what Git commit can work resume?
3. What is the single next incomplete action?

If those answers are not yet available, create the checkpoint first.
