# PPA-WU05-A16 closeout — canonical bounded RFM matrix-share dynamic-top rebinding

Date: 2026-10-01

Status: CLOSED_CANONICAL_ADMITTED

Decision:

    CANONICALLY_ADMITTED_BOUNDED_RFM_MATRIX_SHARE_DYNAMIC_TOP_REBINDING

## Canonical evidence

- baseline: `ecfe628daf78988aec3a784f1b91b9d110d95850`
- qualified postimage: `c4783e6e59abb76d5c3b084e947fb3673416ae91`
- qualification run: `36864593396` — SUCCESS
- admission PR: #939
- canonical merge: `5bb8d8381f29cd7b6d6fa456c6634643e5ab99b8`

Run `36864496237` failed only because the focused runner referenced the
evaporation module at the wrong path. The runner path alone was repaired before
the successful exact-head qualification.

## Admitted capability

A16 can construct a fresh B1.10 matrix dynamic-top request from the A15 matrix
share, with:

    matrix share as the only positive surface source
    original source components removed
    surface evaporation demands removed after upstream ownership
    previous/candidate ponding required zero

and verify the rebound using the existing B1.10 owner.

Only a result that remains:

    flux-controlled
    unponded
    runoff-free

is accepted.

Otherwise the interval returns to the existing Reference route.

## Real-provider evidence

The production B1.10/default-MvG test fixture confirms:

    base effective supply = 8 cm/day
    A15 matrix share = 5.961748798503473 cm/day
    rebound regime = flux
    rebound ponding = 0
    rebound runoff = 0
    rebound net surface supply = matrix share

A deliberately excessive rebound source moves into head control and is rejected
to Reference.

## Architecture boundary

A16 remains a composition primitive.

It does not:

- mutate a live solver request;
- commit physical/history state;
- route the preferential share;
- change A8/A9/A10 runtime behavior;
- admit RFM under ponding/head-control.

## Post-merge preservation

The qualified dependency surface is byte-identical on canonical:

    source 54900d2895c2aba40d1740d5f27beb5f71d7967a
    test   29e7cbdc2ad9778cd17398e45f83b4fa15567182
    runner 5f134e45c6133ecfeb13051e4bc5c1b610476014

The focused qualification is therefore inherited without a second replay.

## Lifecycle

    implemented -> persisted -> tested -> qualified -> canonically admitted -> closed

## Next safe step

Before a live runtime composition can consume A11-A16, A17 must reconcile the
preferential-share owner.

The required question is:

    where does A15 preferential_supply enter the fast domain,
    and which candidate/receipt owner guarantees exactly-once whole-column mass?

No live composition should be admitted until that ownership is explicit.
