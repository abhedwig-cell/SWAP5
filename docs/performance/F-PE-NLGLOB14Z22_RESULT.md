# F-PE-NLGLOB14Z22 result — post-14:16 bidirectional continuation

Date: 2026-09-30

Status:

`NLGLOB14Z22_POST14_CHATTER`

Qualification authority:

- workflow run: `36710114782`;
- HEAD fine segment-B job: `109874968586`;
- RUNOFF fine segment-B job: `109874968567`;
- workflow conclusion: SUCCESS.

Canonical authority rechecked before persistence:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

Research postimage before result persistence:

`research/f-pe-nlglob14z22-post14-bidirectional@dc26819e47be279379ed7ae7b0ba0870cfcb43b2`

## Frozen question

After the qualified Z21 accepted retreat:

`13:16 -> 14:16`

does unchanged exact accepted-state bidirectional ownership remain stable through 540 d, continue to `15:16`, reverse, or develop another chatter burst?

## Aggregate result

Both frozen fine O05 fixtures classify:

`POST14_CHATTER`.

Therefore the frozen aggregate classification is:

`NLGLOB14Z22_POST14_CHATTER`.

This is a qualified negative semantics result, not a solve or transaction failure.

## HEAD fine

The Z21 target event is reproduced exactly at:

`514.6110625 d`.

Immediately afterward the accepted ownership sequence is:

1. reverse `14:16 -> 13:16`;
2. retreat `13:16 -> 14:16`;
3. reverse `14:16 -> 13:16`;
4. retreat `13:16 -> 14:16`;
5. reverse `14:16 -> 13:16`;
6. retreat `13:16 -> 14:16`;
7. reverse `14:16 -> 13:16`;
8. retreat `13:16 -> 14:16`.

The burst occupies offsets 4,058,841 through 4,058,848 after the committed Z18 reverse event.

After that, ownership remains at `14:16` through 540 d.

Diagnostics:

- post-14 ownership changes: 8;
- post-14 direction changes: 7;
- final accepted tail: `14:16`;
- final time: 540.0 d;
- max interval physical mass ledger: about `1.62e-9 cm`;
- max nonlinear residual: about `1.00e-10`;
- max rollback: 0;
- provider route: `surface-flux`;
- geometry remains contiguous and one-face.

## RUNOFF fine

The Z21 target event is reproduced exactly at:

`514.6081875 d`.

Immediately afterward the accepted ownership sequence is:

1. reverse `14:16 -> 13:16`;
2. retreat `13:16 -> 14:16`;
3. reverse `14:16 -> 13:16`;
4. retreat `13:16 -> 14:16`.

The burst occupies offsets 4,058,846 through 4,058,849 after the committed Z18 reverse event.

After that, ownership remains at `14:16` through 540 d.

Diagnostics:

- post-14 ownership changes: 4;
- post-14 direction changes: 3;
- final accepted tail: `14:16`;
- final time: 540.0 d;
- max interval physical mass ledger: about `1.49e-9 cm`;
- max nonlinear residual: about `1.00e-10`;
- max rollback: 0;
- provider route: `surface-flux`;
- geometry remains contiguous and one-face.

## Scientific interpretation

The finite bidirectional chatter observed around `13:16` is not a one-off feature of that specific interface.

A second local chatter burst appears immediately after the deeper accepted retreat to `14:16` in both fine fixtures.

The burst is again:

- deterministic within each fixture;
- finite;
- transaction-clean;
- mass-clean;
- contiguous;
- one-face;
- provider-valid.

Its lifetime differs between fixtures:

- HEAD: 8 post-14 changes;
- RUNOFF: 4 post-14 changes.

Both self-settle at `14:16` and remain there through 540 d.

This establishes that exact no-hysteresis bidirectional accepted-state ownership can repeatedly generate short local direction-flip chatter at moving-interface events.

It does not establish persistent instability.

## Qualified claim boundary

Established:

- the Z21 `13:16 -> 14:16` retreat reproduces exactly;
- both fine fixtures develop immediate post-14 bidirectional chatter;
- the chatter is finite through the tested 540 d horizon;
- all hard solve, mass, rollback, provider and geometry gates remain valid;
- no `14:16 -> 15:16` retreat occurs through 540 d.

Frozen aggregate result:

`NLGLOB14Z22_POST14_CHATTER`.

Not qualified:

- a universal chatter lifetime;
- a production anti-chatter mechanism;
- hysteresis thresholds;
- dwell-time policy;
- event coalescing;
- continuation to `15:16` beyond 540 d;
- disappearance;
- whole-column TG re-entry;
- production temporal ownership.

## Consequence

The evidence now changes the successor priority.

Because finite chatter recurs at more than one moving-interface event, the next research step should compare minimal anti-chatter semantics rather than assuming event-local chatter can simply be ignored.

The successor must not fit a pressure or theta threshold to these event times.

Candidate mechanisms should remain state-based and preserve:

- accepted physical state authority;
- bidirectional motion;
- one-interface authority;
- physical mass;
- transaction semantics;
- provider consistency.

A minimal direction-memory or confirmation state machine is now justified for falsification.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
