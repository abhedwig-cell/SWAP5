# F-PE-ELASTIC10D — fixed 12-cell Dutch BHR-GT settlement discovery result

Date: 2026-09-29

Status: TARGET_READY

Workflow:
`F-PE-ELASTIC10D Dutch BHR-GT grid pilot`

Run:
`36529870974`

Qualified execution head:
`d110a8818dd9fe9bae7c5b3f67406ab4d867c28c`

Artifact:
`f-pe-elastic10d-bhrgt-grid`

Artifact id:
`11016296681`

Artifact digest:
`sha256:59c184e964b769589da58ec8e07f391ae6cf03c720425df586b800ca0c54c45e`

## Frozen grid result

All 12 preregistered 10-km cells returned HTTP 200.

BRO-ID counts:

| Cell | BRO IDs |
|---|---:|
| Wageningen | 2 |
| Utrecht | 5 |
| Zwolle | 32 |
| Assen | 2 |
| Leeuwarden | 7 |
| Alkmaar | 18 |
| Rotterdam | 16 |
| Breda | 0 |
| Eindhoven | 0 |
| Venlo | 0 |
| Arnhem | 0 |
| Lelystad | 4 |

Total unique BRO-IDs across cells:
`86`.

The frozen first-two-per-cell / first-owner duplicate rule selected exactly
`16` unique objects.

## Frozen selected object set

| Owning cell | BRO-ID | Object readiness |
|---|---|---|
| Wageningen | BHR000000462600 | R3 |
| Wageningen | BHR000000462646 | R3 |
| Utrecht | BHR000000456021 | R2 |
| Utrecht | BHR000000456023 | R2 |
| Zwolle | BHR000000356939 | R3 |
| Zwolle | BHR000000356940 | R3 |
| Assen | BHR000000453770 | R2 |
| Assen | BHR000000453775 | R2 |
| Leeuwarden | BHR000000380280 | R2 |
| Leeuwarden | BHR000000380281 | R2 |
| Alkmaar | BHR000000466468 | R3 |
| Alkmaar | BHR000000466469 | R3 |
| Rotterdam | BHR000000353613 | R2 |
| Rotterdam | BHR000000353614 | R2 |
| Lelystad | BHR000000470062 | R3 |
| Lelystad | BHR000000470064 | R3 |

Object-level readiness:
- R3: 8/16;
- R2: 8/16;
- R0/R1: 0/16.

Therefore:
`F_PE_ELASTIC10D_TARGET_READY=16`
and
`F_PE_ELASTIC10D_RESULT=TARGET_READY`.

## Determination-level evidence

The fixed sample contains both source-bound mechanical target types required by
the preregistration.

### R3 examples

Several objects contain rate-controlled settlement determinations with
non-empty `stressChangeDuringSettlement` SWE series bound to
`StressAtSpecificSettlement.xml`.

The series include explicit loading, unloading and relaxation steps and are
therefore source-bound candidates for effective/grain-stress versus vertical
strain tangent extraction.

### R2 examples

Several load-controlled objects contain eight-step settlement determinations
with:
- six distinct vertical stress levels;
- non-empty `HeightAtSpecificState.xml` series;
- explicit `ontlastingstap`;
- a repeated lower stress after higher loading.

Examples include stress paths of the form:
`~19 -> 37/41 -> 74/82 -> 150/163 -> 299/326 -> unload to 74/82 kPa -> reload`.

These are source-bound recompression/unload target candidates.

## Physical metadata coverage

The selected objects also carry useful physical metadata in varying amounts,
including:
- depth intervals;
- volumetric mass density;
- solids density;
- water content;
- sample moisture;
- sample quality;
- organic matter in a subset.

Coverage is not uniform and must be preserved as observed; no imputation is
authorized.

## Interpretation

The earlier local 0.5/5/10-km negative was a geographic coverage effect, not a
lack of BHR-GT settlement target data.

The national fixed-grid result establishes that the public BHR-GT product
contains abundant target-ready Dutch mechanical observations.

This materially changes the physical ELAS research path:

- a direct mechanical target route is available;
- an MvG-only ELAS regression is unnecessary as the primary identification
  strategy;
- R2 unload/reload data can constrain recompression storage;
- R3 effective-stress time series can constrain tangent storage directly.

## Decision

F-PE-ELASTIC10 succeeds.

Classification:

`DUTCH_BHR_GT_MECHANICAL_TARGET_ROUTE_CONFIRMED`.

No ELAS value is calculated in this workunit.

Per the preregistered downstream rule, the next workunit must freeze target
extraction and conversion rules before calculating any compressibility,
specific storage or ELAS quantity.
