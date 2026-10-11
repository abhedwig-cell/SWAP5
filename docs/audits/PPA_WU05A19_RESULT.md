# PPA-WU05-A19 result — minimal dedicated RFM physical state

Date: 2026-10-01

Status: QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE

Baseline:

    integration/f-ci-canonical@8cada0ea691cd129c8645fca0a4bb6626ba73422

Qualified postimage:

    34488da1b4202115a2c138200dd5985cf582411f

Qualification run:

    36866618323 — SUCCESS

Focused gate output:

    PPA_WU05A19_RFM_PHYSICAL_STATE=PASS

## Qualified state

A19 introduces the minimal dedicated mutable RFM state:

    mb_water_cm
    endpoint_water_cm(:)
    tau_surface_day

Structural endpoint depths and RFM parameters remain immutable configuration or
derived quantities.

## Exactly-once interval integration

A17 routing quantities inherit the cm/day unit of the A15 surface receipt.
A19 is the unique interval-integration owner:

    routed rate * dt_day -> candidate water storage increment.

The qualification oracle uses:

    MB rate = 0.4 cm/day
    IC endpoint rate = 1.6 cm/day
    dt = 0.1 day

and obtains:

    MB input = 0.04 cm
    IC input = 0.16 cm
    total preferential input = 0.20 cm
    fast-storage change = 0.20 cm
    mass residual = floating-point zero within 1e-12.

## Transaction semantics

Qualified:

- initialization and ready contract;
- copy identity;
- accepted state remains unchanged after candidate construction;
- replay from the same accepted state and receipt is bit-identical;
- endpoint-count mismatch fails closed;
- invalid routing/event-age status fails closed;
- nonpositive dt fails closed.

A19 does not yet add this state to the serialized backend, restart payload or
live runtime execution.

## Architecture boundary

The standard SWAP macropore continuation state remains untouched.

A19 is the dedicated RFM physical-state object required by A18.

## Lifecycle

    implemented -> persisted -> tested -> qualified

Canonical admission is not claimed by this result.
