# PPA-WU05-PERCH20 preregistration — transaction numerical retry feedback

Date: 2026-10-01

Status: `PREREGISTERED / GENERIC_TRANSACTION_PROTOCOL`

Baseline:
`research/ppa-wu05-perch19-freduq-state-machine@34b011c6bed22db5eb547909bdc497f8e8719973`

Canonical reconciliation:
`integration/f-ci-canonical@ad0737b1a9968ba7a14933dd8332b37f94ad8a37`.

## Purpose

Add the smallest generic transaction lifecycle needed by qualified PERCH19 numerical
continuation without embedding macropore-specific state in the transaction executor.

Existing transaction models must retain current behavior through default no-op hooks.

## Required generic lifecycle

### Solver rejection

For a failed solver trial:

1. restore the pre-attempt model context;
2. call model `apply_retry_feedback` with the failed trial outcome and attempted duration;
3. allow the model to request an explicit next retry duration;
4. if context is transactional, recapture the checkpoint context **after** feedback so
   numerical continuation survives into the next retry;
5. retry from unchanged physical checkpoint state.

### Mass or temporal rejection

Do not call solver retry feedback.

Restore ordinary attempt context and use existing generic retry scaling.

A physically successful but mass/temporal-rejected speculative branch must not change
model numerical continuation.

### Final acceptance

After restoring the context belonging to the accepted physical route and after moving the
accepted physical state into committed ownership, call model `apply_accepted_feedback`
exactly once with accepted duration.

This is the only generic acceptance event numerical continuation may use.

## Interface

Extend `transaction_model_t` with default no-op:

- `apply_retry_feedback(outcome,attempt_dt,next_dt_override_available,next_dt_override,ok)`;
- `apply_accepted_feedback(accepted_dt,ok)`.

No existing model is required to override either hook.

## Retry duration rules

When no override is supplied:

`next_dt = current_dt * policy%retry_scale`.

When a valid override is supplied:

- finite;
- > 0;
- clipped to the original requested interval duration if larger;
- used for the next retry.

Invalid override feedback fails closed rather than silently falling back.

## Context refresh

A successful retry-feedback mutation must be incorporated into the new rollback baseline
for subsequent retries by replacing the saved attempt context with a fresh capture.

Physical checkpoint state remains unchanged.

## Gates

### G1 — default preservation

A model using no new hooks produces exactly the previous transaction behavior.

### G2 — post-rollback ordering

Synthetic model proves retry hook sees restored numerical state, mutates it, and the next
advance sees that mutation.

### G3 — explicit retry duration

Synthetic model requests a non-generic retry duration and the next `advance` receives
exactly that interval.

### G4 — speculative isolation

Mass and temporal rejected trials cannot mutate persistent numerical context.

### G5 — final acceptance

Accepted feedback fires exactly once after final physical acceptance and its mutation
persists.

### G6 — both transaction routes

Qualify external full/half and model-certificate transaction paths.

## Non-scope

- no PERCH19 backend binding in PERCH20;
- no physical macropore state change;
- no A18 replay;
- no canonical admission.

## Decision target

`QUALIFIED_TRANSACTION_NUMERICAL_RETRY_FEEDBACK_CONTRACT`.
