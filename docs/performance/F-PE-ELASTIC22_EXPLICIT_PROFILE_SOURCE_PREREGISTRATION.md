# F-PE-ELASTIC22 — explicit BRO profile-source assembly preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@e355dacf50fcc0cceb77e02f73b78eddebcbeced`

Current canonical reconciliation:
`integration/f-ci-canonical@fed1d42a3f95b2396c071f6f9e76ec8cb66943cd`

The intervening canonical delta is docs-only ELASTIC21 closure and does not
change the ELASTIC22 dependency surface.

Parent authority:
- `F-PE-ELASTIC19_CLOSURE.md`;
- `F-PE-ELASTIC20_CLOSURE.md`;
- `F-PE-ELASTIC21_CLOSURE.md`.

## Purpose

Add one stateless in-memory source adapter that selects one explicit
`normalsoilprofile_id` from already loaded BRO horizon records and constructs
the admitted ELASTIC19 horizon descriptors.

The seam is:

`resolved in-memory BRO horizon rows + explicit normalsoilprofile_id`
-> exact selected profile rows
-> ELASTIC21 block-code mapping
-> ELASTIC20 retention lookup
-> ELASTIC19 horizon descriptor construction.

No external file, database or network I/O is introduced.

## Source-row input contract

Each already loaded row contains:

- `normalsoilprofile_id` integer;
- `layer_number` integer;
- top depth [m below surface];
- bottom depth [m below surface];
- `staringseriesblock` integer;
- dry bulk density [g/cm3];
- organic-matter availability;
- organic-matter content [%];
- explicit peat-type-present flag.

No spatial coordinate or location is part of this work unit.

## Explicit profile selection

The caller supplies one exact positive `normalsoilprofile_id`.

Only rows with that exact ID are considered.

If no rows match:
`PROFILE_NOT_FOUND`.

Rows belonging to other profiles are ignored and do not influence the selected
profile.

## Selected-profile structural rules

For the selected profile:

- at least one row is required;
- input rows must appear in strictly increasing `layer_number`;
- first selected layer number must be 1;
- subsequent layer numbers must be exactly previous+1;
- horizon geometry must be contiguous and increasing;
- first horizon top must be 0 m within the ELASTIC17 geometric tolerance;
- no duplicate layer numbers;
- no gaps/overlaps.

The adapter does not sort selected rows.

This makes source ordering explicit rather than silently repairing input.

## Per-row assembly

For every selected row, in source order:

1. resolve `staringseriesblock` through admitted ELASTIC21;
2. resolve the resulting exact code through admitted ELASTIC20;
3. build the source horizon through admitted ELASTIC19.

Any failure rejects the entire profile atomically.

No partial horizon array is returned.

## Output contract

On success return:

- ordered `fmr_elastic_storage_horizon_t(:)`;
- original selected `layer_number(:)`;
- ELASTIC20 catalog index per horizon;
- exact selected profile ID;
- diagnostics with selected row count.

All geometry and dry-density values remain source identities.

## Qualification matrix

A1. one explicit profile selected from a mixed multi-profile input produces only
that profile.

A2. selected rows preserve layer order and source geometry/density bit identity.

A3. selected `staringseriesblock` values compose exactly through
ELASTIC21+20+19 and reproduce direct manual descriptor construction.

A4. absent profile ID fails closed.

A5. nonpositive requested profile ID fails closed.

A6. selected layer-number gap, duplicate, reverse ordering, non-1 first layer,
geometry gap/overlap or nonzero profile top fail closed atomically.

A7. invalid block or invalid ELASTIC19 source/retention input in any selected
row rejects the whole selected profile with failed-layer provenance.

A8. valid selected all-MINERAL profile composes through admitted
ELASTIC17/16 to the same node descriptors/parameter postimage as a manually
assembled horizon array.

A9. PEAT provenance is preserved; downstream generated-prior assembly rejects
the profile rather than ELASTIC22 reclassifying it.

A10. O0/O2 identity.

A11. production source scope is exactly one new stateless adapter module plus
tests/docs; no runtime/kernel/solver/legacy source changes.

## Admission boundary

A green ELASTIC22 admits only explicit selection from already loaded in-memory
BRO source rows.

It does not admit:
- GeoPackage/file/database parsing;
- network retrieval;
- location-to-profile lookup;
- spatial polygon selection;
- choosing a profile ID automatically;
- alternate Staringreeks years;
- automatic generated-prior request.
