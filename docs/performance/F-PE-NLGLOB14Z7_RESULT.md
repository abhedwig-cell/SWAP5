# F-PE-NLGLOB14Z7 result — confirmatory control retreat 9:16 -> 10:16

Date: 2026-09-29

Status:

`QUALIFIED_CONFIRMATORY_RETREAT_9_TO_10_CONTROL`

Qualification authority:

- workflow run: `36632663817`;
- job: `109625497581`;
- conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Confirmatory scope

This workunit was preregistered as confirmatory because an earlier long Z4 diagnostic trajectory had incidentally ended beyond `9:16`.

That incidental observation is not used as qualification authority.

Z7 uses a new exact event gate and includes a new finer dt level.

## Coverage

PASS.

All four O05 control fixtures complete the frozen 25.60 d horizon:

- HEAD, dt = 6.25e-5 d;
- HEAD, dt = 3.125e-5 d;
- RUNOFF, dt = 6.25e-5 d;
- RUNOFF, dt = 3.125e-5 d.

All four expose the exact accepted contiguous transition:

`9:16 -> 10:16`.

Aggregate classification:

`QUALIFIED_CONFIRMATORY_RETREAT_9_TO_10_CONTROL`.

## Event times

HEAD:

- dt 6.25e-5 d: 21.4572500 d;
- dt 3.125e-5 d: 21.4573125 d.

RUNOFF:

- dt 6.25e-5 d: 21.4540625 d;
- dt 3.125e-5 d: 21.4541250 d.

The two resolution levels differ by one coarse-half timestep in both route families.

## Geometry and mass

All fixtures remain:

- finite;
- contiguous in accepted lower saturated geometry;
- free of reverse late-phase expansion;
- free of skipped retreat nodes;
- h/theta saturation-indicator consistent.

Observed maxima:

- interval physical mass ledger: about `2.36e-14 cm`;
- cumulative physical mass ledger: about `7.87e-13 cm`.

At 25.60 d all final accepted saturated sets are nodes 10:16.

## Scientific interpretation

The physical saturated lower block continues its accepted retreat sequence well beyond 12.8 d.

The newly confirmed event is:

`9:16 -> 10:16`

near 21.45 d.

The increasing event spacing remains substantial, so complete disappearance still cannot be inferred by extrapolation.

## Consequence

A separately preregistered split successor may now test state-derived ownership transition:

`face 8/9 -> face 9/10`

when its own accepted saturated set changes:

`9:16 -> 10:16`.

Control times remain comparator-only.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
