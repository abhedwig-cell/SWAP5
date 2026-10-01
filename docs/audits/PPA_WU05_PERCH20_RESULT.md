# PPA-WU05-PERCH20 result — model-proposed transaction retry directive

Date: 2026-10-01

Status: `CLOSED_QUALIFIED_GENERIC_TRANSACTION_SEAM`

Baseline:
`integration/f-ci-canonical@d89912713f9182f4a5319a54cb6094930d38e2cd`

Qualified postimage:
`e5f74d16bab08248e37e54a22e56d649a9d012fc`

Qualification run:
`36864339023` — SUCCESS

## Decision

`QUALIFIED_MODEL_PROPOSED_RETRY_DIRECTIVE`

PERCH20 qualifies the smallest generic transaction seam required by the exact
SWAP 4.3.1 macropore reduction transition.

This is a generic transaction result. It does not itself implement FrReduQ or admit
perched production runtime.

## Qualified contract

A solver-rejected **full trial** may return:

- `retry_duration_proposal_available`;
- `retry_duration_proposal`;
- positive `retry_duration_reason`.

If no proposal is present, existing behavior is preserved:

`attempt_dt *= retry_scale`.

If a valid proposal is present, the transaction manager:

1. keeps ownership of rollback and retry count;
2. validates the proposed duration;
3. restores the physical checkpoint;
4. preserves the model's post-failure attempt-context mutation by recapturing the
   worker/trial context;
5. retries at the exact proposed duration.

Rejected physical state is never committed.

## Bounds and fail-closed rules

A present proposal is rejected when it is:

- non-finite;
- non-positive;
- larger than the originally requested interval;
- paired with a non-positive reason code.

Invalid proposals return explicit
`TX_STATUS_INVALID_MODEL_RETRY_DIRECTIVE`.

They do not silently fall back to fixed retry scaling.

Existing `max_retries` remains authoritative.

## Preserved behavior

The focused qualification proves both ordinary retry and attempt-context rollback remain
unchanged when no directive is supplied.

Qualified evidence includes:

- ordinary first failure -> fixed `retry_scale`;
- existing context rollback erases failed-attempt trial scratch;
- no model-directive counters on the legacy path;
- committed physical state remains unchanged.

## Model-proposed upward retry

The controlled qualification model demonstrates the exact semantic needed by PERCH19:

1. attempt `dt=1.0` fails without proposal;
2. generic transaction retry gives `dt=0.5`;
3. model changes trial-local numerical context and proposes `dt=0.8`;
4. transaction restores original physical checkpoint;
5. updated trial-local context survives;
6. next attempt is executed at exactly `0.8`;
7. accepted result is committed normally.

This proves a retry duration may legitimately be larger than the immediately failed
minimum-duration attempt while remaining bounded by the original requested interval.

## Why this closes the PERCH19 transaction-duration blocker

Exact B1.11 requires:

`minimum-dt failure -> increase IDecMpRat -> retry at sqrt(DTMIN*DTMAX)`.

The previously qualified PERCH19 state machine can now express that transition without:

- mutating committed physical state;
- hardcoding `flow_reduction=0.1`;
- abusing generic `retry_scale`;
- leaking failed trial physical state.

## Scope boundary

PERCH20 does not yet provide accepted-step feedback for FrReduQ recovery.

It qualifies only the model-proposed retry-duration/carry-forward seam needed to survive a
solver-rejected full trial.

PERCH19 recovery and persistence integration remain a follow-up concern.

No canonical admission is requested from this historical research branch.

## Current canonical reconciliation

Current canonical advanced beyond this research baseline and does not contain the
`retry_duration_proposal_*` seam.

Any production integration must therefore be reconstructed from the then-current canonical
rather than merging this branch wholesale.

## Next safe step

Open **PPA-WU05-PERCH21 — FrReduQ transaction integration** from current canonical.

PERCH21 should selectively carry forward:

- the qualified generic PERCH20 retry directive;
- the qualified PERCH19 numerical state machine;
- corrected perched inner-callback dependencies required by A18 authority;

and then qualify:

1. exact ordinary timestep reduction before FrReduQ escalation;
2. exact minimum-dt escalation and geometric-mean retry;
3. no numerical continuation leakage from speculative mass/temporal rejection;
4. accepted-step recovery;
5. persistence/restart;
6. A18 source-backed perched end-to-end transaction;
7. default A8-A10 route preservation.
