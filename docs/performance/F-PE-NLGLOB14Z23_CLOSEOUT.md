# F-PE-NLGLOB14Z23 closeout — settled publication versus ownership confirmation

Date: 2026-09-30

Final status:

`QUALIFIED_Z23_SETTLED_PUBLICATION_WITH_CONFIRMATION_FALSIFIED`

Qualification authority:

- workflow run `36715199893`;
- job `109886299547`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

## Closure

Z23 closes positively for settled-event publication and negatively for simple committed-ownership confirmation.

For both fine O05 fixtures:

- the exact Z22 internal physical and ownership trajectory remains the reference;
- publishing every internal ownership change is valid but exposes chatter;
- settled-event publication coalesces each consecutive ownership-change burst without altering accepted physical state or internal ownership;
- only two publication transactions are required;
- only the deeper transaction has a net ownership change, `13:16 -> 14:16`;
- coupling-visible reverse ownership is removed in the frozen sequences;
- final published ownership equals final internal ownership.

Simple committed-ownership confirmation/dwell is falsified because a clean opposite-tail accepted state cannot retain the old ownership without violating exact accepted geometry, while rejecting that state would suppress an otherwise valid time-advancing physical interval.

## Mechanistic conclusion

The anti-chatter intervention belongs, if anywhere, at the event-publication/coupling boundary rather than in physical ownership.

Internal ownership must continue to follow accepted physical state exactly.

## Direct successor

Preregister a coupling-contract study for settled-event publication.

The successor must test whether a publication transaction that remains open through an internal finite chatter burst can preserve:

- one physical interface authority;
- interval-by-interval exchanged-water accounting;
- accepted time integration;
- deterministic transaction start and settlement time;
- rollback semantics;
- external coupling consistency.

Do not treat the Z23 publication result as production admission.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z23

BRANCH: `research/f-pe-nlglob14z23-anti-chatter-comparison`

RESEARCH POSTIMAGE BEFORE CLOSEOUT: `409e3ab2fa70e7a148992247d8d3fedfb8ef3e85`

QUALIFICATION RUN: `36715199893`

QUALIFICATION STATUS: `QUALIFIED_Z23_SETTLED_PUBLICATION_WITH_CONFIRMATION_FALSIFIED`

NEXT SAFE STEP: coupling/publication-contract qualification for settled-event transactions.

## Production boundary

No production source/default change.

`LEGACY_NUMERICS` remains production default.
