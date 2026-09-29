# F-PE-ELASTIC10C — service-valid 10-km BHR-GT settlement pilot result

Date: 2026-09-29

Status: VALID_LOCAL_COVERAGE_NEGATIVE

Workflow:
`F-PE-ELASTIC10C BHR-GT 10-km settlement pilot`

Run:
`36528898941`

Qualified execution head:
`eb07dbd9c375adc53148a79483bd063af470e9d5`

Artifact:
`f-pe-elastic10c-bhrgt-pilot`

Artifact id:
`11016570102`

Artifact digest:
`sha256:6542474875d266466ec49f6ade5e3ba8826b6d2a2fa506ebff951b530b8371ee`

## Frozen query

The preregistered service-valid query was executed exactly as frozen:

- endpoint: `POST /sr/bhrgt/v2/characteristics/searches`;
- `analysisType = "zetting"`;
- center:
  - latitude `52.038297852`;
  - longitude `5.31447958948`;
- radius: exactly `10.0 km`.

This center is inherited from the official OpenAPI example and is unrelated to
user location.

## Result

The official service returned:

- HTTP 200;
- `F_PE_ELASTIC10C_SEARCH_IDS=0`;
- `F_PE_ELASTIC10C_RESULT=NEGATIVE_NO_OBJECTS_10KM`.

No BRO-ID was selected.
No BHR-GT object XML was retrieved.
No R0/R1/R2/R3 object classification was therefore applicable.

## Combined bounded-pilot evidence

Across the complete fixed local sequence now executed under valid service
contracts:

- 0.5 km: HTTP 200, zero `analysisType=zetting` BRO-IDs;
- 5.0 km: HTTP 200, zero BRO-IDs;
- 10.0 km: HTTP 200, zero BRO-IDs.

The previously attempted 25-km request is excluded because the official service
rejects enclosing-circle radii larger than 10 km.

## Interpretation

This is a valid **local coverage negative** only.

Supported claim:

> At the official OpenAPI example center, the public BHR-GT characteristics
> service returned no `analysisType=zetting` registrations within 10 km at
> the time of the preregistered query.

Not supported:

- national absence of BHR-GT settlement tests;
- absence of unload/reload or CRS target-ready objects elsewhere;
- any ELAS magnitude conclusion;
- any claim that BHR-GT is unsuitable as a mechanical target source.

The Phase-A schema result remains positive: BHR-GT is semantically capable of
providing stress/strain target information. Only this one fixed geographic cell
is empty.

## F-PE-ELASTIC10 decision

The local pilot does not satisfy the R2/R3 success condition because there are
no selected objects.

Classification:

`LOCAL_CELL_EMPTY_NATIONAL_TARGET_AVAILABILITY_UNRESOLVED`.

A successor workunit may perform geographically broader discovery only under a
new preregistration. It must not reinterpret the 10-km local negative as a
national result and must not alter object readiness thresholds after seeing
future objects.

No ELAS value, prior map or pedotransfer relation is admitted here.
