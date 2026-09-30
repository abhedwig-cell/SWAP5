# F-PE-NLGLOB14Z9C preregistration — bounded confirmation of 10:16 -> 11:16

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Parent research authority:

- NLGLOB14Z9: blocked aggregate at 102.4 d, with preserved 4/4 accepted event evidence for `10:16 -> 11:16`;
- observed event time is about 53.991-53.995 d;
- one fine RUNOFF endpoint solve failure occurs only after the accepted event and blocks the long-horizon aggregate;
- no tolerance, forcing or dt change is authorized.

## Purpose

Independently confirm the physical retreat:

`10:16 -> 11:16`

on a bounded horizon that requires accepted progression beyond the observed event but excludes the unrelated later 102.4 d tail failure.

## Frozen fixtures

Use the same four O05 controls:

- HEAD and RUNOFF;
- dt = 1.25e-4 d and 6.25e-5 d;
- unchanged dry forcing;
- unchanged zero bottom flux;
- unchanged solver tolerances/work limits;
- physical mass as hard authority.

## Frozen horizon

`60.0 d`

No staged extension is allowed in this workunit.

## Physical event definition

The event exists only on exact accepted saturation geometry change:

`10:16 -> 11:16`.

Both pre/post states must be contiguous lower saturated tails defined by exact paired indicators:

- `h >= 0`;
- `theta == theta_s`.

No predictor state, fitted threshold, interpolation, extrapolation or prior event time defines the event.

## Instrumentation

Use event-only accepted-state logging.

Instrumentation may reduce output volume only and must not alter solver path, forcing, timestep, accepted state, provider semantics or mass accounting.

## Hard gates

Per fixture require:

- complete 60.0 d control trajectory;
- exact accepted `10:16 -> 11:16`;
- finite state;
- contiguous accepted saturated tail;
- no reverse;
- no skipped node;
- interval physical mass ledger <= `5e-8 cm`;
- cumulative physical mass remains finite and bounded.

## Frozen classifications

If all four fixtures complete 60.0 d and expose exact event cleanly:

`QUALIFIED_CONFIRMATORY_RETREAT_10_TO_11_CONTROL`.

If all complete but at least one does not expose the event:

`NLGLOB14Z9C_EVENT_NOT_CONFIRMED`.

If otherwise-valid route/dt outcomes differ:

`NLGLOB14Z9C_MIXED_CONFIRMATION`.

Any reverse/skipped/noncontiguous accepted geometry:

`NLGLOB14Z9C_STATE_INCONSISTENT`.

Any process or physical-mass failure before 60.0 d:

`BLOCKED_NLGLOB14Z9C_CONFIRMATION`.

## Consequence

A positive result authorizes a separately preregistered split-ownership successor through accepted:

`10:16 -> 11:16`

with ownership:

`face 9/10 -> face 10/11`.

It does not qualify:

- later retreats;
- complete disappearance;
- empty-tail transition;
- whole-column TG re-entry;
- production temporal ownership.

## Production boundary

Research only. No production source/default change.
