# F-PE-NLGLOB14Z15 result — split ownership through 12:16 -> 13:16

Date: 2026-09-30

Status:

`NLGLOB14Z15_COUPLING_NOT_CLOSED`

with preserved four-fixture accepted-event evidence.

Qualification authority:

- workflow run: `36682681615`;
- segment A jobs:
  - HEAD coarse `109781410979`;
  - HEAD fine `109781411006`;
  - RUNOFF coarse `109781410923`;
  - RUNOFF fine `109781410648`;
- segment B jobs:
  - HEAD coarse `109786095855`;
  - HEAD fine `109786096005`;
  - RUNOFF coarse `109786096036`;
  - RUNOFF fine `109786095890`.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

Can all four split trajectories complete 280.0 d while independently accepting:

`12:16 -> 13:16`

and moving ownership:

`face 11/12 -> face 12/13`?

## Checkpoint continuity

PASS for all four fixtures.

At 140.0 d every segment-A checkpoint has:

- exact h roundtrip;
- exact theta roundtrip;
- accepted saturated tail `12:16`;
- unchanged temporal ownership;
- rollback difference 0;
- no synthetic checkpoint event.

Observed segment-A maxima remain inside the frozen gates.

## Coarse fixtures

Both coarse trajectories qualify the full frozen 280.0 d contract.

### HEAD, dt = 1.25e-4 d

- complete 280.0 d;
- exact accepted `12:16 -> 13:16`;
- split event time: `260.947000 d`;
- control comparator: `260.961125 d`;
- final accepted tail: `13:16`;
- rejected intervals: 0;
- chatter: 0;
- reverse: 0;
- skipped faces: 0;
- max interval mass ledger: about `1.21e-9 cm`;
- max residual: about `1.00e-10`;
- rollback: 0.

### RUNOFF, dt = 1.25e-4 d

- complete 280.0 d;
- exact accepted `12:16 -> 13:16`;
- split event time: `260.944000 d`;
- control comparator: `260.957875 d`;
- final accepted tail: `13:16`;
- rejected intervals: 0;
- chatter: 0;
- reverse: 0;
- skipped faces: 0;
- max interval mass ledger: about `1.46e-9 cm`;
- max residual: about `1.00e-10`;
- rollback: 0.

## Fine fixtures

Both fine trajectories accept the target event and move ownership before failing the later completion requirement.

### HEAD, dt = 6.25e-5 d

- exact accepted event time: `260.933500 d`;
- accepted post-event tail: `13:16`;
- ownership change `face 11/12 -> face 12/13` is recorded;
- checkpoint continuity exact;
- max interval mass ledger: about `1.62e-9 cm`;
- max residual: about `1.00e-10`;
- rollback: 0;
- chatter: 0;
- reverse: 0;
- skipped faces: 0;
- next attempted interval fails the frozen upper-domain validity gate;
- failure classification in the harness: `UPPER`;
- rejected intervals: 1.

### RUNOFF, dt = 6.25e-5 d

- exact accepted event time: `260.9303125 d`;
- accepted post-event tail: `13:16`;
- ownership change `face 11/12 -> face 12/13` is recorded;
- checkpoint continuity exact;
- max interval mass ledger: about `1.49e-9 cm`;
- max residual: about `1.00e-10`;
- rollback: 0;
- chatter: 0;
- reverse: 0;
- skipped faces: 0;
- next attempted interval fails the frozen upper-domain validity gate;
- failure classification in the harness: `UPPER`;
- rejected intervals: 1.

## Aggregate interpretation

The frozen positive Z15 classification requires all four trajectories to complete 280.0 d.

That requirement is not met because both fine fixtures fail immediately after the accepted target transition.

Therefore Z15 does not receive:

`QUALIFIED_SPLIT_RETREAT_12_TO_13_OWNERSHIP_TRANSITION`.

The closest frozen negative class is:

`NLGLOB14Z15_COUPLING_NOT_CLOSED`

because the long-horizon split continuation is not closed for all four fixtures while accepted-state rollback and mass remain clean.

## Preserved scientific evidence

Z15 nevertheless establishes four-fixture accepted-event evidence for:

`12:16 -> 13:16`

and state-derived ownership:

`face 11/12 -> face 12/13`.

All four independently reach the target transition.

The two fine failures occur only after the target event has already been accepted and committed.

No event timing is imposed from control.

## Scientific consequence

The unresolved question is no longer whether the ownership transition exists.

The bounded next question is whether the accepted target event itself can be qualified as the endpoint of the workunit without requiring unrelated post-event continuation to 280 d.

A separately preregistered event-terminated confirmatory successor is therefore appropriate.

It must stop immediately after the exact accepted `12:16 -> 13:16` transition and require:

- exact state-derived ownership move;
- contiguous accepted geometry;
- physical mass;
- nonlinear residual gate;
- rollback authority;
- no chatter/reverse/skip;
- provider-faithful dry top.

It must not attempt to repair or bypass the post-event `UPPER` boundary.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
