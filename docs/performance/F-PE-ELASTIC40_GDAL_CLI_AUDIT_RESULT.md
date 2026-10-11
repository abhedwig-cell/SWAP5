# F-PE-ELASTIC40 — GDAL CLI CRS capability audit result

Date: 2026-09-29

Status: BLOCKED_DEPENDENCY

Branch:
`research/f-pe-elastic40-gdal-cli-audit`

Audited postimage:
`75d3fa1cd18565fa7b94fdd726dbdf39de5ebf40`

Workflow run:
`36593574278`

Job:
`109492622088`

Conclusion:
FAILURE.

## Result

The preregistered final dependency-free CRS route requires
`gdaltransform` to be available on the standard GitHub runner without package
installation.

Observed failure:

`F_PE_ELASTIC40_FAIL gdaltransform unavailable`.

Therefore the GDAL command-line route is not available under the current
dependency-free execution environment.

## Combined CRS route status

Three independently preregistered routes have now been falsified:

1. ELASTIC38:
   `pyproj` unavailable on the standard runner.
2. ELASTIC39:
   `cs2cs` unavailable on the standard runner.
3. ELASTIC40:
   `gdaltransform` unavailable on the standard runner.

No production CRS transformation has been admitted.

## Blocker

Automatic geographic-coordinate -> EPSG:28992 transformation now requires an
explicit dependency/governance decision.

Defensible options are outside this work unit:

- admit a pinned `pyproj`/PROJ dependency for offline preprocessing;
- admit a pinned GDAL/PROJ CLI environment;
- require callers to provide already-resolved EPSG:28992 coordinates and keep
  CRS transformation outside SWAP5.

Until one of those is explicitly selected and preregistered, the admitted
spatial chain starts at already-resolved EPSG:28992 coordinates.

## Preserved admitted chain

Already admitted and unaffected:

`EPSG:28992 point`
-> ELASTIC34 strict maparea selection
-> ELASTIC36 maparea/profile/interchange preprocessing
-> ELASTIC35 row parser
-> ELASTIC37 application binding
-> existing ELAS runtime.

## Decision

Classification:

`TRUE_BLOCKER_CRS_DEPENDENCY_DECISION_REQUIRED`.

No production `src/**` mutation is introduced by ELASTIC40.
