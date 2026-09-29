# F-PE-ELASTIC18 — SWAP grid normalization result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic18-clean-admission`

Qualified clean postimage:
`ef3723bff884b5def6494f16a4576408fd764baa`

Workflow run:
`36560822452`

Job:
`109380988592`

Conclusion:
SUCCESS.

## Production scope

Exactly one production source file is added:

`src/adapter/mod_fmr_elastic_storage_swap_grid_normalization.f90`.

No existing production source is modified.

The adapter converts raw SWAP grid geometry only:

`z_cm -> node_depth_m = -z_cm/100`

`dz_cm -> node_thickness_m = dz_cm/100`.

It does not:
- fetch soil data;
- infer horizons;
- calculate ELAS;
- classify regimes;
- modify runtime state;
- alter solver policy.

## A1 canonical SWAP fixture

The established four-node fixture:

- z = [-25,-75,-150,-250] cm;
- dz = [50,50,100,100] cm;

maps exactly to:

- depth = [0.25,0.75,1.50,2.50] m;
- thickness = [0.50,0.50,1.00,1.00] m.

PASS.

## A2 heterogeneous thickness

A nonuniform contiguous grid maps exactly under the same sign/unit conversion.

PASS.

## A3 sign fail closed

Positive above-surface raw SWAP z is rejected.

PASS.

## A4 value fail closed

Non-finite input and zero/non-positive compartment thickness are rejected.

PASS.

## A5 contiguity fail closed

Raw z/dz geometry that implies a gap or overlap between adjacent compartments is rejected.

PASS.

## A6 ELASTIC17 composition

Normalized geometry from this adapter composes through the admitted ELASTIC17
horizon-node mapper and produces the expected horizon ownership.

PASS.

## A7 O0/O2 identity

Focused output is identical at O0 and O2.

PASS.

## A8 source scope

Production delta is exactly:

`src/adapter/mod_fmr_elastic_storage_swap_grid_normalization.f90`.

No runtime/kernel/legacy production source changes.

PASS.

## Admission meaning

A green ELASTIC18 admits only the raw SWAP-grid normalization seam.

It closes the remaining geometry conversion:

`SWAP z/dz in cm`
-> normalized depth/thickness in metres below surface
-> ELASTIC17 horizon-node mapping.

Still outside scope:
- BOFEK/BRO profile retrieval;
- horizon descriptor construction;
- Staringreeks theta evaluation;
- profile selection;
- file syntax;
- automatic generated-prior request.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
