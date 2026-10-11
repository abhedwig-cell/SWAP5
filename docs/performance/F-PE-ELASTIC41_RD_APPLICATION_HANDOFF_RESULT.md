# F-PE-ELASTIC41 — request-gated RD application handoff result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`research/f-pe-elastic41-rd-end-to-end`

Qualified postimage:
`7fcd5572e18e9c2b55e670d288d8713038f49dad`

Workflow run:
`36595836774`

Job:
`109500386721`

Conclusion:
SUCCESS.

## Qualified seam

`generated_prior_requested + explicit EPSG:28992 point + frozen BRO GeoPackage`
-> request=false: INACTIVE with no source access or outputs
-> request=true: ELASTIC36 spatial/profile preprocessing
-> canonical ELASTIC33 row interchange + ELASTIC41 provenance handoff.

No CRS transformation is introduced.

## Qualification

Offline handoff:
- inactive request performs no source I/O: PASS;
- ELASTIC36 row-byte identity over 64 deterministic real-source points: PASS;
- ELASTIC41 provenance identity: PASS;
- 64/64 real-source sample: PASS;
- spatial BOUNDARY/NOT_FOUND/AMBIGUOUS propagation fail closed: PASS;
- active missing-source failure and inactive source independence: PASS;
- repeated handoff byte/provenance identity: PASS;
- canonical ELASTIC33/35/37 row compatibility: PASS.

Strengthened application composition:
- frozen source authority: PASS;
- 64 deterministic mineral candidates: PASS;
- interchange identity: PASS;
- explicit request: PASS;
- real profile binding: PASS;
- positive generated priors: PASS;
- default-off identity: PASS;
- explicit/user ELAS ownership preservation: PASS;
- O0/O2 identity: PASS;
- zero `src/**` changes: PASS.

Selected real profile in both O0/O2:
- profile `90116260`;
- maparea `V2025-1..soilarea.0000003954`;
- RD x = `179362.75550490862` m;
- RD y = `418659.84937244334` m.

## Qualification-driven repairs

The first result exposed a provenance-object construction defect: the ELASTIC36
`schema` field overwrote the intended ELASTIC41 schema. The merge order was
corrected so ELASTIC41 owns the final handoff schema.

Subsequent failures were test-harness-only:
- diagnostic newline syntax;
- polygon-cache wrapper signature;
- missing Fortran fixture preparer;
- generated integer-looking real literals and repeated array allocation.

These repairs do not change the preregistered handoff semantics.

## Current canonical reconciliation

Current canonical:
`ba2ab6b015fe713c43b62d77ecc9fe1479a41f12`.

The delta from the preregistered ELASTIC41 baseline is the separately owned,
research-only ELASTIC42 end-to-end qualification. It does not modify the
ELASTIC41 tooling or ownership boundary.

## Ownership boundary

ELASTIC41 does not:
- create the generated-prior request;
- transform geographic coordinates to EPSG:28992;
- discover the frozen source path or output paths;
- perform live PDOK/BRO access;
- modify SWAP runtime parameters directly.

ELASTIC37 remains application binding authority.

## Decision

Classification:
`QUALIFIED_ADMISSION_CANDIDATE`.
