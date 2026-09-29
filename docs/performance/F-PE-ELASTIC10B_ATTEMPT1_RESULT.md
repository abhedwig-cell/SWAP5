# F-PE-ELASTIC10B — pilot attempt 1 adjudication

Date: 2026-09-29

Status: INVALID_DISCOVERY_PARSE_NO_DATA_CONCLUSION

Workflow run:
`36527865245`

Head:
`8803da2a172b7bdea32eea3274c0c9b59db4c7f4`

Artifact:
`f-pe-elastic10b-bhrgt-pilot`,
artifact id `11014754622`.

## What happened

The preregistered 0.5-km search returned HTTP 200 and the XML response explicitly
reported:

`<numberOfDocuments>0</numberOfDocuments>`.

There was therefore no BHR-GT object at the first radius.

The pilot parser correctly attempted local-name extraction for `broId`, but
also contained a non-preregistered broad regex fallback. That fallback matched
the namespace string:

`http://www.broservices.nl/xsd/bhrgtcommon/2.1`

and incorrectly interpreted `bhrgtcommon` as a BRO-ID.

The subsequent object request for `bhrgtcommon` returned HTTP 400.

## Adjudication

The reported:

- `OBJECTS=1`;
- `TARGET_READY=0`;
- `NEGATIVE_R0_R1_ONLY`

are invalid as population evidence.

This attempt does **not** establish absence of target-ready BHR-GT data.

Classification:

`INVALID_DISCOVERY_PARSE`.

## Corrective action

The preregistration already froze BRO-ID extraction as XML local-name based.

The parser is corrected by removing the regex fallback entirely.

The search radii, center, `analysisType=zetting`, first-non-empty stopping rule,
lexicographic selection and five-object maximum remain unchanged.

The corrected pilot must therefore proceed:
- 0.5 km: recognized as empty;
- then 5 km;
- then 25 km if necessary.

No scientific acceptance criterion changed after seeing the invalid result.
