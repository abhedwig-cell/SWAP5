# PPA-WU05-A19 closeout — canonical minimal dedicated RFM physical state

Date: 2026-10-01

Status: CLOSED_CANONICAL_ADMITTED

Decision:

    CANONICALLY_ADMITTED_MINIMAL_DEDICATED_RFM_PHYSICAL_STATE

## Canonical evidence

- baseline: `8cada0ea691cd129c8645fca0a4bb6626ba73422`
- qualified postimage: `34488da1b4202115a2c138200dd5985cf582411f`
- qualification run: `36866618323` — SUCCESS
- admission PR: #944
- canonical merge: `09397ecdfc9aacc405d78467fe428efc7b026a67`

## Admitted capability

Canonical production source now contains the minimal dedicated RFM mutable
physical/history state:

    mb_water_cm
    endpoint_water_cm(:)
    tau_surface_day

A19 also owns the exactly-once interval conversion of A17 routing rates into
water-storage increments.

## Transaction semantics

Qualified:

- initialization and validity;
- copy identity;
- accepted-state immutability during candidate construction;
- exact candidate storage receipt;
- bit-identical replay from the same accepted state;
- endpoint-size mismatch fail-closed;
- invalid upstream status fail-closed.

The standard SWAP macropore continuation state remains untouched.

## Post-merge preservation

The qualified dependency surface is byte-identical on canonical:

    source f84f67c42e5a4caf0b826d9f32fe05149775e150
    test   8d8ac0458c5f2c4fd26d9174eb5ef3ca317a6016
    runner e5a80e66ccba71a0ae9376e0365c44f6c8053592

The focused qualification is inherited without replay.

## Lifecycle

    implemented -> persisted -> tested -> qualified -> canonically admitted -> closed

## Remaining boundary

A19 is not yet a backend optional-state layout.

A20 must integrate this state with:

    FMR optional-state layout identity
    physical-state clone/checkpoint
    storage accounting
    temporal comparison
    restart/checkpoint preservation

before a live end-to-end RFM runtime may be admitted.
