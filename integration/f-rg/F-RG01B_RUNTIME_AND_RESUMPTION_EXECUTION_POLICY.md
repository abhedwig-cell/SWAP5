# F-RG01B — SWAP5 Workunit Runtime & Resumption Execution Policy

Policy ID: `F-RG01B-RREP`

Policy version: `1.0.0`

Status: `NORMATIVE_PROGRAM_GOVERNANCE_ADDENDUM`

Parent governance authority: `regie/f-rg01a-parallel-research-isolation-contract-ownership-policy@4553204468695553cf69a48d1c97598c471156d6`

Parent F-RG01A tree: `87c65fe9f094461376e073db88349952c1ecee60`

Original program authority: `regie/f-rg01-post-rb1-program-rebaseline@09ef05c60c5e45af218980001c8ad8ec30da2e9e`

Current-canonical snapshot at establishment: `integration/f-ci-canonical@2a0db2524fba6e258316ce82630c60ea1c9c673a`

Current-canonical snapshot purpose: program-state reference only. This policy changes no production canonical.

Exit target: `QUALIFIED_RUNTIME_AND_RESUMPTION_EXECUTION_POLICY_ESTABLISHED`

## 1. Authority and scope

This document is a normative governance addendum to F-RG01 and F-RG01A. It governs how a scientifically and architecturally coherent SWAP5 workunit may be executed when one ChatGPT execution, tool session or runtime window is insufficient to complete the whole workunit safely.

The policy changes neither the SWAP Core Architecture Invariants nor the scientific scope of any existing workunit. It changes no production source, reopens neither RB1 nor completed qualifications, and does not alter production admission criteria.

Its central rule is:

> The substantive scope of a workunit is determined by scientific and software-architectural coherence, not by the runtime available to one execution chunk.

A workunit may therefore span multiple execution chunks without being split into artificial pseudo-workunits merely to fit one runtime window.

## 2. Definitions

### 2.1 Workunit

A workunit is the governed unit of scientific, architectural, implementation or qualification scope. Its identity, ownership, authority chain, exit criteria and qualification target persist across execution chunks.

A runtime interruption does not create a new workunit.

### 2.2 Execution chunk

An execution chunk is one bounded period of active execution within the same workunit. A chunk may correspond to one ChatGPT run, one tool session or another practical execution window.

Execution chunks are implementation logistics, not scientific scope boundaries.

### 2.3 Durable checkpoint

A durable checkpoint is a repository-backed or otherwise explicitly persisted state from which the same workunit can resume without reconstructing already settled work from scratch.

A checkpoint is only durable when the information needed for safe continuation is recorded explicitly and can be independently inspected.

### 2.4 Moving and frozen authority

The definitions from F-RG01A remain in force.

A frozen authority is pinned and need not be rediscovered merely because a new execution chunk starts.

A moving authority may require a targeted live recheck at resumption if its movement can materially affect the remaining work.

## 3. Normative runtime principle

Runtime limitations may influence execution strategy, checkpoint frequency, batching, ordering and the size of one execution chunk.

Runtime limitations may not by themselves:

- redefine the scientific scope of the workunit;
- remove required verification;
- weaken qualification criteria;
- turn a coherent workunit into unrelated smaller workunits;
- force a premature production admission;
- justify skipping authority or ownership checks;
- justify repeating already qualified work without cause.

When one execution chunk is insufficient, the correct response is normally to persist a resumable checkpoint and continue the same workunit in a later chunk.

## 4. Meaningful execution phases

Where useful, a workunit should be divided into meaningful phases such as:

1. authority and reconnaissance;
2. semantic-contract or design specification;
3. implementation or composition;
4. verification and qualification;
5. closeout and authority publication.

These phases are examples, not mandatory labels. A workunit may use a different phase structure when the technical problem requires it.

Phase boundaries should follow meaningful dependency or risk boundaries rather than arbitrary token, time or chat limits.

A phase may itself require multiple execution chunks.

## 5. Mandatory resumability record

Before ending an execution chunk that leaves the workunit incomplete, persist enough state to allow safe continuation.

