# F-PE-TIMEARCH05 preregistration — retry ownership reconciliation

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@c18325bf110032cf323fad08bb7ddb52204b1d76`

Parents:

- TIMEARCH01 — timestep architecture redesign;
- TIMEARCH02 — executable separated decision contracts;
- TIMEARCH03 — timestep attribution;
- TIMEARCH04 — scheduler ownership.

## Purpose

Determine whether current SWAP5 retry layers are semantically duplicate, merely nested, or both, and define a single explicit ownership hierarchy for a future timestep architecture.

No production retry behavior changes in TIMEARCH05.

## Existing source authority

Current F-CI13 distinguishes three Richards paths:

1. alternative linear-solver recovery remains inside one physical solve;
2. nonconvergence above legacy DTMIN triggers internal `fldecdt -> TimeControl(5)` reduction and retry inside SWAP;
3. terminal nonconvergence at the internal minimum returns `RETRYABLE_NUMERICAL` to the transaction layer.

Current transaction authority then separately retries from the committed origin for:

- terminal solver rejection;
- hard mass rejection;
- temporal rejection.

F-GC41 owns a still higher whole-window retry after coupling preflight rejection.

## Ownership hypotheses

H1. Internal legacy retry and transaction solver retry are **nested, not semantically duplicate**:
- internal retry owns recovery inside one requested physical interval;
- outer solver retry owns failure after the internal recovery envelope is exhausted.

H2. Temporal retry is not solver retry:
- the physical solve has converged;
- accepted-state publication is withheld because the temporal acceptance contract rejects the interval.

H3. Coupling-window retry is not a SWAP numerical retry:
- it is owned by multi-participant whole-window acceptance;
- it requires a fresh window/runtime identity from the same accepted origin.

H4. Despite distinct semantics, nested retries can repeat already-expended work:
- internal retries on a rejected outer trial are counted as discarded work;
- a transaction retry re-executes from the committed origin;
- a coupling retry may re-execute the complete SWAP transaction again.

## Executable ownership matrix

Use the canonical `mod_transaction_reference` with a deterministic test-only model.

### I. LOCAL_INTERNAL_SUCCESS

One transaction attempt.

The model reports:
- solver success;
- two internal retries already consumed;
- valid mass;
- valid temporal certificate.

Expected:
- transaction attempts = 1;
- transaction retries = 0;
- solver rejections = 0;
- temporal rejections = 0;
- total internal retries = 2;
- accepted internal retries = 2.

### II. TERMINAL_SOLVER_ESCALATION

First outer attempt:
- model reports solver failure;
- three internal retries already consumed.

Second outer attempt after transaction reduction:
- solver succeeds;
- one internal retry.

Expected:
- transaction attempts = 2;
- transaction retries = 1;
- solver rejections = 1;
- total internal retries = 4;
- accepted internal retries = 1.

This proves rejected internal work is retained in total diagnostics but not accepted-work diagnostics.

### III. TEMPORAL_REJECTION

First outer attempt:
- solver succeeds;
- valid mass;
- temporal indicator rejects;
- one internal retry was consumed.

Second reduced attempt:
- solver succeeds;
- temporal indicator accepts;
- one internal retry.

Expected:
- transaction attempts = 2;
- retries = 1;
- solver rejections = 0;
- temporal rejections = 1;
- total internal retries = 2;
- accepted internal retries = 1.

### IV. WHOLE_WINDOW_RETRY

Source-bound to F-GC41.

Expected ownership:
- retry only before publication point;
- all participant candidates discarded/invalidated;
- fresh smaller window/runtime identity;
- same accepted physical origin;
- never represented as an internal Richards retry.

## Work attribution

The test model also reports deterministic work per physical trial.

For rejected outer attempts, work must remain in total diagnostics and be absent from accepted diagnostics.

Define:

`discarded_work = total_work - accepted_work`.

This is not called duplicate work when the layers have distinct semantics. It is called **nested re-execution cost**.

## Advancement rule

TIMEARCH05 qualifies retry ownership if:

1. the source guard confirms F-CI13 internal/terminal split;
2. the transaction ownership matrix passes O0 and O2;
3. all four retry classes have distinct owner/reason semantics;
4. total versus accepted diagnostics make nested re-execution cost observable;
5. no proposal-controller state is required to represent a rejected trial.

If qualified, the target production hierarchy is:

1. local solver recovery inside TrialExecutor;
2. transaction RetryController for terminal solver, mass and temporal rejection;
3. coupling WindowController for whole-window preflight rejection;
4. StepProposalController updated only after committed acceptance.

## Production boundary

No production `src/**` changes.

Possible outcomes:

- `QUALIFIED_RETRY_OWNERSHIP_HIERARCHY`;
- `BLOCKED_RETRY_OWNERSHIP_OVERLAP`.
