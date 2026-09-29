# F-PE-ELASTIC19 — resolved horizon descriptor materialization result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic19-horizon-descriptor-materialization`

Qualified postimage:
`3c637cd253a40b024471a94cca04348ff60085ec`

Workflow run:
`36562363881`

Job:
`109386011096`

Conclusion:
SUCCESS.

## Production scope

Exactly one production source file is added:

`src/adapter/mod_fmr_elastic_storage_horizon_descriptor_materializer.f90`.

No existing production source is modified.

The adapter converts already resolved source-horizon metadata to the admitted
ELASTIC17 horizon descriptor.

It does not:
- fetch BOFEK/BRO;
- resolve profile IDs;
- resolve a Staringreeks block code;
- parse files;
- calculate ELAS directly;
- change runtime or solver policy.

## Frozen regime classification

The preregistered rule is implemented exactly:

- peat type present -> PEAT;
- otherwise unavailable organic matter -> UNKNOWN;
- otherwise organic matter >15% -> ORGANIC_RICH_NONPEAT;
- otherwise -> MINERAL.

The exact 15% boundary remains MINERAL.

A1:
PASS.

## Reference-state water content

The adapter evaluates the frozen reference state:

`h_ref=-100 cm`.

Using:

`m=1-1/n`

and:

`theta_ref =
 wcr + (wcs-wcr)/(1+(alpha*100)^n)^m`.

The frozen Staringreeks-2018 source table was replayed for all 36
B01..B18/O01..O18 materials.

For every material:
- materialization succeeds;
- theta is finite;
- theta lies within [wcr,wcs];
- production theta matches the independently evaluated direct equation oracle
  to the declared real64 tolerance.

A2/A3:
PASS.

## Source identity

Source:
- top depth;
- bottom depth;
- dry bulk density

are copied bit-identically into the resulting ELASTIC17 horizon descriptor.

No density or geometry averaging occurs.

A4:
PASS.

## Fail-closed input contract

Rejected:
- invalid horizon geometry;
- non-positive dry density;
- invalid available organic-matter percentage;
- invalid/non-finite MvG retention parameters;
- n <= 1;
- non-positive alpha.

A5:
PASS.

## ELASTIC17 composition

Two adjacent materialized source horizons map through the admitted ELASTIC17
complete-compartment rule and preserve their expected descriptor ownership.

A6:
PASS.

## Downstream physical-policy preservation

All-MINERAL materialized horizons compose through ELASTIC17 and ELASTIC16 into
the admitted generated-prior chain.

When a horizon is PEAT:
- ELASTIC19 preserves PEAT;
- ELASTIC17 preserves PEAT;
- downstream ELASTIC16/14 generated-prior materialization rejects that node.

No hidden reclassification occurs.

A7:
PASS.

## Optimization identity

Focused output is identical at O0 and O2.

A8:
PASS.

## Source scope

Production delta is exactly:

`src/adapter/mod_fmr_elastic_storage_horizon_descriptor_materializer.f90`.

No runtime/kernel/legacy source changes.

A9:
PASS.

## Admission meaning

A green ELASTIC19 closes the typed source-horizon descriptor construction seam:

`resolved source horizon + resolved Staringreeks retention parameters`
-> regime + theta(-100 cm)
-> ELASTIC17 horizon descriptor.

Still outside scope:
- BOFEK/BRO external data acquisition;
- profile selection;
- Staringreeks block-code lookup;
- file/input grammar;
- automatic generated-prior request.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
