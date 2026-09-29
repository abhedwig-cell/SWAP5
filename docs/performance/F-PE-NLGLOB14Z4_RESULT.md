# F-PE-NLGLOB14Z4 result — later-retreat control exposure beyond 8:16

Date: 2026-09-29

Status:

`QUALIFIED_NEXT_LATE_RETREAT_CONTROL_EXPOSURE`

Qualification authority:

- workflow run: `36621713582`;
- job: `109588470735`;
- conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

Does the accepted persistent saturated-KLAG control expose the next physical lower-edge retreat beyond `8:16`?

## Coverage

PASS.

All four O05 control fixtures complete the first frozen 12.8 d stage:

- HEAD, dt = 1.25e-4 d;
- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 1.25e-4 d;
- RUNOFF, dt = 6.25e-5 d.

All remain finite, mass-clean and geometrically consistent.

## Physical event

All four expose the exact accepted transition:

`8:16 -> 9:16`.

Event times:

HEAD:

- dt 1.25e-4 d: 7.65275 d;
- dt 6.25e-5 d: 7.65275 d.

RUNOFF:

- dt 1.25e-4 d: 7.649625 d;
- dt 6.25e-5 d: 7.649625 d.

The event is therefore stable across the two complete control resolutions.

## Geometry

No fixture shows:

- reverse late-phase expansion;
- skipped node;
- noncontiguous accepted saturated tail;
- h/theta saturation-indicator inconsistency.

At 12.8 d all four final accepted saturated sets are nodes 9:16.

## Physical mass

Observed maxima:

- accepted-interval physical mass ledger: about `2.36e-14 cm`;
- cumulative physical mass ledger: about `1.16e-12 cm`.

No residual redistribution or mass correction is used.

## Instrumentation note

The first two workflow attempts were instrumentation-only failures before solver execution.

The successful run uses event-only accepted-state logging. This changes diagnostics volume only and does not alter solver, forcing, timestep, state, mass accounting or provider semantics.

## Scientific interpretation

The physical lower saturated edge continues to retreat at increasingly late times:

`7:16 -> 8:16 -> 9:16`.

The newly qualified `8:16 -> 9:16` transition occurs near 7.65 d.

Complete disappearance is still not exposed and must not be inferred.

## Consequence

A separately preregistered split accepted-state successor may now test state-driven ownership transition:

`face 7/8 -> face 8/9`

when its own accepted saturated set changes:

`8:16 -> 9:16`.

Control event times are comparators only and must not trigger split ownership.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
