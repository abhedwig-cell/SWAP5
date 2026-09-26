# F-PE-REPAIR01 closeout — inactive-root qbot scratch ownership

Date: 2026-09-26

Status: `CLOSED_REPAIR_QUALIFIED`

PR:
`#635 — F-PE-REPAIR01: inactive-root qbot scratch ownership`

Branch:
`work/f-pe-repair01-inactive-root-qbot`

Parent:
`F-PE-REPRO01`

## Defect

For B1.10 prescribed-head mode 5, bottom-flux materialization unconditionally summed:

`richards%provider_root_sink`

even when no root-sink provider was associated.

On the inactive-root route that array is non-authoritative worker scratch and need not have been written.

REPRO01 proved this could feed process-dependent memory contents into qbot reconstruction and produce intermittent exact first-corrector status 6.

## Repair

The production materializer now follows explicit ownership:

- associated root-sink provider: preserve the existing root-sink sum;
- no root-sink provider: root contribution is exactly zero.

No whole-workspace reset was introduced.

No solver, temporal, retry or constitutive policy changed.

## Qualification

All dedicated repair gates pass:

- inactive-root poisoned scratch regression;
- active-root physical and tangent preservation;
- fixed-build exact repeatability: 20/20;
- fixed-build A2C repeatability: 20/20;
- A1 live coupled control;
- six independent A2C live coupled replicas;
- A2C application-shaped mass/accounting gate.

The formerly deterministic ROOT_SINK poison failure changed from 0/40 PASS before the repair to 40/40 PASS after the repair.

All six A2C coupled replicas retained exact coupled endpoints.

## Numerical and performance consequence

The repair is correctness-first but also avoids a tempting performance regression.

The defect is not repaired by zeroing the full Reference workspace. Only the non-authoritative inactive-root contribution is excluded.

That preserves the zero-waste ownership principle while restoring deterministic qbot materialization.

The repaired postimage is therefore suitable again for performance measurement.

## Decision

F-PE-REPAIR01 is content-closed and qualified.

The exact/default live route is restored as coupled reference authority for the qualified sample.

A1 remains preserved.

A2C remains default OFF but its coupled qualification is restored on the repaired postimage.

The next performance work should resume the observation-only combined practical-stack rebaseline rather than open another optimization immediately.
