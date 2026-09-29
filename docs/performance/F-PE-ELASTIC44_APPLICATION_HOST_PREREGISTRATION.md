# F-PE-ELASTIC44 — application-host composition preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_IMPLEMENTATION

Baseline:
`integration/f-ci-canonical@b6c9079c209eb6d1fe2db2fd61ff330941770166`

Parent authority:
- `F-PE-ELASTIC31_CLOSURE.md`;
- `F-PE-ELASTIC37_CLOSURE.md`;
- `F-PE-ELASTIC41_CLOSURE.md`;
- `F-PE-ELASTIC_RD_CHAIN_CLOSEOUT_2026-09-29.md`.

## Purpose

Add one explicit application-host composition above the already admitted ELAS seams.

The bounded host contract is:

`explicit RD x/y + explicit config-source discovery + frozen BRO GeoPackage`
-> ELASTIC31 request discovery
-> when inactive: preserve base parameters exactly and perform no BRO/row-file work
-> when explicitly requested: ELASTIC41 offline RD handoff
-> ELASTIC37 row-file application binding
-> bound parameter postimage.

The host does not introduce new ELAS physics, source selection semantics, request
semantics, CRS transformation, or solver/runtime I/O.

## Ownership

ELASTIC44 owns only orchestration between already admitted components.

ELASTIC31 remains authority for explicit/CLI/environment request discovery and
no-precedence source arbitration.

ELASTIC41 remains authority for request-gated offline EPSG:28992 RD point to
canonical row/provenance handoff.

ELASTIC37 remains authority for row-file parsing, profile assembly, grid mapping,
generated-prior assembly, and final parameter binding.

ELASTIC15 remains final explicit/user ELAS ownership authority.

## Explicit boundary

Input coordinates are already resolved EPSG:28992 metres.

ELASTIC44 must not:
- transform longitude/latitude;
- add pyproj, PROJ, GDAL, or another CRS dependency;
- read live PDOK/BRO services;
- add GIS I/O to Richards/runtime;
- infer or create a generated-prior request;
- introduce precedence among explicit, CLI, and environment request sources;
- overwrite explicit/user ELAS;
- weaken MINERAL-only automatic generated-prior eligibility.

## Host shape

Implement a small application-host executable/script intended for preprocessing
and application composition, not solver execution ownership.

Required explicit host inputs:
- frozen BRO GeoPackage path;
- RD x and y;
- output row/provenance paths;
- application parameter input sufficient for the qualification fixture;
- optional explicit ELAS config path while retaining admitted CLI/environment
  discovery semantics.

The exact implementation language may follow the smallest existing repository
pattern, provided the admitted Fortran request and binding contracts are
exercised rather than reimplemented.

## Qualification matrix

A1. No configured request resolves to inactive and leaves the parameter
postimage bit-identical to the base input.

A2. Inactive mode performs no frozen-BRO access and produces no row/provenance
outputs.

A3. One valid explicit generated-prior request plus a valid real RD point
produces the same ELASTIC41 row interchange/provenance as direct ELASTIC41.

A4. The produced row file is consumed by the admitted ELASTIC37 binding and
produces active finite positive generated ELAS for a real MINERAL profile.

A5. Explicit/user ELAS ownership remains preserved; the generated route fails
closed without mutating the base values.

A6. ELASTIC31 source conflicts remain fail-closed. ELASTIC44 adds no source
precedence.

A7. Missing/invalid GeoPackage, spatial BOUNDARY/NOT_FOUND/AMBIGUOUS failures,
invalid row file, and binding failures propagate fail closed with no partial
accepted postimage.

A8. Repeated valid host composition is deterministic for row/provenance and
parameter postimage.

A9. O0/O2 produce identical host-observable results.

A10. No solver/Richards source is changed. Any `src/**` change, if needed at
all, is restricted to an application/adapter host seam and must be justified by
the qualification evidence.

## Admission boundary

A green ELASTIC44 admits only explicit application-host orchestration for
already-resolved EPSG:28992 coordinates and explicit generated-prior request
semantics.

It does not admit:
- geographic-coordinate input;
- automatic generated-prior activation from location/profile identity;
- live source retrieval;
- runtime GIS;
- new ELAS parameterization;
- solver changes.
