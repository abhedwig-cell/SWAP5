# PPA-WU05-A17 closeout — canonical explicit-parameter RFM preferential router

Date: 2026-10-01

Status: CLOSED_CANONICAL_ADMITTED

Decision:

    CANONICALLY_ADMITTED_EXPLICIT_PARAMETER_RFM_PREFERENTIAL_ROUTER

## Canonical evidence

- baseline: `f71cccad728b4cc0dc515c449ac6a06a0de30716`
- qualified postimage: `9d4c247666c9641aa1c29f835187dcd4c2afcdbb`
- qualification run: `36865436660` — SUCCESS
- admission PR: #941
- canonical merge: `af049e84bb81cbe1a49924172f77f485189f1d0a`

## Admitted capability

A17 canonically admits the deterministic reduced RFM preferential router with
explicit caller-owned:

    f_MB
    connectivity p
    Z_AH
    Z_IC
    endpoint depth grid

The operator returns:

    MB amount
    IC amount
    endpoint weights
    endpoint amounts

with exact preferential-flow mass closure.

No default RFM structural parameter is admitted.

## Preserved boundaries

A17 does not:

- map endpoint classes into current SWAP macropore domains;
- mutate committed or candidate physical state;
- add restart state;
- implement wall exchange;
- implement transit time;
- implement bottom breakthrough;
- infer or fit f_MB or p.

## Post-merge preservation

The exact qualified dependency surface is byte-identical on canonical:

    source 24a100a0f2a063238c072545bdf30dea48a68f3f
    test   eb3cee4e1bf98725e612062cceac732f351ec9df
    runner eb3da0107900fcff1b8faa254fcc73c2d1e3d96b

The focused qualification is inherited without a second replay.

## Lifecycle

    implemented -> persisted -> tested -> qualified -> canonically admitted -> closed

## Next safe step

A18 must determine whether the A17 routing receipt can be represented in an
existing committed/candidate fast-domain state without changing its physical
meaning.

The existing standard SWAP macropore domains may not be reused merely as a
convenient container if doing so would silently impose current SWAP geometry on
RFM endpoint classes.

Exactly-once candidate/commit/restart ownership is required before live runtime
composition.
