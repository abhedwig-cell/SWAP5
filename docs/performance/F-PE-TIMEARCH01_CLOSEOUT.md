# F-PE-TIMEARCH01 closeout — timestep architecture audit and redesign decision

Date: 2026-09-28

Final status:

`QUALIFIED_TIMESTEP_ARCHITECTURE_REDESIGN`

Canonical authority:

`integration/f-ci-canonical@3b94726fe7d01aec42a5a53587769f38916203f4`

## Decision

The current timestep architecture should be redesigned before further production tuning of DTMIN/DTMAX or related heuristics.

This is an architecture decision, not a claim that the TimeControl routine itself consumes material runtime.

The performance cost arises from the intervals selected by the control architecture, not from executing its branching logic.

## Why redesign is justified

Current canonical demonstrably mixes at least these independently owned concerns in mutable `dt` state:

1. accepted-step numerical growth/shrink based on nonlinear iteration count;
2. solver-failure recovery;
3. hard event alignment;
4. process-specific event/retry rules;
5. day-boundary restart policy;
6. user safety/performance bounds;
7. transaction interval clipping;
8. outer transaction retry;
9. temporal acceptance/retry.

These concerns can be separated without changing the Richards equations or physical process equations.

## Strongest architectural findings

### Event scheduling is not timestep accuracy

The following should conceptually be hard-stop ownership, not numerical-policy ownership:

- meteorological discontinuities;
- rainfall/runon events;
- irrigation/interception events;
- external coupling-window end;
- calendar/output boundaries only where exact state-at-time semantics require them.

### Solver recovery is not accepted-step proposal

`fldecdt -> TimeControl(5)` is retry policy.

`numbit -> TimeControl(3)` is future-step proposal.

They currently share the same mutable `dt` state.

### Calendar day changes numerical history

At start of day the current code raises dt to at least:

`sqrt(DTMIN*DTMAX)`.

This is numerical-policy mutation caused by a calendar boundary.

### User DTMIN/DTMAX are not preserved as pure numerical bounds

Current initialization mutates them using:

- output cadence;
- detailed meteorological cadence;
- the rule `DTMIN <= 0.1*DTMAX`.

The effective runtime values therefore combine numerical policy and scheduling.

### SWAP5 now has nested control layers

Post-SWAP4 architecture added:

- transactional retry/rollback;
- temporal rejection/certificate policy;
- external coupling windows.

Legacy TimeControl still operates inside those layers.

The complete retry/timestep hierarchy therefore has no single explicit owner.

## Relationship to recent BOFEK/performance evidence

Recent experiments consistently show:

- larger intervals can materially reduce solver work where safe;
- static DTMAX/regime/material policies are not robust near dynamic wet transitions;
- one-step accepted-state heuristics can expose large speed potential but are insufficiently predictive;
- selective two-half refinement restores robustness but consumes most of the gain;
- the fixed-flux temporal defect indicator does not generalize to dynamic top.

Therefore further direct tuning inside the existing architecture is unlikely to resolve the ownership and observability problem.

## Qualified target architecture

The redesign should separate:

### HardEventScheduler
Owns non-crossable time boundaries only.

### StepProposalController
Owns preferred next numerical interval.

### TrialExecutor
Executes one transactional candidate interval.

### AcceptanceController
Owns mass/temporal/accuracy acceptance.

### RetryController
Owns smaller-interval choice after typed rejection.

### DecisionTrace
Records why every requested/attempted/accepted interval has its size.

No process should independently mutate the global next-step policy outside these contracts.

## DTMIN / DTMAX direction

TIMEARCH01 does not production-remove either input yet.

However, the redesign must explicitly evaluate:

- retaining them as user policy;
- demoting them to optional safety bounds;
- removing them from ordinary user input in favor of an accuracy/performance profile.

The current evidence does not support keeping DTMIN/DTMAX as unquestioned central user controls.

## Required successor

`F-PE-TIMEARCH02 — timestep decision attribution and shadow controller`

TIMEARCH02 is observation-first.

It must:

1. attribute every current timestep decision to a typed reason;
2. quantify counts and solver work by reason;
3. separate hard-event clamps from numerical-policy clamps;
4. expose nested retry ownership;
5. run one or more shadow proposal controllers without affecting accepted execution;
6. quantify how often the actual dt is smaller than the shadow preference and why;
7. produce the minimal replacement contract before any production TimeControl rewrite.

## Production boundary

No timestep semantics or production source are changed in TIMEARCH01.

