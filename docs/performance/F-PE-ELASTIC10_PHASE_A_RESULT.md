# F-PE-ELASTIC10 — BHR-GT schema-audit result

Date: 2026-09-29

Status: PHASE_A_SCHEMA_BOUND_PILOT_AUTHORIZED

Clean branch baseline:
`integration/f-ci-canonical@ad1c4b9193238a46dff95bd30e251adfc0426302`

Schema-audit workflow run:
`36538415609`

Job:
`109307781946`

Conclusion:
PASS.

## Exact service authority

Official public BHR-GT base:

`https://publiek.broservices.nl/sr/bhrgt/v2`

The machine-readable OpenAPI document was retrieved from:

`openapi.json`

with:

- HTTP 200;
- content type `application/json;charset=UTF-8`;
- size `12925` bytes;
- SHA-256 `c47e290b1fcf447f3e766e115c08598e4a888e3f38e9814fbbafaaf01f31795d`.

The bounded schema artifact is:

- Actions artifact `f-pe-elastic10-bhrgt-schema`;
- artifact id `11019227909`;
- artifact digest `sha256:15942c47378db4815de2571c61725a258db163bf137f373419d1fc5126666962`.

## Exact public REST paths

OpenAPI exposes exactly these BHR-GT v2 paths:

1. `GET /sr/bhrgt/v2/bro-ids`
2. `POST /sr/bhrgt/v2/characteristics/searches`
3. `GET /sr/bhrgt/v2/objects/{broId}`

The characteristics endpoint returns BHR-GT object summaries and is explicitly
documented as the first stage of a two-stage search/object retrieval workflow.

## Search contract

`BhrGtCriteriaSet` requires an `area` and supports, among others:

- `analysisType`;
- `depthInterval`;
- `samplingQuality`;
- `waterContentDetermined`;
- `organicMatterContentDetermined`;
- `volumetricMassDensityDetermined`;
- `volumetricMassDensitySolidsDetermined`.

The search result is bounded by the service to at most 2000 characteristics.

## Settlement-analysis semantic binding

Current official BHR-GT catalogue authority states that analysis type

`zetting`

requires a `SettlementCharacteristicsDetermination` and water-content and
volumetric-mass-density determinations, while related optional physical
determinations may also be present.

The current catalogue further defines:

- load-controlled determination steps with explicit loading/unloading step type;
- vertical stress in kPa;
- vertical strain in percent;
- settlement-progress time series;
- CRS/rate-controlled paths with vertical effective/grain stress;
- SWE DataArray encoding for potentially long measurement series.

Therefore BHR-GT is semantically capable of supplying a mechanically relevant
elastic/recompression target without substituting MvG parameters or virgin
compression indices.

## Phase-A limitation

The OpenAPI schema intentionally describes the public search/object service, not
the full internal BHR-GT XML/XSD object graph.

Therefore Phase A establishes:

- service discovery;
- query contract;
- object retrieval contract;
- official settlement semantics.

It does not yet establish that current public objects actually contain usable
unload/reload sequences.

## Decision

Phase B bounded object pilot is authorized.

No ELAS value, soil pedotransfer relation, solver tuning or production default
is inferred from Phase A.
