# F-PE-ELASTIC10 — BHR-GT schema-acquisition result

Date: 2026-09-29

Status: PHASE_A_SCHEMA_AUTHORITY_CLOSED

Workflow run:
`36526529454`

Qualified head:
`98ab37a36c090728d3ed9728a3e602f3c5cfdf2c`

Artifact:
`f-pe-elastic10-bhrgt-schema`
artifact id `11014558994`
digest `sha256:876d18c694ab9b2527e218c4cef407041608a15ddb96908b9dddcc01dad7b39e`.

## Official service authority

Base service:
`https://publiek.broservices.nl/sr/bhrgt/v2`

The base service responded HTTP 200.

Unique OpenAPI source:
`/sr/bhrgt/v2/openapi.json`

OpenAPI response:
- HTTP 200;
- content type `application/json;charset=UTF-8`;
- bytes: 12925;
- SHA-256 `c47e290b1fcf447f3e766e115c08598e4a888e3f38e9814fbbafaaf01f31795d`.

## Bound endpoints

The current official BHR-GT v2 service exposes exactly the relevant two-stage
public retrieval pattern:

1. `GET /sr/bhrgt/v2/bro-ids`
   - requires a source-holder KVK;
   - therefore not suitable as a national discovery endpoint without a known
     source holder.

2. `POST /sr/bhrgt/v2/characteristics/searches`
   - public characteristics search;
   - request schema: `BhrGtCriteriaSet`;
   - result capped at 2000;
   - returns XML characteristics;
   - explicitly intended as stage 1 of a two-stage selection workflow.

3. `GET /sr/bhrgt/v2/objects/{broId}`
   - retrieves a public BHR-GT registration object by BRO-ID as IMBRO XML;
   - suitable as stage 2 after characteristics search.

## Search criteria authority

`BhrGtCriteriaSet` requires `area` and additionally supports, among others:

- `analysisType`;
- `depthInterval`;
- `samplingQuality`;
- `waterContentDetermined`;
- `organicMatterContentDetermined`;
- `volumetricMassDensityDetermined`;
- `volumetricMassDensitySolidsDetermined`;
- date/registration filters.

The official OpenAPI example supplies an enclosing circle centered at:

- latitude `52.038297852`;
- longitude `5.31447958948`;
- radius `0.5`.

This example location may be reused as a deterministic service pilot origin; it
has no relation to user location.

## Settlement target semantics

Independent official BHR-GT catalogue authority confirms:

- current `analysisType=zetting` requires a
  `SettlementCharacteristicsDetermination`;
- settlement analysis also includes water-content determination and volumetric
  mass-density determination;
- load-controlled settlement exposes explicit loading/unloading step type,
  vertical stress and vertical-strain time series;
- CRS/rate-controlled settlement exposes vertical strain and vertical
  effective/grain stress;
- time series use SWE DataArray encoding.

Therefore the public product is semantically capable of yielding an independent
mechanical target for constrained/recompression compressibility.

## Phase-A decision

Classification:

`BHR_GT_MECHANICAL_TARGET_SERVICE_SOURCE_BOUND`.

The remaining uncertainty is population/object coverage, not schema semantics.

No ELAS value or mechanical slope has yet been derived.
