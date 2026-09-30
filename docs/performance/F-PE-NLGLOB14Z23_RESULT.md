# F-PE-NLGLOB14Z23 result — repeated finite chatter strategy comparison

Date: 2026-09-30

Status:

`QUALIFIED_Z23_SETTLED_PUBLICATION_WITH_CONFIRMATION_FALSIFIED`

Qualification authority:

- workflow run: `36715199893`;
- strategy-comparison job: `109886299547`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

Research postimage before result persistence:

`research/f-pe-nlglob14z23-anti-chatter-comparison@4633401730847b22dda8d51697e5c142c7d4443d`

## Frozen question

Given the repeated finite bidirectional ownership chatter established by Z20-Z22, which minimal response remains compatible with the exact accepted physical trajectory without fitting h/theta thresholds?

The frozen strategies were:

1. publish every internal ownership change as-is;
2. keep internal ownership unchanged but coalesce coupling-visible publication until the event-local burst settles;
3. delay opposite committed ownership until later confirmation.

## Aggregate result

The frozen aggregate classification is:

`QUALIFIED_Z23_SETTLED_PUBLICATION_WITH_CONFIRMATION_FALSIFIED`.

Both fixtures establish:

- `ACCEPT_AS_IS_VALID`;
- `SETTLED_PUBLICATION_EQUIVALENT`;
- `SIMPLE_CONFIRMATION_SEMANTICALLY_INCOMPATIBLE`.

No hard reference inconsistency occurs.

## HEAD fine

### Accept as-is

The complete reference sequence contains 15 published ownership changes when the already-committed initial reverse event is included.

- reverse publications: 7;
- longest alternating burst: 9 ownership changes;
- final published tail: `14:16`.

This is physically valid but coupling-visible chatter remains explicit.

### Settled-event publication

The same internal accepted-state and ownership trajectory is retained exactly.

The publication rule identifies two event transactions.

First transaction:

- starts with the committed reverse around 260.9335625 d;
- internal ownership changes: 6;
- origin tail: `13:16`;
- settled tail: `13:16`;
- settlement: 260.9339375 d;
- net ownership change: none.

Second transaction:

- starts at the deeper retreat at 514.6110625 d;
- internal ownership changes: 9;
- origin tail: `13:16`;
- settled tail: `14:16`;
- settlement: 514.611625 d;
- net ownership change: one retreat.

Thus 15 coupling-visible ownership publications reduce to two event-transaction publications, of which only one changes the final published ownership.

No accepted physical state is suppressed, internal ownership remains the sole physical authority, and final published ownership equals the qualified reference final ownership.

### Simple committed-ownership confirmation

Classification:

`SIMPLE_CONFIRMATION_SEMANTICALLY_INCOMPATIBLE`.

Thirteen opposite-direction moves are exposed.

For each clean opposite-tail accepted state, delaying the ownership move would require one of two prohibited outcomes:

- accept a physical state whose exact saturated-tail geometry conflicts with the retained ownership; or
- suppress/reject an otherwise valid time-advancing accepted physical interval.

Therefore simple confirmation/dwell cannot preserve the frozen accepted-state authority.

## RUNOFF fine

### Accept as-is

The complete reference sequence contains 11 ownership publications including the committed initial reverse event.

- reverse publications: 5;
- longest alternating burst: 6;
- final published tail: `14:16`.

### Settled-event publication

Again, the unchanged internal trajectory produces exactly two event transactions.

First transaction:

- starts at 260.930375 d;
- internal ownership changes: 6;
- origin tail: `13:16`;
- settled tail: `13:16`;
- settlement: 260.93075 d;
- net ownership change: none.

Second transaction:

- starts at 514.6081875 d;
- internal ownership changes: 5;
- origin tail: `13:16`;
- settled tail: `14:16`;
- settlement: 514.6085 d;
- net ownership change: one retreat.

Final published ownership again equals the exact internal reference ownership.

### Simple committed-ownership confirmation

Classification:

`SIMPLE_CONFIRMATION_SEMANTICALLY_INCOMPATIBLE`.

Nine opposite-direction moves are exposed and the same accepted-state ownership contradiction applies.

## Scientific interpretation

Repeated finite chatter does not require redefining the physical state or inserting a fitted hysteresis band.

The evidence instead separates two concerns that had previously been conflated:

1. internal physical ownership, which must continue to follow each exact accepted state;
2. coupling-visible event publication, which need not necessarily expose every internal direction flip as a separate external event.

A settled-event publication transaction can remove coupling-visible reverse chatter in the frozen fixtures while leaving the complete internal physical trajectory unchanged.

By contrast, a simple ownership dwell/confirmation rule acts at the wrong layer. It attempts to keep committed ownership behind the accepted physical state and therefore conflicts directly with the accepted-state authority established by Z18-Z22.

## Qualified claim boundary

Qualified:

`QUALIFIED_Z23_SETTLED_PUBLICATION_WITH_CONFIRMATION_FALSIFIED`.

Established for the two frozen fine O05 trajectories:

- publishing chatter as-is remains physically valid;
- settled-event publication preserves the internal reference trajectory;
- final published ownership equals final internal ownership;
- coupling-visible reverse ownership can be eliminated in the analyzed event bursts;
- simple committed-ownership confirmation/dwell is semantically incompatible with exact accepted-state ownership.

Not qualified:

- actual coupled-backend behavior under delayed publication;
- a production publication API;
- maximum permissible publication lag;
- coarse-dt behavior;
- broader soil/profile portability;
- performance benefit;
- production temporal-ownership admission.

## Consequence

The next safe successor is not an internal ownership state machine.

It is a coupling/publication-contract study for settled-event publication.

That successor must verify that delayed publication across a short internal ownership burst:

- does not duplicate interface authority;
- does not change exchanged water or accepted time integration;
- does not violate an external coupler's interval-by-interval contract;
- exposes a deterministic transaction boundary and settlement time.

Only after those coupling semantics are qualified should settled-event publication become an admission candidate.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
