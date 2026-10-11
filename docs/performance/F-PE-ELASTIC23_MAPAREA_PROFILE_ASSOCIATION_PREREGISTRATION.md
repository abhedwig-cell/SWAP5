# F-PE-ELASTIC23 — BRO maparea-to-profile association preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@9ca61a27aa979d5e87ffeffbd3e74fd0f1c5e406`

Parent authority:
- `F-PE-ELASTIC22_CLOSURE.md`;
- frozen PDOK BRO Bodemkaart artifact from ELASTIC12A4.

## Source relation evidence

Frozen GeoPackage relation:

`soilarea_normalsoilprofile(maparea_id, normalsoilprofile_id)`

contains:
- 48,025 rows;
- 48,025 distinct `maparea_id` values;
- 368 distinct `normalsoilprofile_id` values.

Therefore, within the frozen source, every soilarea has exactly one associated
normal soil profile.

ELASTIC23 freezes only that deterministic association.

## Purpose

Add one stateless in-memory adapter:

`explicit already selected maparea_id + resolved relation rows`
-> exact `normalsoilprofile_id`
-> admitted ELASTIC22 explicit profile source.

No geometry, point-in-polygon logic, file I/O or network access is introduced.

## Input contract

Each already loaded relation row contains:
- exact `maparea_id` character data;
- positive `normalsoilprofile_id`.

The caller supplies one explicit `maparea_id`.

Maparea IDs are treated as opaque source identifiers.

Accepted equality is exact apart from trailing Fortran padding.

No:
- case folding;
- leading-space trimming;
- wildcard matching;
- suffix/prefix matching

is allowed.

## Selection rule

Exactly one relation row must match the requested maparea ID.

Outcomes:

- zero matches -> `MAPAREA_NOT_FOUND`;
- one match with positive profile ID -> OK;
- more than one match -> `AMBIGUOUS_MAPAREA`.

Even duplicate rows that happen to contain the same profile ID are ambiguous.
The adapter does not silently deduplicate source corruption.

## Output contract

On success return:
- exact selected `normalsoilprofile_id`;
- matched input-row index;
- status OK.

No source-horizon data are copied or interpreted here.

## Qualification matrix

A1. explicit maparea from mixed association rows returns the exact associated
profile ID.

A2. trailing character padding is harmless.

A3. leading-space, case-changed, missing and empty identifiers fail closed.

A4. duplicate matching maparea rows fail as ambiguous, including duplicates
with identical profile IDs.

A5. matching row with nonpositive profile ID fails closed.

A6. returned profile ID composes through admitted ELASTIC22 and yields the same
profile horizon array as direct explicit profile-ID selection.

A7. unrelated relation rows do not affect the selected mapping.

A8. O0/O2 identity.

A9. production source scope is exactly one new stateless adapter module plus
tests/docs; no runtime/kernel/solver/legacy source changes.

## Admission boundary

A green ELASTIC23 admits only already-selected soilarea ID to profile-ID
association.

It does not admit:
- GeoPackage/file/database loading;
- spatial polygon geometry;
- point-in-polygon selection;
- coordinate systems;
- automatic location-to-maparea selection;
- automatic generated-prior request.
