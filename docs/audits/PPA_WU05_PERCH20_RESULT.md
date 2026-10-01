# PPA-WU05-PERCH20 result — macropore numerical-continuation integration

Date: 2026-10-01

Status: `CLOSED_QUALIFIED_MACROPORE_NUMERICAL_CONTINUATION_INTEGRATION`

Canonical baseline:
`integration/f-ci-canonical@641a8ba7fad5b67f0ebff7c78dd065270ed46329`

Qualified postimage:
`ce6d5a3dfddab6ec72972dfc1503dcebda48a3c8`

Qualification run:
`36892803443` — SUCCESS

## Decision

`QUALIFIED_MACROPORE_NUMERICAL_CONTINUATION_INTEGRATION`

PERCH20 closes the state-architecture dependency identified by PERCH19.

The exact B1.11 exchange-reduction controller can now be represented as dedicated
numerical continuation without modifying the seven-field macropore physical state.

## New layout

Registered:

`FMR_NUMERICAL_CONTINUATION_MACROPORE_REDUCTION = 505019`

The layout is distinct from:

- NONE;
- Richards temporal history;
- all optional physical-state layout identities.

It composes specifically with:

`FMR_OPTIONAL_STATE_LAYOUT_MACROPORE`.

Unknown or mismatched state/layout combinations remain fail-closed.

## Typed continuation carrier

Added:

`fmr_macropore_reduction_continuation_t`

with exactly the PERCH19 payload:

- `reduction_level` 0..3;
- `successful_steps` 0..10;
- `previous_reduction_dt >= 0`.

The current factor is derived:

`0.1 ** reduction_level`.

Added state subtype:

`fmr_b110_macropore_reduction_state_t`

which extends the ordinary B1.10 physical state and carries the numerical continuation
separately from the allocated seven-field macropore physical state.

## Clone / committed / restart semantics

The qualified carrier supports:

- exact clone of physical plus numerical state;
- typed committed-state construction;
- committed snapshot;
- restart template matching;
- rejection of NONE and Richards-temporal layout mismatches;
- rejection of invalid continuation payloads.

The committed constructor requires an allocated physical macropore state, preventing the
numerical continuation layout from being used as an unrelated generic carrier.

## PERCH19 controller binding

The already-qualified PERCH19 controller is bound through a typed adapter.

Qualified transitions include:

- ordinary temporal retry precedence above DTMIN;
- no accepted-state mutation during a trial-local reduction candidate;
- level 0 -> 1 exchange-reduction candidate at DTMIN;
- source retry timestep `sqrt(DTMIN*DTMAX)`;
- ten-successful-step recovery;
- exact conversion between controller and continuation payload.

The controller remains the source authority for transition equations. PERCH20 owns state
lifetime and transaction representation.

## Backend admission

The serialized backend now recognizes the new numerical continuation layout only for
macropore optional-state templates.

Existing macropore templates using:

`FMR_NUMERICAL_CONTINUATION_NONE`

remain admitted and unchanged.

The new layout does not enable temporal-indicator history.

## Qualification evidence

Run `36892803443` passed the PERCH20 gate at O0/O2 and then passed the current canonical
RFM optional-state preservation gate.

Qualified markers include:

- `PPA_WU05_PERCH20_LAYOUT_IDENTITY=PASS`;
- `PPA_WU05_PERCH20_CLONE_PAYLOAD=PASS`;
- `PPA_WU05_PERCH20_RESTART_MATCH=PASS`;
- `PPA_WU05_PERCH20_COMMITTED_CARRIER=PASS`;
- `PPA_WU05_PERCH20_FAIL_CLOSED=PASS`;
- `PPA_WU05_PERCH20_CONTROLLER_BINDING=PASS`;
- `PPA_WU05_PERCH20_REJECT_ISOLATION=PASS`;
- `PPA_WU05_PERCH20_CARRIER_GATE=PASS`.

RFM optional-state preservation also passed on the same postimage.

## Scope boundary

PERCH20 qualifies the continuation state architecture and controller binding.

It does not yet claim that the full FMR transaction orchestrator automatically performs
the source retry ladder on the Andelst perched authority case.

That production replay must prove the complete ordering in one live transaction:

1. factor 1 attempt;
2. ordinary temporal reduction precedence until DTMIN;
3. trial-local level escalation;
4. reduced-factor retry;
5. accepted physical plus numerical publication;
6. restart and recovery.

## Next safe step

Open:

`PPA-WU05-PERCH21 — Andelst live retry/admission replay`.

PERCH21 should be reconstructed from then-current canonical and carry only the required
qualified PERCH code plus the A18 authority fixture.

If the live replay passes, the perched production capability can become a production
admission candidate.
