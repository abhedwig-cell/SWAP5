# PPA-WU05-PERCH20 preregistration — model-proposed transaction retry directive

Date: 2026-10-01

Status: `PREREGISTERED / GENERIC_TRANSACTION_INTERFACE_RESEARCH`

Baseline:
`integration/f-ci-canonical@d89912713f9182f4a5319a54cb6094930d38e2cd`

Owning dependency:
`PPA-WU05-PERCH19` decision
`QUALIFIED_FREDUQ_STATE_MACHINE_REQUIRES_MODEL_PROPOSED_RETRY_DURATION_SEAM`.

## Purpose

Add the smallest generic transaction contract that allows a model, after a solver-rejected
**full trial**, to request a specific next attempt duration and carry forward trial-local
attempt context.

This seam is required by the exact SWAP 4.3.1 macropore reduction transition:

`dtmin failure -> increase IDecMpRat -> retry at sqrt(DTMIN*DTMAX)`.

The generic transaction manager remains owner of rollback, retry count, interval bounds
and committed-state publication.

## Interface

A solver-rejected full-trial outcome may optionally return a retry directive:

- proposal available;
- proposed next attempt duration;
- integer reason/provenance code.

When no proposal is supplied, existing behavior remains exactly:

`attempt_dt *= retry_scale`.

When a valid proposal is supplied:

1. validate duration is finite and positive;
2. validate it does not exceed the originally requested interval duration;
3. count one rollback/retry under the existing max-retry bound;
4. when attempt context is required, capture the model's **post-failure trial context**
   and use that as the context restored before the next attempt;
5. retry from the original physical checkpoint with the proposed duration.

Committed state is never replaced on a rejected attempt.

## Scope boundary

The model-proposed directive is admitted only for a solver-rejected **full trial**.

Half-trial solver failures, mass failures and temporal failures continue to use the
existing fixed `retry_scale` policy.

This prevents a partially advanced half-step context from becoming a new retry authority.

## Fail-closed rules

A present directive is invalid when:

- proposed duration is non-finite;
- proposed duration <= 0;
- proposed duration exceeds the originally requested interval duration;
- reason code is not positive.

An invalid present directive must not silently fall back to fixed scaling.

## Gates

### G1 — legacy preservation

A model that never proposes a retry directive reproduces the existing fixed-scale retry
sequence and accepted result.

### G2 — larger model retry

A controlled dummy model must demonstrate:

- first normal solver failure uses fixed `retry_scale`;
- later solver failure proposes a duration larger than the current failed attempt but
  still inside the original requested interval;
- transaction executes that exact proposed duration.

### G3 — attempt-context carry

The same dummy model mutates only worker/trial attempt context on the model-proposed
failure.

The next attempt must observe that updated context while the physical retry state is still
cloned from the original checkpoint.

### G4 — committed-state isolation

Rejected attempts and model-proposed retry context must not mutate the committed state.

### G5 — invalid directive

An invalid model proposal fails closed with explicit status/provenance and is not replaced
by a scaled retry.

### G6 — bounds

Existing `max_retries` remains authoritative for both fixed and model-proposed retries.

## Non-scope

PERCH20 does not implement FrReduQ itself and does not change any macropore physics.

It does not alter:

- mass gates;
- temporal/full-half acceptance;
- candidate commit rules;
- persistence;
- existing retry_scale defaults.

## Decision states

- `QUALIFIED_MODEL_PROPOSED_RETRY_DIRECTIVE`;
- `REQUIRES_TRANSACTION_REDESIGN`;
- or `FALSIFIED_MODEL_RETRY_DIRECTIVE`.
