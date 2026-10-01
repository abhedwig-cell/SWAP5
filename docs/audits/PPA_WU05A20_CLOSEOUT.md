# PPA-WU05-A20 closeout — canonical RFM optional-state carrier

Date: 2026-10-01

Status: CLOSED_CANONICAL_ADMITTED

Decision:

    CANONICALLY_ADMITTED_RFM_OPTIONAL_STATE_CARRIER_FAIL_CLOSED_RUNTIME

## Canonical evidence

- baseline: `100704c5a7283ae592bfa2104928ac16cd7ba32d`
- qualified postimage: `183360a3207cb5c6e83ef6881f65bba2260ddf0e`
- qualification run: `36868999374` — SUCCESS
- admission PR: #946
- canonical merge: `1472797d5e1b8d61175c5eb760d63a364adaf0cb`

## Admitted capability

A20 adds the dedicated FMR optional physical-state layout:

    FMR_OPTIONAL_STATE_LAYOUT_RFM = 505002

with a polymorphic carrier:

    fmr_b110_rfm_state_t

that owns the A19 RFM state.

Qualified semantics include:

- committed-state construction;
- polymorphic clone;
- committed snapshot;
- kernel checkpoint capture/snapshot;
- caller/source isolation;
- backend storage accounting including RFM storage;
- exact temporal identity including RFM state identity.

## Deliberate runtime boundary

A20 explicitly keeps live RFM stepping unavailable.

The serialized backend returns:

    KERNEL_STATUS_NOT_ADMITTED

for the RFM optional-state layout.

This guard is part of the admitted A20 contract and prevents a layout registry
change from silently activating a new physical execution route.

## Post-merge preservation

The exact qualified dependency surface is byte-identical on canonical:

    runtime core 283c812deeaec151caad520adfb3d8df39e894d0
    backend      e0e995783bfe5c92c8a58c385c05f0bb25faaf60
    test         62974abf9a58a645e822454b5288c4830963a0f2
    runner       1c91c2a2935fdfee9c51a299fac9d06c2c15bdb4

The focused O0/O2 qualification is therefore inherited without replay.

## Explicit non-claims

A20 does not admit:

- live RFM stepping;
- RFM runtime forcing/parameter wiring;
- wall exchange;
- fast-domain release/bottom outflow;
- external encoded restart-file codec compatibility;
- combined RFM + snow/temperature/surface-water layouts.

## Lifecycle

    implemented -> persisted -> tested -> qualified -> canonically admitted -> closed

## Next safe step

A21 may open the first live bounded RFM runtime composition, but only after its
preregistration owns the complete candidate interval:

    existing B1.10 preflight
    -> A11/A12/A13 activation inputs
    -> A15 surface receipt
    -> A16 matrix-share rebound and re-verification
    -> matrix solve
    -> A17 preferential routing
    -> A19 fast-state candidate
    -> whole-column storage/external-flux accounting

A21 must remain fail-closed to the existing Reference route for ponded,
head-controlled, runoff-active, invalid or unsupported cases.

The A20 runtime-reject guard must not be removed before that complete composition
is qualified.
