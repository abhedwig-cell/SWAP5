# F-PE-ELASTIC22 — explicit BRO profile retrieval result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic22-profile-retrieval`

Qualified postimage:
`380b5af925fd8fa478454feee40dcba29783045c`

Workflow run:
`36565674276`

Job:
`109396861612`

Conclusion:
SUCCESS.

## Scope

ELASTIC22 adds an offline preprocessing tool:

`tools/fpe_elastic22_profile_retrieval.py`.

It reads a caller-supplied local BRO Bodemkaart GeoPackage in read-only mode
and retrieves exactly one explicit `normalsoilprofile_id`.

No `src/**` production source is changed.

## Frozen source authority

Qualification used the already frozen PDOK BRO Bodemkaart artifact:
- workflow run `36550782840`;
- artifact `11024079961`.

## Qualification

- A1 required `normalsoilprofiles` and `soilhorizon` schema: PASS.
- A2 all 368 explicit profile IDs retrieve successfully: PASS.
- A3 retrieved horizons total exactly 1568: PASS.
- A4 every profile/horizon field is identical to direct SQL source rows: PASS.
- A5 known profile 16160 identity: PASS.
- A6 missing profile ID fails closed: PASS.
- A7 malformed/missing schema fails closed: PASS.
- A8 repeated retrieval is semantically identical: PASS.
- A9 no network, coordinate-selection or ELAS/retention derivation appears in the tool: PASS.
- A10 repository production source scope is empty: PASS.

## Output boundary

The tool emits source-bound JSON only:
- profile ID;
- soilunit;
- horizon layer number;
- top/bottom depth;
- staringseriesblock;
- dry density;
- organic matter;
- peat type.

It does not emit:
- Staringreeks retention parameters;
- theta(-100 cm);
- regime classification;
- ELAS.

## Admission meaning

A green ELASTIC22 admits explicit offline BRO profile retrieval from a local
source artifact.

Still outside scope:
- location-to-profile selection;
- BOFEK unit/profile policy;
- automatic profile selection;
- end-to-end horizon-to-node ELAS orchestration;
- user-facing SWAP input syntax;
- automatic generated-prior request.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
