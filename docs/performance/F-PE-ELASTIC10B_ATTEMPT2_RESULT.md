# F-PE-ELASTIC10B — corrected pilot attempt 2 result

Date: 2026-09-29

Status: SERVICE_RADIUS_CONTRACT_BLOCKED_NO_POPULATION_CONCLUSION

Workflow run:
`36528193825`

Qualified head:
`8779629dc242653b4a370873fd6ea5a66e1d44e8`.

Artifact:
`f-pe-elastic10b-bhrgt-pilot`,
artifact id `11014909596`,
digest `sha256:f3cbf3c5858012250bd4cfe0a26daa57b6d1be836d59e8e91c42f78c39a366fb`.

## Corrected discovery evidence

The invalid free-text BRO-ID fallback from attempt 1 was removed before this run.

The frozen search sequence then produced:

- 0.5 km: HTTP 200, `numberOfDocuments=0`;
- 5.0 km: HTTP 200, `numberOfDocuments=0`;
- 25.0 km: HTTP 400 rejection.

The 25-km response is explicit:

`CriteriaSet.area.enclosingCircle.radius = 25.0 ... mag niet groter zijn dan 10`.

Therefore the public BHR-GT characteristics service enforces:

`radius <= 10 km`.

This constraint was not expressed as a numeric maximum in the OpenAPI schema used
for the preregistration.

## Adjudication

The run-level marker:

`F_PE_ELASTIC10B_RESULT=NEGATIVE_NO_OBJECTS`

must not be interpreted as a valid population negative.

Only these statements are supported:

1. the official example center has no `analysisType=zetting` objects within
   0.5 km;
2. the same center has no such objects within 5 km;
3. the preregistered 25-km step is outside the service contract and was not
   executed as a valid characteristics search.

No BHR-GT object XML was retrieved in this corrected attempt.

## Classification

`INCOMPLETE_SERVICE_CONTRACT_MAX_RADIUS_DISCOVERED`.

This is a valid service-contract discovery, not a mechanical-target result.

## Successor boundary

A successor pilot may use the newly source-bound maximum radius of exactly
10 km at the same fixed center.

No object-selection rule, target-readiness classification or mechanical
acceptance criterion may change merely because the first two valid radii were
empty.
