# PPA-WU05-PERCH19 result — FrReduQ numerical continuation

Date: 2026-10-01

Status: `CLOSED_PARTIAL_QUALIFIED_STATE_MACHINE / TRANSACTION_RETRY_DURATION_BLOCKED`

Current canonical reconciliation:
`integration/f-ci-canonical@d89912713f9182f4a5319a54cb6094930d38e2cd`

Research branch:
`research/ppa-wu05-perch19-flow-reduction-ladder@e9b1b5b4be5195ff8a68f16f7426ac2b862b0ffb`

## Decision

The exact FrReduQ continuation state machine is qualified in isolation.

Production integration is blocked because the current generic transaction contract cannot
represent the exact B1.11 retry-duration transition that follows macropore exchange
reduction.

Decision:

`QUALIFIED_FREDUQ_STATE_MACHINE_REQUIRES_MODEL_PROPOSED_RETRY_DURATION_SEAM`

## Qualified pure state machine

PERCH19 introduces a typed numerical continuation:

- `reduction_level`;
- `accepted_step_count`;
- `recovery_dt`.

Derived exchange factors are exactly:

- level 0: `1.0`;
- level 1: `0.1`;
- level 2: `0.01`;
- level 3: `0.001`.

The transition evaluator is side-effect-free: committed input is never mutated.

Qualification run:

`36862145326` — SUCCESS

Qualified postimage:

`c33309b31ff5ce0962611554f37bca9290d40df0`

Evidence includes:

- bounded 0 -> 1 -> 2 -> 3 escalation;
- no escalation above level 3;
- exact `sqrt(dtmin*dtmax)` retry-duration proposal;
- 10-accepted-step one-level recovery;
- accepted larger-dt immediate one-level recovery;
- no recovery at level 0;
- committed-input isolation;
- O0/O2 identity.

## Exact source ordering

Exact B1.11 does not reduce macropore exchange on the first nonlinear failure.

Ordering is:

1. ordinary timestep reduction;
2. when HeadCalc is already at the minimum timestep and remains non-convergent:
   increment `IDecMpRat`;
3. set `FlDecMpRat`;
4. store current `dt` in `dtold`;
5. clear the minimum-timestep latch;
6. TimeControl then sets:
   `dt = sqrt(DTMIN*DTMAX)`.

The exchange factor becomes:

`FrReduQ = 0.1 ** IDecMpRat`.

After successful steps the reduction level is recovered gradually according to
`dt > dtold` or ten accepted steps.

## SWAP5 retry ownership

In the explicit Reference-Richards path, HeadCalc performs one nonlinear solve for the
caller-supplied timestep.

On non-convergence it restores the trial state, sets the typed worker
`request_dt_reduction` flag and returns.

`mod_reference_richards_legacy_binding` then publishes:

`SW_SOLVE_RETRY_ADVISED`.

The solver does not itself run TimeControl or retry at another timestep.

The generic transaction manager owns interval retries.

## Blocking transaction contract

Current `mod_transaction_reference` represents retry duration only through:

`attempt_dt = attempt_dt * policy%retry_scale`

with the policy contract requiring:

`0 < retry_scale < 1`.

Therefore every transaction retry must be shorter than the previous attempt.

Exact macropore reduction requires a different transition after the minimum-timestep
failure:

`dt_retry = sqrt(DTMIN*DTMAX)`.

For the Andelst authority values this is a restart upward from the minimum timestep, not
another multiplicative reduction.

The existing `trial_outcome_t` has no model-proposed retry-duration field or retry-reason
contract that could express this source transition.

## Why PERCH19 does not approximate this away

The following substitutions are rejected:

- hardcode `flow_reduction=0.1`;
- increment FrReduQ on the first solver retry;
- keep shrinking dt while changing FrReduQ;
- ignore the source recovery timestep `sqrt(DTMIN*DTMAX)`;
- persist the level while leaving retry ordering to accidental outer behavior.

A18 proved the reduction mechanism is operationally relevant: the source-backed Andelst
perched case retries at factor 1.0 and converges at exact factor 0.1.

Therefore changing the ordering would alter qualified numerical semantics.

## Canonical carry-forward

PERCH19 was reconstructed from current canonical rather than merging the historical
perched ancestry.

Only the qualified source seams required for the perched inner route were selectively
carried forward.

The generic historical A11-A18 documentation/status namespace is not carried into
canonical and does not override the current RFM authority.

## Production status

PERCH19 is not a production-admission candidate.

The physical seven-field macropore state remains unchanged.

The new FrReduQ continuation remains a numerical-policy research component and has not
been attached to committed FMR state or persistence because the owning retry action cannot
yet be represented faithfully by the transaction contract.

## Next safe workunit

Open:

`PPA-WU05-PERCH20 — model-proposed transaction retry duration`.

PERCH20 should add the smallest generic transaction seam that allows a model to request a
specific next attempt duration after a solver rejection while preserving:

- transaction ownership of retries;
- fail-closed validation of proposed duration;
- no committed-state mutation on rejection;
- existing fixed-`retry_scale` behavior when no proposal exists;
- current temporal/full-half semantics;
- explicit retry reason/provenance.

Then PERCH19 can integrate:

- FrReduQ numerical continuation;
- exact min-dt -> reduced-exchange -> geometric-mean-dt transition;
- accepted recovery;
- persistence/restart;
- A18 active perched end-to-end replay.
