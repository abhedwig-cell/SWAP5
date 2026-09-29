# F-PE-ELASTIC12B — low-stress BHR-GT elastic-evidence coverage result

Date: 2026-09-29

Status: LOW_STRESS_TARGET_ROUTE_CONFIRMED

Qualified workflow:
`F-PE-ELASTIC12B low-stress BHR-GT coverage`

Run:
`36538267535`

Job:
`109307299356`

Qualified head:
`7e31b0898d85e84de13db618b0a1780e1a874395`

Artifact:
`f-pe-elastic12b-low-stress-coverage`

Artifact id:
`11018544503`

Artifact digest:
`sha256:c47ebb65c641a4b01504e709f4b65da27816aba4d99e72f15c5b1f3dcc3e3f7b`

## Frozen population

The audit used exactly the 86 BRO IDs frozen from the already-qualified
F-PE-ELASTIC10D search artifact.

Source authority:

- workflow run: `36529870974`;
- artifact id: `11016296681`;
- artifact digest:
  `sha256:59c184e964b769589da58ec8e07f391ae6cf03c720425df586b800ca0c54c45e`.

No new search center, radius, replacement object or result-dependent expansion
was introduced.

All 86 current public BHR-GT objects were fetched successfully:

`F_PE_ELASTIC12B_FETCH_SUCCESS=86/86`.

## Mechanical population

Across the 86 objects the current BHR-GT responses contain:

- settlement determinations: `248`;
- R2/load-controlled determinations: `79`;
- R3/effective-stress determinations: `169`;
- explicit unload steps: `241`.

The public population therefore contains abundant unload mechanics, not merely
loading observations.

## LS25 primary result

Preregistered LS25-LOCAL requires an unload path local to <=25 kPa.

Result:

- LS25-TOUCH objects: `7`;
- LS25-LOCAL objects: `5`.

This exceeds the preregistered three-object threshold.

Classification:

`LOW_STRESS_TARGET_ROUTE_CONFIRMED`.

### Five LS25-LOCAL objects

All five qualifying local candidates are **R3 effective-stress unload series**.

| BRO ID | Determination | Step | Local effective-stress range <=25 kPa | Local rows |
|---|---:|---:|---:|---:|
| BHR000000466495 | 1 | 2 | 22.51–25.00 kPa | 96 |
| BHR000000466498 | 1 | 2 | 22.96–24.97 kPa | 41 |
| BHR000000469044 | 1 | 2 | 18.76–24.72 kPa | 77 |
| BHR000000469048 | 1 | 2 | 23.85–24.98 kPa | 11 |
| BHR000000469193 | 1 | 2 | 19.79–25.00 kPa | 1656 |

Every candidate has at least three finite rows and at least two distinct
positive effective stresses in the <=25 kPa unload subset.

No LS25-LOCAL candidate depends on a loading envelope or inferred unload shape.

### Touch-only low-stress objects

Two additional objects reach <=25 kPa during an explicit unload step but do not
satisfy the frozen local-target criterion:

- BHR000000356941;
- BHR000000456026.

They remain diagnostic only.

## LS50 diagnostic transition result

At the broader, preregistered diagnostic threshold:

- LS50-TOUCH objects: `30`;
- LS50-TRANSITION / local-ready objects: `21`.

This shows that the public BHR-GT evidence becomes substantially denser between
25 and 50 kPa.

The threshold is not relaxed: 25 kPa remains the root-zone low-stress criterion.

## Loading-only observations

The audit also encountered many low-stress rows outside explicit unload steps:

- <=25 kPa row observations: `584683`;
- <=50 kPa row observations: `1068330`.

These counts are row-level diagnostics across long R3 series, not independent
mechanical targets.

Per preregistration, none of these loading-only rows is used as elastic evidence.

## Interpretation

F-PE-ELASTIC12A found no demonstrated overlap between the deep M5 calibration
stress domain and the saturated root-zone mechanical stress regime.

F-PE-ELASTIC12B removes the resulting data blocker:

- direct unload/recompression evidence exists at <=25 kPa;
- it exists in five distinct BRO objects;
- all five primary candidates use source-bound effective-stress R3 series;
- the next workunit can derive low-stress mechanical targets without
  extrapolating the deep M5 relationship.

This does **not** validate the deep M5 law at low stress. It only establishes
that an independent low-stress falsification dataset can be constructed.

## Scientific boundary

This workunit does not calculate:

- a strain/stress slope;
- constrained compressibility;
- Ssk;
- SWAP ELAS;
- a root-zone production parameter;
- an M5 low-stress prediction score.

No solver/runtime performance evidence is used.

## Decision

Qualified classification:

`LOW_STRESS_TARGET_ROUTE_CONFIRMED`.

Per the frozen downstream rule, a successor may now derive low-stress
mechanical targets from the exact five LS25-LOCAL candidates.

Because all five candidates are R3 series, the preferred next target is the
source-bound low-stress unload relation:

`vertical strain versus vertical effective stress`.

The successor must freeze its slope estimator, quality diagnostics and any
M5 comparison before calculating target magnitudes.
