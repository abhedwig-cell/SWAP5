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


## Pre-valid-run classifier scope refinement

Before any valid BHR-GT object pilot completed, a second parser-review finding was
recorded.

The readiness classifier originally searched SWE `values`, stress and strain
evidence over the complete BHR-GT object. One BHR-GT registration object can
contain multiple analyses, so an unrelated analysis payload could otherwise
contribute a nonempty SWE block to settlement readiness.

The parser was therefore tightened before valid object evidence to:

- collect mechanical readiness evidence separately inside each
  `SettlementCharacteristicsDetermination` subtree;
- classify each settlement determination independently;
- derive object readiness only from those determination-level classes;
- retain depth, density, moisture, quality and organic-matter fields as
  object-level descriptive metadata.

No discovery geometry, `analysisType`, radius sequence, stopping rule, selected
object count, readiness definitions or success criterion changed.

This is classified as a fail-closed evidence-binding correction, not a changed
scientific hypothesis or post-result threshold adjustment.


## Attempt 2 service-radius adjudication

A later corrected discovery run established:

- 0.5 km: HTTP 200, zero BRO-IDs;
- 5 km: HTTP 200, zero BRO-IDs;
- 25 km: HTTP 400, therefore not a population result.

The exact official rejection states:

`CriteriaSet.area.enclosingCircle.radius = 25.0 ... mag niet groter zijn dan 10`.

The 25-km response is therefore classified:

`INVALID_RADIUS_SERVICE_REJECTION`.

It does not support a negative-data conclusion.

Because this service constraint was unknown at preregistration time and no valid
third-radius result existed, the bounded pilot is corrected before further valid
evidence to use 10 km as the third and final radius.

Unchanged:
- center;
- analysisType=zetting;
- first-non-empty stopping rule;
- lexicographic selection;
- five-object maximum;
- R0-R3 definitions;
- target-ready success criterion.

No radius beyond the official 10-km maximum is allowed in this workunit.
