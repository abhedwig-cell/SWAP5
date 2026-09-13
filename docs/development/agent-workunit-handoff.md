# Agent work-unit handoff contract

## Purpose

This page defines the handoff between SWAP5 development coordination and an execution agent such as Codex. It does not replace scientific authority, architecture decisions, workstream ownership or verification contracts. Its purpose is to make agent execution bounded, reviewable and recoverable.

The intended separation is:

```text
coordination / scientific review   -> define scope, authority and acceptance
repository documentation           -> durable project knowledge and authority
work-unit handoff                  -> bounded execution contract
execution agent                    -> inspect, implement, test and report
review / qualification             -> decide whether evidence is sufficient
integration / canonical adoption   -> separate acceptance step
```

An agent is not granted authority merely because it can edit the repository.

## Relationship to existing governance

This contract is subordinate to:

- the workstream ownership and integration rules in `workstreams.md`;
- the persistence and recovery rules in `workstream-execution-protocol.md`;
- the normative architecture invariants in `../architecture/invariants.md`;
- accepted ADRs in `../decisions/`;
- applicable verification contracts and evidence in `../verification/`;
- more specific versioned work-unit contracts and status records under `integration/`.

If these sources conflict materially, the execution agent must expose the conflict. It must not create a new interpretation merely to continue execution.

## Minimum input contract

A material agent work unit should enter execution with enough information to answer the following fields. A coordinator may provide them directly or point to versioned records that do.

```text
WORK UNIT:
PURPOSE:
BASELINE REF:
BASELINE SHA:
APPLICABLE AUTHORITY:
IN SCOPE:
OUT OF SCOPE:
SCIENTIFIC BEHAVIOUR CHANGE ALLOWED: yes / no / specifically bounded
SHARED INTERFACES THAT MAY CHANGE:
SHARED INTERFACES THAT MUST NOT CHANGE:
REQUIRED VERIFICATION:
STOP / ESCALATION CONDITIONS:
EXPECTED DELIVERABLES:
TARGET REVIEW / INTEGRATION REF:
```

`BASELINE SHA` is evidence of the actual starting point. A phrase such as `latest`, `current` or `canonical` is not by itself a reproducible baseline. When the work unit requests the current value of a ref, resolve it live immediately before execution and record the resulting SHA.

The handoff should distinguish authority from historical context. A previous prompt, chat summary or old branch may explain why a decision exists without being allowed to override the accepted repository state.

## Execution phases

A work unit may be executed over multiple agent runs. The phase boundaries should follow technical meaning rather than arbitrary elapsed time. A typical sequence is:

1. **Authority and baseline check**
   - resolve the exact baseline;
   - read the work-unit contract and applicable authority;
   - identify affected invariants, owners and dependent contracts;
   - state any conflict before editing.

2. **Repository reconnaissance**
   - locate the production path, tests, status/evidence records and relevant history;
   - verify assumptions from the handoff against current repository state;
   - narrow the change surface.

3. **Design or contract realization**
   - make only the changes authorized by the work unit;
   - record design decisions when repository governance requires an ADR or interface note;
   - keep research/trial behaviour separate from production authority unless adoption is explicitly in scope.

4. **Focused verification**
   - run the smallest authoritative checks that can reject an incorrect postimage quickly;
   - persist useful work before expensive gates, following the recovery protocol.

5. **Qualification or broader gates**
   - run only the named broader gates applicable to the work unit;
   - preserve exact commands, baselines and results where the qualification contract requires evidence.

6. **Completion handoff**
   - report exact repository state and evidence;
   - distinguish implemented, persisted, tested and qualified;
   - leave one explicit next safe step.

Not every work unit needs every phase, but omitted phases must not be silently claimed as complete.

## Scope control

Execution agents should be conservative about expanding scope.

A newly discovered defect or architectural weakness may be recorded without being fixed in the current work unit. Expand the implementation only when the existing scope and authority clearly permit it. Otherwise leave a bounded finding with the affected component, evidence and suggested owning workstream.

In particular, do not use a documentation, research, performance or verification work unit as an implicit route to change production physics.

## Checkpoint handoff

The durable checkpoint rules are defined in `workstream-execution-protocol.md`. For agent execution, a checkpoint summary should additionally make the current reasoning boundary visible:

```text
WORK UNIT:
WORKING BRANCH:
BASELINE SHA:
CHECKPOINT HEAD:
PHASE COMPLETED:
AUTHORITIES RE-READ:
FILES / ARTIFACTS PERSISTED:
KEY FINDINGS / DECISIONS:
FOCUSED CHECKS COMPLETED:
TEST / QUALIFICATION STATE:
OPEN FINDINGS OR BLOCKERS:
NEXT EXPENSIVE OR RISKY ACTION:
NEXT SAFE STEP:
```

The summary is useful metadata, but the Git commit is the recovery boundary. Never treat an uncommitted chat summary as the only copy of completed implementation work.

## Completion handoff

A material completion report should contain:

```text
WORK UNIT:
STARTING BASELINE:
FINAL WORKING BRANCH / HEAD:
SCOPE COMPLETED:
FILES / COMPONENTS TOUCHED:
INTERFACES CHANGED:
INVARIANTS AFFECTED:
SCIENTIFIC / NUMERICAL BEHAVIOUR CHANGE:
TESTS AND EXACT RESULT:
QUALIFICATION EVIDENCE:
KNOWN LIMITATIONS:
UNRESOLVED FINDINGS / AUTHORITY CONFLICTS:
REVIEW REQUIRED:
RECOMMENDED NEXT SAFE STEP:
```

Use explicit states:

- `implemented`: intended postimage exists;
- `persisted`: postimage is recoverable from Git;
- `tested`: named focused tests have passed against that postimage;
- `qualified`: all required admission gates and evidence are complete;
- `blocked`: a required dependency or gate prevents progress.

These states retain the meanings defined by the recovery protocol. An agent must not collapse them into a generic `done`.

## Review and adoption boundary

Execution completion is not canonical adoption.

Unless the work unit explicitly grants integration authority, the execution agent should stop with a reviewable branch, commit, diff and evidence. A reviewer or integration work unit then decides whether the result:

- matches the declared scope;
- respects applicable authority and invariants;
- has sufficient verification evidence;
- can be admitted without invalidating dependent work;
- needs rebase, further qualification or rejection.

This separation is especially important for scientific software: a technically valid patch can still be scientifically under-qualified or architecturally inconsistent.

## Recovery after agent interruption

When an agent run stops unexpectedly:

1. inspect the live work-unit branch and exact HEAD;
2. read the latest versioned work-unit status or checkpoint record;
3. verify which changes and evidence are already persisted;
4. resume at the single next incomplete action;
5. re-evaluate the baseline only when upstream authority has moved or the work unit requires a live-current baseline;
6. do not redo completed design or source reconstruction merely because the previous agent context disappeared.

If the upstream baseline has moved in a way that touches the work unit's authority, interface or verification assumptions, do not blindly continue. Record the drift and reassess the affected assumptions first.

## Why this contract is deliberately thin

SWAP5 already versions its architecture, decisions, verification rules and execution recovery protocol. Agent instructions should route execution into that knowledge rather than duplicate it. Keeping the agent layer thin reduces the risk that an old prompt or `AGENTS.md` becomes a competing source of truth.
