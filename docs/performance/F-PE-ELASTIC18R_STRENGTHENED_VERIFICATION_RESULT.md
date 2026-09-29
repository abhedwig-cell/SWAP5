# F-PE-ELASTIC18R — strengthened post-admission verification result

Date: 2026-09-29

Status: QUALIFIED_PRESERVATION

Branch:
`work/f-pe-elastic18r-strengthened-verification`

Qualified postimage:
`768bb320f5d891fdabf7e99f78a8e20728e87967`

Workflow run:
`36561553299`

Job:
`109383373261`

Conclusion:
SUCCESS.

## Production identity

The admitted ELASTIC18 production blob was verified before replay:

`src/adapter/mod_fmr_elastic_storage_swap_grid_normalization.f90`

blob:

`d9138f57a2c0b354b454cf99062b84d8b584d1c2`.

Marker:
`F_PE_ELASTIC18R_PRODUCTION_BLOB=PASS`.

No production source differs from current canonical.

Marker:
`F_PE_ELASTIC18R_PRODUCTION_DIFF_EMPTY=PASS`.

## Strengthened fail-closed coverage

The post-admission oracle retains all original ELASTIC18 checks and additionally
executes the preregistered cases that were not explicit in the original
canonical test source:

- negative compartment thickness;
- z/dz shape mismatch;
- adjacent-compartment overlap.

The existing negative cases remain covered:
- non-finite geometry;
- zero thickness;
- above-surface node centre;
- compartment gap.

All pass at O0 and O2.

## Preserved original gates

Observed:

- `F_PE_ELASTIC18_A1_CANONICAL_GRID=PASS`;
- `F_PE_ELASTIC18_A2_HETEROGENEOUS=PASS`;
- `F_PE_ELASTIC18_A3_SIGN_FAIL_CLOSED=PASS`;
- `F_PE_ELASTIC18_A4_VALUE_FAIL_CLOSED=PASS`;
- `F_PE_ELASTIC18_A5_CONTIGUITY_FAIL_CLOSED=PASS`;
- `F_PE_ELASTIC18_A6_ELASTIC17_COMPOSITION=PASS`;
- `F_PE_ELASTIC18_A7_O0_O2=PASS`;
- `F_PE_ELASTIC18_A8_SOURCE_SCOPE=PASS`.

## Qualification correction trail

A prior strengthened run `36560803732` failed at test compilation because the
test source omitted the already existing `FMR_ELAS_GRID_INVALID_SHAPE` import.

That failure occurred before executing the oracle and did not indicate a
production semantic defect.

The final preservation postimage:
- imports the status correctly;
- uses the actual runner temporary directory instead of an escaped literal path;
- changes no production code.

## Decision

The already admitted ELASTIC18 production capability remains qualified.

ELASTIC18R strengthens executable preservation evidence only.

Classification:

`QUALIFIED_PRESERVATION_NO_PRODUCTION_CHANGE`.
