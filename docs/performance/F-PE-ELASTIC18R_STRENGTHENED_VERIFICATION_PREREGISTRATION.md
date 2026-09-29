# F-PE-ELASTIC18R — strengthened post-admission grid verification

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRESERVATION_REPLAY

Baseline:
`integration/f-ci-canonical@262190047ff97399cb1368cf45d7965dedf6de86`

Parent authority:
- `F-PE-ELASTIC18_CLOSURE.md`;
- admitted production blob
  `d9138f57a2c0b354b454cf99062b84d8b584d1c2`.

## Purpose

Strengthen the executable preservation evidence for the already admitted
ELASTIC18 SWAP-grid normalization adapter.

This work unit changes no production source.

The original ELASTIC18 preregistration requires fail-closed coverage for:
- shape mismatch;
- non-finite values;
- zero and negative compartment thickness;
- above-surface node centres;
- compartment gaps;
- compartment overlaps.

The admitted canonical test exercises the main conversion, non-finite/zero
thickness, above-surface and gap cases, but does not explicitly execute shape
mismatch, negative thickness and overlap.

ELASTIC18R closes only that verification gap.

## Production identity requirement

The canonical production blob must remain exactly:

`d9138f57a2c0b354b454cf99062b84d8b584d1c2`.

No `src/**` change is authorized.

## Added negative cases

The strengthened oracle must explicitly verify:

1. negative `dz` -> `FMR_ELAS_GRID_INVALID_VALUE`;
2. `z/dz` shape mismatch -> `FMR_ELAS_GRID_INVALID_SHAPE`;
3. overlapping adjacent compartments -> `FMR_ELAS_GRID_NONCONTIGUOUS`.

All existing A1-A6 ELASTIC18 behavior remains unchanged.

## Runner hygiene

The preservation runner must:
- use the real runner temporary directory rather than an escaped literal path;
- compile/run at O0 and O2;
- require identical output;
- require an empty production diff against current canonical.

A production delta is a preservation failure.

## Qualification

R1. admitted production blob identity PASS.

R2. original A1-A6 markers PASS at O0 and O2.

R3. added negative thickness, shape mismatch and overlap cases PASS.

R4. O0/O2 output identity PASS.

R5. production source diff is empty.

## Boundary

ELASTIC18R does not:
- reopen physical parameter inference;
- alter grid conversion semantics;
- change tolerances;
- modify the admitted adapter;
- broaden ELASTIC18 scope.

A green result is preservation/verification evidence only.
