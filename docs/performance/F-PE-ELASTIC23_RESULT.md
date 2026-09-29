# F-PE-ELASTIC23 — offline BRO profile retrieval result

Date: 2026-09-29

Status: QUALIFIED_RESULT

Branch:
`work/f-pe-elastic23-profile-retrieval`

Qualified postimage:
`7c9e77a839f060f0370c7e35b2b5ac3382df2249`

Workflow run:
`36567392350`

Job:
`109402603786`

Conclusion:
SUCCESS.

## Architecture result

The architecture audit resolves the ELASTIC22 boundary as a two-workunit
design:

- ELASTIC22 owns the admitted stateless typed in-memory explicit-profile
  selection and source-horizon assembly seam;
- ELASTIC23 owns only offline retrieval of an already explicit profile identity
  from a frozen local BRO source artifact.

Source acquisition, spatial/profile selection and runtime activation remain
separate concerns.

## Frozen source authority

Qualification used:
- workflow run `36550782840`;
- artifact `f-pe-elastic12a4-pdok-atom`;
- artifact id `11024079961`;
- producer head `6f81df17d74308fa423f75095cb3d448f95d773c`;
- archive SHA-256
  `f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6`.

The Actions download independently reported exactly the same SHA-256.

## Qualification

- A1 required source schema: PASS.
- A2 all 368 explicit `normalsoilprofile_id` values retrieve: PASS.
- A3 total retrieved source horizons = 1568: PASS.
- A4 every emitted source field equals the direct-SQL oracle: PASS.
- A5 profile `16160` exact source identity: PASS.
- A6 missing/nonpositive profile identity fails closed: PASS.
- A7 malformed schema and malformed profile geometry fail closed: PASS.
- A8 repeated retrieval is semantically deterministic: PASS.
- A9 emitted frozen-artifact provenance SHA-256 is exact: PASS.
- A10 boundary hygiene and zero `src/**` production-source scope: PASS.

## Qualified seam

`explicit normalsoilprofile_id + frozen local BRO GeoPackage`
-> exact source profile metadata
-> exact ordered source horizons
-> source-bound JSON `swap5.elastic23.bro-profile.v1`.

No location or coordinate is accepted by the tool.

No Staringreeks retention, theta(-100 cm), material-regime classification,
ELAS prediction, node mapping or application activation occurs.

## Preserved boundary

Still outside scope:
- location-to-profile selection;
- spatial polygon lookup;
- BOFEK unit/profile choice policy;
- automatic profile selection;
- user-facing SWAP input syntax;
- runtime parsing of the preprocessing artifact;
- automatic generated-prior request.

## Decision

Classification:

`QUALIFIED_RESULT_READY_FOR_CLEAN_ADMISSION_EXTRACTION`.
