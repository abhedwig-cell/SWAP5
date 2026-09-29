# F-PE-ELASTIC10B — bounded BHR-GT mechanical-object pilot result

Date: 2026-09-29

Status: TARGET_PATH_CONFIRMED

Workflow run:
`36538921262`

Job:
`109309469746`

Artifact:
- name: `f-pe-elastic10-bhrgt-schema`;
- id: `11019244975`;
- digest: `sha256:933279ebb472f70d01d80c12ca0a59e6cfee9cf03bd6d605a6dee4b64927b727`.

## Frozen query result

The preregistered query was executed unchanged:

- `analysisType = "zetting"`;
- Netherlands bounding box:
  - lower: 50.70 N, 3.20 E;
  - upper: 53.60 N, 7.30 E.

Search response:
- HTTP 200;
- content type `application/xml`;
- size `3,072,071` bytes;
- SHA-256 `f982ef1386bd8129c42253cb00d41dd2cf57dea19971510ec82d494556a9e02f`;
- unique BRO IDs: 692.

The preregistered lexicographically first three IDs were:

1. `BHR000000339285`
2. `BHR000000339288`
3. `BHR000000351603`

No adaptive reselection occurred.

## Object evidence

### BHR000000339285

- HTTP 200;
- bytes: 207004;
- SHA-256: `cf00e0f075b7b37c6b1c080546864a43b03201ec788099d3d50a109c7d9a0f59`.

Contains five `SettlementCharacteristicsDetermination` records using
`samendrukkenBelastinggestuurd`.

The determinations contain:
- explicit `belastingstap` and `ontlastingstap`;
- absolute `verticalStress` in kPa;
- `strainPoint24hours`;
- populated `heightChangeDuringSettlement` series.

One example unload branch changes vertical stress from 86.9 to 43.3 kPa and
its detailed settlement series shows vertical strain decreasing during the
unload step.

### BHR000000339288

- HTTP 200;
- bytes: 2,833,152;
- SHA-256: `976cbd0c404abea3f857e02e871f7686f59c67a29c5ab2b293ea466dc4aa7100`.

Contains two `SettlementCharacteristicsDetermination` records using
`samendrukkenSnelheidgestuurd`.

The determinations contain:
- loading, unloading and relaxation step types;
- populated `stressChangeDuringSettlement` time series;
- vertical strain;
- effective-pressure/stress information;
- volumetric density, solids density and water-content determinations.

### BHR000000351603

- HTTP 200;
- bytes: 1,438,498;
- SHA-256: `071aab573ef2125a950ecff9095e8ee1dd6986181c78350d30a7ac7f2565a465`.

Contains one rate-controlled settlement determination with:
- loading, unloading and relaxation steps;
- populated `stressChangeDuringSettlement` series;
- density and water-content metadata.

## SWE encoding correction

The pilot's generic `swe:DataArray` tag counter reported no literal
`DataArray` wrapper tags.

Raw-object inspection shows why: the domain element itself
(`heightChangeDuringSettlement` or `stressChangeDuringSettlement`) carries
the SWE structure as children:

- `swe:elementCount`;
- `swe:elementType` with an `xlink:href`;
- `swe:TextEncoding`;
- domain `values`.

For load-controlled settlement the referenced DataRecord is:

`HeightAtSpecificState.xml`

with fields:
- elapsed time;
- vertical strain.

For rate-controlled settlement the referenced DataRecord is:

`StressAtSpecificSettlement.xml`

with fields:
- elapsed time;
- excess pore-water pressure;
- horizontal effective stress;
- vertical effective stress;
- vertical strain.

This parser correction is source-bound to current official BHR-GT catalogue
semantics and the raw pilot objects.

## Falsification result

The preregistered success class is:

`TARGET_PATH_CONFIRMED`.

At least one object contains explicit load/unload semantics plus stress and
strain response, and rate-controlled objects contain effective-stress/strain
series.

## Scientific interpretation

BHR-GT provides a direct Dutch mechanical target route for ELAS research.

This is materially stronger than fitting ELAS from MvG parameters because the
target can be derived from measured deformation under controlled stress paths.

No ELAS value is selected by this pilot.
