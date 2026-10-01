# PPA-WU05-PERCH20 preregistration — macropore numerical-continuation state integration

Date: 2026-10-01

Status: `PREREGISTERED / NUMERICAL_CONTINUATION_INTEGRATION`

Canonical baseline:
`integration/f-ci-canonical@641a8ba7fad5b67f0ebff7c78dd065270ed46329`

Research authorities:

- A18 source-backed Andelst perched authority and active inner exchange;
- PERCH19 qualified exact `IDecMpRat / FrReduQ` controller.

## Purpose

Add a dedicated FMR numerical-continuation layout for the exact macropore exchange
reduction controller without changing the seven-field physical macropore state.

## Payload

The committed/candidate numerical continuation payload is exactly:

- `reduction_level` in 0..3;
- `successful_steps` in 0..10;
- `previous_reduction_dt >= 0`.

Current `FrReduQ` is derived as `0.1 ** reduction_level`.

## Architecture

The new layout is a separate `numerical_continuation_layout_id`.

It must compose with:

`FMR_OPTIONAL_STATE_LAYOUT_MACROPORE`.

It must not overload or alter:

- the seven-field macropore physical continuation state;
- Richards temporal-history layout;
- RFM optional-state layouts;
- default A8-A10 macropore templates using numerical-continuation NONE.

## Gates

### G1 — layout identity

Register a dedicated fail-closed numerical-continuation layout ID.

Macropore templates may use either:

- NONE, preserving current admitted behavior;
- PERCH_REDUCTION, requiring the typed continuation carrier.

Unknown or mismatched layouts remain rejected.

### G2 — typed carrier

Add a macropore physical-state subtype carrying the PERCH19 numerical payload separately
from the physical seven-field state.

Clone/checkpoint must preserve both exactly.

### G3 — reject/commit

A trial-local controller candidate may advance reduction/recovery state.

Rejected enclosing candidates must leave committed numerical continuation unchanged.

Accepted candidates publish physical macropore state and numerical continuation
atomically.

### G4 — restart

Restart template matching must require the dedicated carrier for the new layout and
roundtrip all three values exactly.

### G5 — controller integration

Bind the qualified PERCH19 controller to the continuation payload.

Preserve source ordering:

1. ordinary temporal reduction above DTMIN;
2. exchange-reduction escalation only at minimum-step boundary;
3. bounded levels 0..3;
4. source retry timestep `sqrt(DTMIN*DTMAX)`;
5. accepted-step recovery after ten steps or larger dt.

### G6 — preservation

When the new layout is absent:

- canonical macropore NONE route remains unchanged;
- Richards temporal-history route remains unchanged;
- RFM and other optional-state layouts remain unchanged.

## Non-scope

PERCH20 does not yet claim:

- full Andelst production admission;
- canonical merge of historical A11-A18 documents;
- covering-layer macropore physics;
- RossFast or parallel MultiSWAP perched execution.

## Decision states

- `QUALIFIED_MACROPORE_NUMERICAL_CONTINUATION_INTEGRATION`;
- `QUALIFIED_CARRIER_CONTROLLER_INTEGRATION_PRODUCTION_REPLAY_REQUIRED`;
- or a concrete architecture blocker.
