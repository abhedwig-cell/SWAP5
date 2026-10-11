# PPA-WU05-A20 result — dedicated RFM optional-state carrier

Date: 2026-10-01

Status: QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE

Baseline:

    integration/f-ci-canonical@100704c5a7283ae592bfa2104928ac16cd7ba32d

Qualified postimage:

    183360a3207cb5c6e83ef6881f65bba2260ddf0e

Qualification run:

    36868999374 — SUCCESS

Focused markers:

    PPA_WU05A20_STATIC_BINDING=PASS
    PPA_WU05A20_RFM_OPTIONAL_STATE_LAYOUT=PASS
    PPA_WU05A20_RUNTIME_O0=PASS
    PPA_WU05A20_RUNTIME_O2=PASS
    PPA_WU05A20_RFM_OPTIONAL_STATE_GATE=PASS

## Qualified capability

A20 adds a distinct FMR optional physical-state identity:

    FMR_OPTIONAL_STATE_LAYOUT_RFM = 505002

and a dedicated polymorphic serialized-backend carrier:

    fmr_b110_rfm_state_t

containing the canonically admitted A19:

    rfm_physical_state_t.

## Checkpoint / restart-seam evidence

The focused executable verifies that:

- a committed state can be initialized with the RFM carrier;
- committed snapshot preserves the base B1.10 state and RFM state;
- kernel checkpoint capture and snapshot preserve both bitwise;
- mutating caller-owned source objects after committed-state construction does
  not alter the committed or checkpoint-owned carrier;
- mutating a returned committed snapshot does not alter checkpoint-owned state.

This qualifies the in-memory canonical checkpoint/reconstruction seam. External
encoded restart-file compatibility is not claimed.

## Backend bindings

The full serialized backend compiles on O0 and O2 with:

- explicit RFM storage accounting:

      matrix storage + ponding + rfm%storage_cm()

- explicit RFM temporal identity requiring both base-state identity and:

      full%rfm%same_values(half%rfm)

- RFM carrier compatibility only with the non-combined optional-state profile.

## Deliberate execution guard

A20 does not activate live RFM execution.

run_trial explicitly returns:

    KERNEL_STATUS_NOT_ADMITTED

when:

    optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_RFM.

Thus registering the carrier cannot silently activate a new physical route.

## Explicit non-claims

Not qualified here:

- live RFM stepping;
- RFM forcing/parameter admission;
- wall exchange;
- preferential release/bottom outflow;
- external encoded restart-file codec compatibility;
- combined RFM + snow/temperature/surface-water layouts.

## Lifecycle

    implemented -> persisted -> tested -> qualified

Canonical admission is not claimed by this result.
