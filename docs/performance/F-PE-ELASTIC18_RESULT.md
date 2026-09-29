# F-PE-ELASTIC18 — SWAP grid normalization result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic18-grid-normalization`

Qualified postimage:
`9839864e165dd555920df02d9a25b5090a402255`

Workflow run:
`36560891383`

Job:
`109381212514`

Conclusion:
SUCCESS.

## Production scope

Exactly one production source file is added:

`src/adapter/mod_fmr_elastic_storage_swap_grid_normalization.f90`.

No existing production source is modified.

## Qualified contract

The adapter accepts explicitly typed raw grid inputs:

- `z_cm(:)`;
- `dz_cm(:)`.

It returns:

- node centre depth in metres below soil surface;
- node compartment thickness in metres.

Frozen transformation:

`node_depth_m = -0.01 * z_cm`

`node_thickness_m = 0.01 * dz_cm`.

No generic unit detection is performed and `abs(z)` is not used.

## Grid consistency

The adapter independently reconstructs expected node centres from cumulative
compartment thickness:

`expected_z_i = -(sum(dz_1..dz_(i-1)) + dz_i/2)`.

Supplied `z_cm` must agree within `1e-8 cm`.

This rejects hidden:
- gaps;
- overlaps;
- reordered nodes;
- wrong sign conventions;
- profiles not starting at the soil surface.

## Qualification results

A1 uniform centimetre grid normalization: PASS.

A2 heterogeneous contiguous grid normalization: PASS.

A3 positive z, non-finite input, non-positive thickness and shape mismatch fail
closed: PASS.

A4 centre/thickness inconsistency fails closed: PASS.

A5 normalized geometry composes with admitted ELASTIC17 and produces the
expected horizon ownership: PASS.

A6 material-boundary straddling remains visible and is rejected by ELASTIC17;
ELASTIC18 does not hide it: PASS.

A7 O0/O2 identity: PASS.

A8 source scope:
`src/adapter/mod_fmr_elastic_storage_swap_grid_normalization.f90`
only: PASS.

## Unit/provenance boundary

The centimetre assumption is explicit in the public adapter boundary.

Supporting repository evidence includes:
- the established HeadCalc/ROM grid materializer `--dz-cm`, which directly
  constructs `MOD_grid z`, `dz` and `disnod`;
- the SWAP scientific positive-up z convention;
- the admitted centimetre-based hydraulic/storage convention.

The adapter does not claim that an arbitrary unnamed external grid uses
centimetres.

## Admission meaning

A green ELASTIC18 closes the raw SWAP-style cm-grid to normalized ELASTIC17
geometry seam.

It does not admit:
- unit guessing;
- grid resampling;
- compartment splitting;
- BOFEK/BRO data retrieval;
- horizon selection;
- file parsing;
- automatic generated-prior request.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
