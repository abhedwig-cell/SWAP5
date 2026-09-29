# F-PE-ELASTIC39 — PROJ CLI CRS capability audit preregistration

Date: 2026-09-29

Status: PREREGISTERED_RESEARCH_ONLY

Baseline:
`integration/f-ci-canonical@47a1ff4b46d6eb14730ff6a4b99508b1cdb7e396`

Parent authority:
- `F-PE-ELASTIC38_CRS_CAPABILITY_AUDIT_RESULT.md`;
- `F-PE-ELASTIC34_CLOSURE.md`;
- `F-PE-ELASTIC36_CLOSURE.md`.

## Purpose

Evaluate whether the standard GitHub runner already provides an offline PROJ
command-line route for explicit WGS84 longitude/latitude to EPSG:28992
transformation, after the pyproj route was falsified in ELASTIC38.

This is research-only.

No production dependency or CRS adapter is admitted.

## Candidate tools

Required candidate:
- `cs2cs`.

Supporting characterization:
- `projinfo`.

No package installation is allowed.

Environment:
- `PROJ_NETWORK=OFF`.

## CRS contract

Source:
- EPSG:4326;
- explicit input order longitude, latitude.

Target:
- EPSG:28992;
- metres.

The audit must record exact PROJ tool versions where available.

## Qualification gates

A1. `cs2cs` is present on the standard runner.

A2. `projinfo EPSG:28992` succeeds offline if `projinfo` is present.

A3. the five preregistered Netherlands WGS84 probes transform to finite RD
coordinates in x [0,300000] m and y [250000,650000] m.

A4. repeated forward transformations are byte-identical at the textual
precision requested by the audit.

A5. inverse transformation through `cs2cs -I` returns finite geographic
coordinates.

A6. geographic round-trip error is <= 2e-7 degrees for longitude and latitude.

A7. transformed output is sensitive to longitude/latitude order; swapped input
must not silently reproduce the same point.

A8. `PROJ_NETWORK=OFF` remains sufficient; no remote grid retrieval is needed.

A9. output/provenance persists exact executable/version characterization.

A10. zero `src/**` production changes.

## Decision

If any required gate fails:
`ROUTE_FALSIFIED_PROJ_CLI_NOT_READY`.

If all required gates pass:
`QUALIFIED_PROJ_CLI_CAPABILITY_READY_FOR_SEPARATE_PRODUCTION_DESIGN`.

A green ELASTIC39 still does not admit production CRS transformation.
