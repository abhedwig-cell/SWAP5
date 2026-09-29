# F-PE-ELASTIC11A — BHR-GT mechanical SWE schema result

Date: 2026-09-29

Status: TARGET_SCHEMA_BOUND

Workflow:
`F-PE-ELASTIC11A BHR-GT target schema binding`

Run:
`36530434453`

Qualified head:
`b81304dc70ba8a1369e573b036a637a4807052af`

Artifact:
`f-pe-elastic11a-target-schemas`

Artifact id:
`11015693839`

Artifact digest:
`sha256:4203e4fabae2eea37211697df45caef81198e67c771beb48a26baf7e9e185120`

## HeightAtSpecificState

Official schema:
`http://schema.broservices.nl/xsd/bhrgtcommon/2.0/HeightAtSpecificState.xml`

SHA-256:
`eaf6fa175a8530d4b3fa7d26960c2796a892c080ab73d5cf6bf72a7befbbc0ec`

Ordered fields:

1. `elapsedTime` — Quantity — `s`
2. `verticalStrain` — Quantity — `%`

This closes the R2 SWE column-order and unit authority.

## StressAtSpecificSettlement

Official schema:
`http://schema.broservices.nl/xsd/bhrgtcommon/2.0/StressAtSpecificSettlement.xml`

SHA-256:
`7d2d9a3cef1e91513621cc7d3f3064f461100dadbd0f21bbe3559d98e4b5d895`

Ordered fields:

1. `elapsedTime` — Quantity — `s`
2. `verticalStrain` — Quantity — `%`
3. `excessPoreWaterPressure` — Quantity — `kPa`
4. `verticalEffectiveStress` — Quantity — `kPa`
5. `horizontalEffectiveStress` — Quantity — `kPa`

This closes the R3 required vertical-strain and vertical-effective-stress
column-order/unit authority.

## Decision

Classification:

`BHR_GT_R2_R3_TARGET_SCHEMA_SOURCE_BOUND`.

F-PE-ELASTIC10E may now calculate only the preregistered mechanical targets.
No predictor model or production ELAS assignment is admitted by this result.
