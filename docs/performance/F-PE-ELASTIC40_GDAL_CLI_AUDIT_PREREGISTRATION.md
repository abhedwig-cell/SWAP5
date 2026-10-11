# F-PE-ELASTIC40 — GDAL CLI CRS capability audit preregistration

Date: 2026-09-29

Status: PREREGISTERED_RESEARCH_ONLY

Baseline:
`integration/f-ci-canonical@464207ac036d5aa30314025b879df81cd518347f`

Parent authority:
- `F-PE-ELASTIC38_CRS_CAPABILITY_AUDIT_RESULT.md`;
- `F-PE-ELASTIC39_PROJ_CLI_AUDIT_RESULT.md`;
- `F-PE-ELASTIC34_CLOSURE.md`.

## Purpose

Test one final dependency-free CRS route on the standard GitHub runner after:
- pyproj was unavailable in ELASTIC38;
- cs2cs was unavailable in ELASTIC39.

Candidate tools:
- `gdaltransform` required candidate;
- `ogr2ogr` supporting characterization.

No package installation or repository dependency change is allowed.

## CRS contract

Source CRS: EPSG:4326.
Target CRS: EPSG:28992.

Input semantics are explicit longitude, latitude.

Environment:
- `PROJ_NETWORK=OFF`.

## Qualification gates

A1. `gdaltransform` is present.

A2. the five preregistered Netherlands WGS84 probes transform to finite RD
coordinates in x [0,300000] m and y [250000,650000] m.

A3. repeated forward transformations are byte-identical.

A4. inverse transform returns finite geographic coordinates.

A5. geographic round-trip error <= 2e-7 degrees.

A6. swapped lon/lat input does not silently reproduce the same result.

A7. no network access is required.

A8. exact GDAL executable/version provenance is persisted.

A9. `ogr2ogr` availability is characterized without becoming a requirement.

A10. zero `src/**` production changes.

## Decision

If the required route fails:
`ROUTE_FALSIFIED_GDAL_CLI_NOT_READY`.

If it passes:
`QUALIFIED_GDAL_CLI_CAPABILITY_READY_FOR_SEPARATE_PRODUCTION_DESIGN`.

A green audit does not itself admit production CRS transformation.