The checkpoint record must contain, where applicable:

- workunit ID and title;
- workunit scope and explicit non-scope;
- current phase and phase status;
- governing authority or authorities;
- exact pinned commit SHAs, trees or immutable tags already established;
- current-canonical SHA if current canonical is relevant to the remaining work;
- semantic contracts consumed by the workunit;
- semantic contracts owned or modified by the workunit;
- relevant `FROZEN` or `MOVING` contract classification under F-RG01A;
- decisions already taken and their rationale;
- files added, changed or deliberately left untouched;
- commits already created;
- tests, workflow runs, comparisons or qualification steps already executed and their results;
- unresolved findings or blockers;
- exact next safe action;
- any live authority that must be rechecked on resumption;
- any authority that is frozen and therefore must not be unnecessarily reconstructed.

The record may be a dedicated checkpoint/status artifact, an authoritative phase record, or another repository-backed artifact suitable for the workunit. The format is less important than completeness, exactness and inspectability.

## 6. Checkpoint before long or risky work

Long-running, high-risk or state-changing steps should normally begin only after prior work has been durably checkpointed.

Examples include:

- large recomposition or integration steps;
- production-source modifications after a substantial reconnaissance phase;
- long qualification suites;
- broad current-canonical comparison runs;
- multi-step migration or remediation sequences;
- admission preparation where a wrong authority choice would invalidate downstream work;
- changes to a moving semantic contract with multiple consumers.

This rule is intended to bound loss from runtime interruption. It does not require a commit after every trivial action.

Checkpoint granularity should be proportional to the cost and risk of reconstructing the completed work.

## 7. Resumption protocol

When resuming an interrupted workunit:

1. load the latest durable checkpoint;
2. verify that the checkpoint belongs to the intended workunit and authority chain;
3. recheck only external authorities that were explicitly moving or whose movement can materially affect the remaining work;
4. retain frozen/pinned authorities unless there is evidence that the checkpoint itself was invalid;
5. verify that already-created commits and changed files still exist at the recorded SHAs;
6. continue from the recorded next safe action;
7. do not repeat completed verification merely because the execution environment is new;
8. repeat earlier work only when a changed authority, failed preservation check, discovered defect or invalid checkpoint gives a technical reason to do so.

A new execution chunk must distinguish between `resume verification` and `full reconstruction`. Full reconstruction is not the default.

## 8. Runtime interruption does not invalidate prior work

A timeout, tool disconnect, ChatGPT runtime boundary or other execution interruption does not by itself invalidate:

- an exact authority already pinned;
- a committed design decision;
- a committed implementation step;
- a completed passing test whose tested SHA remains unchanged;
- an independent qualification already completed against an immutable candidate;
- a durable governance or checkpoint artifact.

Invalidation requires a substantive reason, such as changed moving authority, changed candidate contents, failed ancestry, discovered semantic conflict, failed test preservation or incorrect prior evidence.

## 9. No artificial scope compression

Workunit prompts and execution plans must not be made scientifically smaller solely to increase the probability that one ChatGPT run finishes before a runtime limit.

If the natural workunit requires several phases, the workunit should remain intact and use resumable execution chunks.

Conversely, this policy must not be used to make workunits arbitrarily large. Normal workunit boundaries still follow scientific and architectural cohesion, single-owner semantics, reviewability and bounded qualification scope.

The test is therefore not “can one run finish it?” but “does this form one coherent unit of authority, ownership and verification?”

## 10. Relationship to F-RG01A contract ownership policy

F-RG01A remains fully applicable across execution chunks.

An execution interruption does not release or duplicate semantic-contract ownership.

When a workunit resumes:

- its previously declared owned contracts remain owned by that workunit unless an explicit handoff occurred;
- a new concurrent workunit may not seize the same moving contract merely because the original workunit is between execution chunks;
- `SAFE_PARALLEL`, `PARALLEL_AFTER_PINNING` and `SERIAL_REQUIRED` decisions remain based on semantic ownership, not on whether a chat is currently running;
- if a moving contract changed during the pause, the resuming workunit must re-evaluate the relevant parallel-workstream gate before modifying that contract further.

