# F-PE-ELASTIC19 — resolved horizon descriptor materialization preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@57fba7961ed5a32679556653c6c4730d775623f2`

Parent authority:
- ELASTIC13 qualified soil-regime policy;
- ELASTIC14 admitted physical-prior materializer;
- ELASTIC17 admitted horizon-to-node mapper;
- ELASTIC18 admitted SWAP-grid normalization.

## Purpose

Add one stateless typed adapter that turns already resolved source-horizon
properties into the exact horizon descriptor consumed by ELASTIC17.

The adapter closes two bounded preprocessing steps:

1. classify the already resolved source horizon under the frozen ELASTIC13
   regime rule;
2. evaluate Staringreeks/MvG volumetric water content at the already frozen
   reference head `h=-100 cm`.

It performs no external data retrieval.

## Input contract

The caller supplies one normalized source horizon:

- top depth [m below soil surface];
- bottom depth [m below soil surface];
- dry bulk density [g/cm3];
- organic-matter availability flag;
- organic matter [% dry mass] when available;
- explicit peat-type-present flag;
- Staringreeks retention parameters:
  - residual water content `wcr`;
  - saturated water content `wcs`;
  - `alpha` [cm^-1];
  - `n`.

No soil/profile ID or file path enters this contract.

## Frozen regime rule

Before implementation results are inspected:

- if `peat_type_present=.true.`: PEAT;
- else if organic matter unavailable: UNKNOWN;
- else if organic matter > 15%: ORGANIC_RICH_NONPEAT;
- else: MINERAL.

Exactly 15% belongs to MINERAL.

No hydraulic parameter may change the regime classification.

## Frozen reference-water calculation

Reference pressure head:

`h_ref=-100 cm`.

For valid MvG/Staringreeks input:

`m = 1 - 1/n`

`theta_ref =
 wcr + (wcs-wcr) / (1 + (alpha*abs(h_ref))^n)^m`.

The calculation uses real64 and no fitted correction.

This is the same default MvG retention relation used in the ELASTIC12 transfer
study at the fixed -100 cm state.

## Input validation

Fail closed on:
- non-finite geometry or descriptor values;
- top depth < 0;
- bottom <= top;
- dry density <= 0;
- available organic matter outside [0,100]%;
- non-finite/invalid retention parameters;
- `wcr < 0`;
- `wcs <= wcr` or `wcs > 1`;
- `alpha <= 0`;
- `n <= 1`;
- non-finite/out-of-range resulting theta.

When organic matter is unavailable, its numeric placeholder is ignored.

## Output contract

Return one `fmr_elastic_storage_horizon_t` containing:

- source geometry unchanged;
- dry density unchanged;
- computed `theta_ref_cm3_cm3`;
- classified regime.

No ELAS value is produced.

## Qualification matrix

A1. exact regime boundary:
- 15% non-peat -> MINERAL;
- >15% non-peat -> ORGANIC_RICH_NONPEAT;
- peat flag -> PEAT;
- unavailable OM without peat -> UNKNOWN.

A2. Staringreeks B01/B12/O05/O14 reference-theta values at -100 cm match an
independent direct equation oracle.

A3. all 36 frozen Staringreeks-2018 materials produce finite theta in
`[wcr,wcs]`.

A4. source geometry/density are copied bit-identically.

A5. invalid geometry, density, OM and retention parameters fail closed.

A6. produced horizon descriptors compose through admitted ELASTIC17 exactly.

A7. MINERAL output composes through ELASTIC17 -> ELASTIC16 -> ELASTIC14/15;
PEAT remains PEAT and is rejected downstream rather than reclassified.

A8. O0/O2 identity.

A9. production source scope is exactly one new stateless adapter module; no
runtime/kernel/legacy source is modified.

## Boundary

ELASTIC19 does not:
- fetch BOFEK/BRO;
- select a BOFEK profile;
- resolve a Staringreeks block code to parameters;
- parse files;
- choose a reference head;
- calculate or activate ELAS directly;
- alter solver policy.
