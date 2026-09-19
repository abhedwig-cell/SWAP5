# F-ROM-LARE bounded execution and recovery protocol

## Purpose

This protocol exists because interactive research sessions can terminate before a large autonomous work block is fully reported. Repository state must therefore remain sufficient to resume without repeating already-qualified scientific work.

This is an execution/governance protocol only. It changes no hydrology, numerical method, acceptance criterion, or scientific decision rule.

## Core rule

**Persist scientific authority before starting the next expensive scientific question.**

A completed calculation that exists only in chat context is not a checkpoint.
A completed GitHub Actions run that has only an ephemeral log is not the preferred checkpoint.
The durable checkpoint is a small repository result/status file that binds:

- preregistration;
- immutable input/evidence hashes;
- workflow/artifact authority where applicable;
- scientific decision;
- whether the result is complete, blocked, or outside domain;
- the exact next authorized work unit.

Large raw evidence may remain in GitHub Actions artifacts. The repository result stores the hashes and interpretation needed to recover it.

## Maximum work-unit granularity

Default execution policy for this branch:

1. one scientific question per workflow;
2. one independent case or parameter slice per matrix job;
3. default per-case timeout <= 15 minutes;
4. aggregate/adjudication jobs should normally be <= 5 minutes;
5. long panels are sharded rather than run serially;
6. each case writes a structured JSON outcome before upload;
7. case artifacts use `if: always()` where a structured blocked/negative result is meaningful;
8. aggregation consumes case artifacts and does not recompute the underlying cases.

A longer job requires an explicit reason in its preregistration or workflow.

## Supersession policy

Research workflows that are invalidated by a newer commit use workflow-level concurrency with:

`cancel-in-progress: true`

This prevents multiple obsolete versions of the same diagnostic from running concurrently.

Cancellation of a superseded run is not a scientific failure.

## Resume algorithm after timeout or new chat

Always follow this order:

1. Read `integration/f-rom/LARE_RS1_RECOVERY_CHECKPOINT.json`.
2. Reconcile its recorded branch head with the live branch head.
3. For the current work unit, first check whether its durable `*_RESULT.json` already exists.
4. If a durable result exists and its authority hashes still match, **do not rerun the calculation**.
5. If no durable result exists:
   - inspect the latest relevant Actions run;
   - if the aggregate result artifact exists, persist/adjudicate only that artifact;
   - otherwise inspect per-case artifacts;
   - rerun only missing/invalid cases;
   - aggregate from already-qualified case artifacts whenever possible.
6. Never regenerate a qualified predecessor merely because the current interactive session lost context.
7. Update the recovery checkpoint before launching the next expensive work unit.

## Negative and blocked outcomes

A structured negative or blocked result is a valid checkpoint when preregistered.

Examples:

- `OUTSIDE_QUALIFIED_DOMAIN`;
- `DIAGNOSTIC_BLOCKED`;
- `MORE_STATE_INFORMATION_REQUIRED`;
- an explicitly preregistered case-level blocked result.

Do not repeatedly rerun a scientifically blocked case unless a later work unit changes the missing authority or input.

## Repository vs artifact storage

Persist in Git:

- preregistration;
- compact result/adjudication;
- hashes/digests;
- small pair/case manifests required for deterministic continuation;
- recovery checkpoint;
- next-step authority.

Keep in Actions artifacts when large:

- full trajectories;
- large per-step traces;
- large diagnostic tables;
- compiler/stdout replicas.

A persisted result must contain enough provenance to recover the exact artifact.

## Commit cadence

For multi-stage research, preferred cadence is:

`PREREGISTER -> EXECUTE CASE(S) -> PERSIST CASE/AGGREGATE RESULT -> UPDATE RECOVERY CHECKPOINT -> NEXT WORK UNIT`

Do not accumulate several unpersisted scientific conclusions and then commit them at the end.

## Current workflow hardening

The C3B, C4B and C4D workflows are hardened to:

- cancel superseded runs;
- use bounded per-case timeouts;
- use short aggregate jobs;
- preserve structured case evidence.

Future long-running LARE workflows should follow the same pattern by default.

## Interaction policy

Repository checkpoints are not interaction checkpoints.

If the scientific authority determines the next step, continue autonomously after persisting the current result. The purpose of smaller jobs is recoverability, not more permission requests.
