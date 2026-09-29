# F-PE-ELASTIC18 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@7323dce8a9addf2abc1f5624d95e6ce0d04a969c`

Merged PR:
`#804`

Admitted production file:
`src/adapter/mod_fmr_elastic_storage_swap_grid_normalization.f90`

Admitted production blob:
`d9138f57a2c0b354b454cf99062b84d8b584d1c2`

## Admission summary

F-PE-ELASTIC18 admits the bounded SWAP-grid normalization seam:

`z_cm,dz_cm`
-> node depth/thickness in metres below soil surface
-> admitted ELASTIC17 horizon-node mapping.

The adapter owns unit/sign normalization and grid-contiguity validation only.

## Clean qualification authority

Clean extraction:
`work/f-pe-elastic18-clean-admission@ef3723bff884b5def6494f16a4576408fd764baa`

Qualification:
- workflow run `36560822452`;
- job `109380988592`;
- conclusion SUCCESS.

Named passes:
- canonical SWAP grid fixture;
- heterogeneous compartment grid;
- sign fail closed;
- invalid/non-finite thickness/value fail closed;
- gap/overlap contiguity fail closed;
- ELASTIC17 composition;
- O0/O2 identity;
- production source scope.

## Blob identity

The admitted canonical production blob and clean qualification blob are
identical:

`d9138f57a2c0b354b454cf99062b84d8b584d1c2`.

No production source changed between clean qualification and canonical
admission.

## Admitted conversion

Raw inputs are explicitly typed as centimetres.

For every node:

`node_depth_m = -z_cm / 100`

`node_thickness_m = dz_cm / 100`.

No automatic unit detection or `abs(z)` conversion is admitted.

The positive-up SWAP sign convention remains explicit.

## Geometry validation

The normalized compartments must:
- begin at the soil surface;
- have positive thickness;
- be finite;
- tile contiguously;
- not overlap;
- not contain a gap larger than the admitted representation tolerance.

Invalid geometry fails closed before ELASTIC17 mapping.

## Current admitted geometry chain

`raw SWAP z/dz [cm]`
-> ELASTIC18 normalized node geometry [m below surface]
-> ELASTIC17 source-horizon/node mapping
-> ELASTIC16 resolved descriptor assembly
-> ELASTIC14 generated mineral prior
-> ELASTIC15 explicit application binding
-> admitted row-24 ELAS path.

## Preserved boundaries

Still outside ELASTIC18:
- external BOFEK/BRO profile retrieval;
- source profile selection;
- horizon descriptor construction;
- Staringreeks theta evaluation;
- file/input grammar;
- automatic generated-prior request;
- automatic peat/high-organic assignment.

## Closure

F-PE-ELASTIC18 is canonically admitted and closed.

The raw SWAP-grid geometry seam is no longer a blocker.