A paused but not closed workunit can therefore still be an active semantic owner.

## 11. Relationship to production admission and qualification

Execution chunks do not create partial production authority.

A workunit may leave intermediate implementation or qualification checkpoints, but production status changes only through the existing authority chain and explicit exit criteria.

In particular:

- `in progress` is not `qualified`;
- a checkpoint is not an admission candidate unless explicitly frozen as one;
- an interrupted qualification may resume, but only completed evidence may be used for a qualification claim;
- a partially completed canonical admission must fail closed until its prescribed promotion and preservation gates are complete;
- current canonical may never be inferred from a workunit checkpoint.

## 12. Recommended phase states

For long workunits, checkpoint artifacts should use clear states such as:

- `IN_PROGRESS_RECONNAISSANCE`
- `IN_PROGRESS_CONTRACT_SPECIFICATION`
- `IN_PROGRESS_IMPLEMENTATION`
- `IN_PROGRESS_VERIFICATION`
- `IN_PROGRESS_CLOSEOUT`
- `CHECKPOINTED_FOR_RESUMPTION`
- `BLOCKED`
- the workunit-specific qualified exit state

These states describe execution progress only. They do not replace research maturity states from F-RG01A or production-admission states.

## 13. Prompt requirement for substantial workunits

Future SWAP5 workunit prompts expected to involve substantial multi-step execution should state, directly or by reference to this policy:

- that workunit scope is defined by scientific/architectural cohesion, not one-run runtime;
- that multiple execution chunks are permitted;
- the intended major phases where they are reasonably foreseeable;
- that each meaningful phase or risky transition must leave a durable resumable checkpoint;
- what must be persisted at checkpoint;
- that resumption should recheck moving authorities selectively rather than reconstructing everything;
- that runtime interruption does not automatically invalidate prior completed work.

This requirement complements, rather than replaces, the F-RG01A parallel-workstream gate.

## 14. Practical execution guidance

The preferred execution pattern for a substantial workunit is:

```text
pin authority
   -> persist checkpoint
   -> specify contracts/design
   -> persist checkpoint
   -> implement/compose bounded change
   -> persist checkpoint
   -> verify/qualify
   -> persist evidence
   -> close authority
```

The exact number of checkpoints is not prescribed.

If a workunit is simple enough to complete safely in one execution chunk, this policy does not require artificial checkpoint commits.

If a run approaches a practical execution limit, prefer closing the current meaningful phase and persisting state over beginning a new high-risk phase that cannot be made resumable.

## 15. Architecture and scientific integrity consequences

This runtime policy is intentionally subordinate to substantive correctness.

It must preserve:

- one-kernel architecture;
- clean solver/process/runtime boundaries;
- transactionality and rollback guarantees;
- hard mass conservation;
- reference-mode availability;
- MultiSWAP correctness;
- qualification independence;
- current-canonical admission discipline;
- F-RG01A semantic-contract ownership rules.

No scientific or architectural requirement becomes optional because it spans multiple execution chunks.

## 16. Governance preservation

This policy deliberately does not:

- modify `integration/f-ci-canonical`;
- modify production source;
- reopen RB1;
- reopen existing scientific qualifications;
- alter the SWAP5-v1 completion denominator;
- change RossFast maturity or production status;
- weaken any F-RG01A ownership classification;
- authorize asynchronous/background execution outside explicitly invoked execution chunks.

Future changes to this policy require a new versioned governance authority. Historical versions remain reproducible.

## 17. Exit condition

This policy is established when:

1. the versioned governance artifact is committed on a branch descended from the exact F-RG01A authority;
2. its definition commit and tree are pinned in a status/closeout artifact;
3. the establishment current-canonical snapshot is recorded;
4. the diff is governance-only;
5. future substantial workunit prompts can cite this authority for multi-chunk execution and resumability;
6. the exact target is recorded as:

`QUALIFIED_RUNTIME_AND_RESUMPTION_EXECUTION_POLICY_ESTABLISHED`
