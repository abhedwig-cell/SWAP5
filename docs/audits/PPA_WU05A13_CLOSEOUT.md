# PPA-WU05-A13 closeout — canonical RFM surface-event age service

Date: 2026-10-01

Status: CLOSED_CANONICAL_ADMITTED

Decision:

    CANONICALLY_ADMITTED_RFM_SURFACE_EVENT_AGE_SERVICE

## Canonical evidence

- baseline: `ae4eede414692fb0071ea093050f5accd36dd48d`
- qualified postimage: `9ab2f5996c6698916c5febe1ddb8a2685ee8d56c`
- focused qualification run: `36861648257` — SUCCESS
- admission PR: #934
- canonical merge: `77a73c4bac08b92549890fa90139a13b37649bb0`

## Admitted capability

Canonical production source now contains a transaction-safe surface-event-age
primitive for RFM.

For an already segmented active interval:

    evaluation_age = accepted_age + 0.5*dt
    candidate_age  = accepted_age + dt

For an inactive interval:

    evaluation_age = 0
    candidate_age  = 0

The caller remains owner of event-active identity, interval segmentation,
commit/discard and effective infiltrating source definition.

## Transaction and restart boundary

A13 performs pure candidate construction and does not mutate accepted state.

It does not yet add tau_surface to any existing committed/restart layout. A
future runtime composition must assign that state ownership explicitly and
preserve reject/retry semantics.

## Preserved boundaries

A13 does not:

- infer events from rainfall or flux thresholds;
- define a dry-gap threshold;
- change A8/A9/A10 source ownership;
- choose sigma_B;
- route preferential water;
- change existing restart payloads.

## Post-merge preservation

The exact qualified dependency surface is byte-identical on canonical:

    source 93210151f1324dfeedf3fd67dd6616ffdcb5bd67
    test   4c315d493432f72d8f442d42b9456e9419858262
    runner 1c6d717dd98a4aa8b4c238dc5e76264bdf67e3cd

The focused qualification is therefore inherited without a second CI replay.

## Lifecycle

    implemented -> persisted -> tested -> qualified -> canonically admitted -> closed

## Next safe step

Do not yet alter the runtime matrix/macropore source partition.

A14 must first identify an already admitted surface-boundary owner for:

    effective infiltrating supply after surface-boundary handling

including ponding/runoff ownership.

If canonical lacks that explicit contract, runtime RFM source partition is a
real ownership blocker rather than an invitation to invent another runoff law.
