# F-PE-ELASTIC41 — request-gated RD preprocessing handoff preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_TOOL_CHANGE

Baseline:
`integration/f-ci-canonical@b1ab94eb2940203f3a4564d72383247d71bb4fad`

Parent authority:
- `F-PE-ELASTIC36_CLOSURE.md`;
- `F-PE-ELASTIC37_CLOSURE.md`;
- `F-PE-ELASTIC40_GDAL_CLI_AUDIT_RESULT.md`.

## Purpose

Add one offline application-preprocessing seam that gates ELASTIC36 spatial/profile
preprocessing on an already explicit generated-prior request and emits the exact
ELASTIC33 row file path/provenance expected by ELASTIC37.

The seam is:

`generated_prior_requested + EPSG:28992 point + frozen BRO GeoPackage`
-> if false: INACTIVE, no source file access, no output files
-> if true: ELASTIC36 RD-point composition
-> ELASTIC33 row interchange + provenance manifest.

No CRS transformation is performed.

## Input contract

Inputs:
- explicit boolean generated-prior request;
- caller-supplied frozen local GeoPackage path;
- already-resolved EPSG:28992 x/y coordinates;
- explicit output row-file path;
- explicit output provenance path.

Request=false:
- GeoPackage existence is not checked;
- coordinates are not validated or consumed;
- no output file is created.

Request=true:
- GeoPackage must exist;
- x/y must be finite numeric values;
- ELASTIC36 owns maparea/profile/interchange semantics.

## Output/provenance contract

On active success:
- row file bytes are exactly the ELASTIC33 interchange returned by ELASTIC36;
- provenance JSON contains:
  - schema = `swap5.elastic41.application-handoff.v1`;
  - generated_prior_requested = true;
  - row_file path as supplied by caller;
  - all ELASTIC36 selection provenance fields unchanged.

Writes are atomic at workunit level:
- on failure neither final output file is left behind.

## Ownership boundary

ELASTIC41 may:
- gate offline preprocessing on an explicit request;
- invoke ELASTIC36;
- write row/provenance outputs.

ELASTIC41 may not:
- create a request from location/profile identity;
- transform CRS;
- discover a GeoPackage path;
- discover output paths;
- invoke ELASTIC37 or modify SWAP runtime parameters;
- perform live PDOK/BRO network I/O.

ELASTIC37 remains application binding authority.

## Qualification matrix

A1. request=false with a nonexistent GeoPackage returns INACTIVE and creates no
files.

A2. request=true on known valid RD point produces ELASTIC36-identical row bytes.

A3. active provenance preserves exact source hash, RD point, maparea,
normalsoilprofile_id and horizon_count.

A4. 64 qualified real-source points from ELASTIC36 reproduce the exact same
selected profile and row bytes through ELASTIC41.

A5. spatial BOUNDARY/NOT_FOUND/AMBIGUOUS failures propagate fail closed and leave
no final files.

A6. missing source artifact in active mode fails closed; inactive mode remains
independent of source existence.

A7. repeated active preprocessing is byte/provenance deterministic.

A8. request=false does not import/open/read the GeoPackage or create partial
outputs.

A9. generated ELASTIC41 row file remains directly consumable by admitted
ELASTIC35/37 semantics, demonstrated by canonical row magic/provenance identity.

A10. no `src/**` changes; ELASTIC41 is offline tooling/tests/docs only.

## Admission boundary

A green ELASTIC41 admits request-gated offline RD preprocessing and explicit
row-file handoff only.

Still outside:
- geographic CRS transformation into EPSG:28992;
- direct subprocess invocation from the Fortran application host;
- automatic request from location/profile identity.
