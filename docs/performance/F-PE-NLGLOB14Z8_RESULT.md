# F-PE-NLGLOB14Z8 result — split ownership through 9:16 -> 10:16

Date: 2026-09-30

Status:

`QUALIFIED_SPLIT_FURTHER_LATE_RETREAT_OWNERSHIP_TRANSITION`

Qualification authority:

- coarse fixture run: `36636184285`;
- fine segmented recovery run: `36636224712`;
- fine segment jobs:
  - HEAD A `109637389315`;
  - RUNOFF A `109637389735`;
  - HEAD B `109638471383`;
  - RUNOFF B `109638471210`.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

Can the qualified split accepted-state trajectory independently follow:

`9:16 -> 10:16`

and move temporal ownership only from its own accepted state:

`face 8/9 -> face 9/10`?

## Execution note

The original combined GitHub-hosted execution was externally terminated before fine-dt results completed.

Per the preregistered execution-only amendment, the fine dt=6.25e-5 fixtures were therefore run as:

- exact segment A to 12.8 d;
- exact accepted-state checkpoint;
- segment B from 12.8 to 25.6 d.

No scientific fixture, forcing, timestep, solver tolerance, ownership rule, gate or classification changed.

## Coarse fixtures

Both dt=1.25e-4 trajectories complete 25.6 d and qualify.

HEAD:

- split event: 21.457625 d;
- control event: 21.45725 d;
- difference: +3 dt;
- final tail: 10:16.

RUNOFF:

- split event: 21.454375 d;
- control event: 21.45400 d;
- difference: +3 dt;
- final tail: 10:16.

Both have:

- zero rejected intervals;
- zero chatter;
- zero reverse transitions;
- zero skipped faces;
- zero rollback leakage.

## Fine checkpoint continuity

Both segment-A checkpoints at 12.8 d are exact and valid:

- HEAD final/checkpoint tail: 9:16;
- RUNOFF final/checkpoint tail: 9:16;
- h/theta checkpoint roundtrip: exact;
- no synthetic ownership event at restart;
- segment B resumes from the accepted segment-A endpoint.

Thus the segmented execution preserves trajectory authority.

## Fine fixtures

Both dt=6.25e-5 segmented trajectories jointly complete 25.6 d and qualify.

HEAD:

- split event: 21.45750 d;
- control event: 21.45725 d;
- difference: +4 dt;
- final tail: 10:16.

RUNOFF:

- split event: 21.4543125 d;
- control event: 21.4540625 d;
- difference: +4 dt;
- final tail: 10:16.

Both have:

- zero rejected intervals;
- zero chatter;
- zero reverse transitions;
- zero skipped faces;
- zero rollback leakage.

## Aggregate conservation and nonlinear gates

Across the four fixtures, including both segmented fine trajectories:

- max accepted-interval physical mass ledger: about `1.05e-9 cm`;
- max nonlinear residual: about `9.94e-11`;
- max rollback difference: 0.

All remain inside the frozen gates.

## Accepted ownership sequence

Every qualified split trajectory now reaches:

`4:16 -> 5:16 -> 6:16 -> 7:16 -> 8:16 -> 9:16 -> 10:16`.

Temporal ownership follows:

`3/4 -> 4/5 -> 5/6 -> 6/7 -> 7/8 -> 8/9 -> 9/10`.

Control event times are diagnostic only and never trigger ownership.

## Scientific interpretation

The moving-interface split mechanism remains stable through another substantially later physical retreat, now after more than 21 simulated days.

The state-derived ownership rule has been exercised across six sequential lower-edge retreats with:

- one interface authority;
- no chatter;
- no skipped ownership face;
- no rollback leakage;
- physical mass closure;
- provider-faithful dry top semantics.

## Qualified claim boundary

Qualified:

`QUALIFIED_SPLIT_FURTHER_LATE_RETREAT_OWNERSHIP_TRANSITION`.

Not yet qualified:

- retreats beyond 10:16;
- complete saturated-block disappearance;
- empty-tail transition;
- whole-column TG re-entry;
- production temporal ownership.

## Consequence

Return to independent persistent-KLAG control and expose the next accepted retreat beyond 10:16.

Only after that physical control event exists may split ownership be extended again.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
