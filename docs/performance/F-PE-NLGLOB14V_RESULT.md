# F-PE-NLGLOB14V result — second-retreat control exposure

Date: 2026-09-29

Status:

`QUALIFIED_SECOND_RETREAT_CONTROL_EXPOSURE`

Qualification authority:

- workflow run: `36604161977`;
- job: `109528796058`;
- conclusion: SUCCESS.

Canonical authority rechecked before result persistence:

`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

## Frozen question

Does the persistent-KLAG physical control expose a genuine accepted second saturated-block retreat

`nodes 4:16 -> nodes 5:16`

under unchanged dry forcing, independently of split-solver behavior?

## Coverage

PASS.

All 8 HEAD/RUNOFF x four-dt fixtures complete, remain finite, preserve contiguous saturation geometry and remain mass-clean.

The staged 0.10 d horizon did not cover the event in all fixtures, so the preregistered 0.20 d stage was used.

All 8 fixtures expose exactly:

- pre-event saturated set: nodes 4:16, count 13;
- post-event saturated set: nodes 5:16, count 12;
- no noncontiguous set;
- no reverse 12 -> 13 move after the event.

Aggregate classification:

`QUALIFIED_SECOND_RETREAT_CONTROL_EXPOSURE`.

## Event timing

HEAD:

- dt 2.5e-4 d: 0.10625 d;
- dt 1.25e-4 d: 0.106125 d;
- dt 6.25e-5 d: 0.1060625 d;
- dt 3.125e-5 d: 0.10596875 d.

RUNOFF:

- dt 2.5e-4 d: 0.10600 d;
- dt 1.25e-4 d: 0.106125 d;
- dt 6.25e-5 d: 0.10600 d;
- dt 3.125e-5 d: 0.1059375 d.

The second retreat is therefore exposed near 0.106 d in both route families.

This workunit qualifies event exposure, not a separate formal event-time convergence law.

## Physical admissibility

Maximum accepted-interval physical mass ledger is about `2.36e-14 cm`.

Maximum cumulative physical mass ledger is about `3.51e-14 cm`.

No control process failure occurs.

## Scientific interpretation

The absence of ownership-face motion in NLGLOB14U was a horizon issue, not evidence that the lower saturated edge is pinned.

Under the unchanged dry forcing, the control eventually retreats from node 4 to node 5 at about 0.106 d.

This supplies an independently exposed physical event against which the split accepted-state ownership rule can now be tested.

## Consequence

A separately preregistered successor may now test whether the split accepted-state trajectory:

- remains transactionally and mass conservative through the event;
- changes ownership face from 3/4 to 4/5 only when its accepted physical state changes from 4:16 to 5:16;
- avoids chatter or reverse ownership;
- remains close to the persistent-KLAG control without fitting event time, h or theta thresholds.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
