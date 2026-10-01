# PPA-WU05-PERCH19 preregistration — source-faithful FrReduQ retry state machine

Date: 2026-10-01

Status: `PREREGISTERED / NUMERICAL_STATE_MACHINE`

Baseline:
`research/ppa-wu05-a18-perched-authority-fixture@50843361c30fe3dc67114bce2b0ad22d9af77c88`

Canonical reconciliation:
`integration/f-ci-canonical@aea20f61381f0c750fc90f2eb5201b8a40efcd73`.

Owning evidence:

- A18 solver-stable source-backed perched fixture;
- A18 active inner exchange requires source reduction factor 0.1;
- exact 4.3.1 `IDecMpRat/FrReduQ` source semantics.

## Purpose

Migrate the exact macropore exchange-reduction control state used by SWAP 4.3.1 when
Richards convergence fails with active macropore exchange.

This workunit owns **numerical continuation state**, not physical macropore state.

The seven-field physical macropore continuation schema remains unchanged.

## Exact source behavior

Rate factor:

`FrReduQ = 0.1 ** IDecMpRat`

with source levels:

- 0 -> 1.0;
- 1 -> 0.1;
- 2 -> 0.01;
- 3 -> 0.001.

### Nonconvergence before minimum timestep

If Richards does not converge and `fldtmin = false`:

- physical trial state is reset;
- `fldecdt = true`;
- exchange-reduction level is unchanged;
- timestep controller reduces `dt`.

### Nonconvergence at minimum timestep

If Richards still does not converge at minimum timestep and `IDecMpRat < 3`:

- `IDecMpRat += 1`;
- `FlDecMpRat = true`;
- `dtold = dt`;
- minimum-timestep flag is cleared;
- timestep controller sets the next timestep to:

  `sqrt(dtmin*dtmax)`.

### Recovery after successful steps

After convergence, if `IDecMpRat > 0`:

- `NStep` increments up to 10;
- if `dt > dtold` or `NStep >= 10`:
  - `dtold = dt`;
  - `NStep = 0`;
  - `IDecMpRat -= 1`.

Thus reduction state can survive accepted steps.

## Deterministic SWAP5 state

PERCH19 introduces an explicit numerical state containing:

- reduction level `0..3`;
- recovery accepted-step count `0..10`;
- last reduction/recovery timestep `dtold`.

Transient source flags such as `FlDecMpRat` become returned actions, not persisted state.

## Actions

The state machine returns one of:

- `NONE`;
- `REDUCE_TIMESTEP`;
- `ESCALATE_EXCHANGE_REDUCTION_AND_RESET_TIMESTEP`;
- `EXHAUSTED`.

For the escalation action it returns:

`next_dt = sqrt(dtmin*dtmax)`.

## Safety difference from legacy

Exact 4.3.1 can continue after the final reduction level even when convergence remains
unresolved, after warning.

SWAP5 must **not** silently inherit that behavior.

PERCH19 records the source behavior but maps final exhaustion to fail-closed
`EXHAUSTED`.

No nonconverged physical candidate may be admitted.

## Persistence boundary

Because reduction level affects physical exchange rates, restart-equivalent execution
requires the numerical state to be checkpointed/restored.

This state is not part of the seven physical macropore continuation fields.

It belongs to numerical continuation / transaction context.

## Gates

### G1 — exact transition oracle

Prove factor ladder, timestep-reduction action, escalation action, sqrt reset and recovery
rules against literal B1.11 source semantics.

### G2 — rejected-attempt isolation

State changes caused by a failed speculative transaction must be restorable from attempt
context.

### G3 — restart serialization

Persist/restore reduction level, recovery count and `dtold` exactly.

### G4 — A18 active perched replay

Use the A18 source-backed perched state.

Starting at source level 0, reproduce:

- unreduced retry;
- level-1 factor 0.1;
- converged active perched inner exchange;
- exact mass closure.

No caller hardcodes 0.1.

### G5 — recovery behavior

Demonstrate one-step recovery when accepted `dt > dtold` and ten-step recovery when
accepted `dt == dtold`.

### G6 — preservation

Default A8-A10 route and all qualified A15/A16/A17 behavior remain unchanged when the
state machine is disabled.

## Non-scope

- no covering-layer extension;
- no dynamic crack feedback;
- no RossFast;
- no parallel MultiSWAP;
- no canonical admission from the research ancestry.

## Decision

Target:
`QUALIFIED_SOURCE_FAITHFUL_FREDUQ_NUMERICAL_CONTINUATION`.
