# F-PE-ELASTIC19 — source horizon descriptor builder result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic19-horizon-descriptor-builder`

Qualified postimage:
`fbdbea0af224433816c8f8e9509e5141a0ab3476`

Workflow run:
`36561705709`

Job:
`109383870826`

Conclusion:
SUCCESS.

## Production scope

Exactly one production source file is added:

`src/adapter/mod_fmr_elastic_storage_horizon_descriptor_builder.f90`.

No existing production source is modified.

The adapter performs only:
- source validation;
- frozen Staringreeks theta(-100 cm) evaluation;
- frozen ELASTIC13 regime classification;
- construction of the admitted ELASTIC17 horizon type.

It performs no profile lookup, data fetch, parser action, ELAS inference or
runtime mutation.

## A1 retention identity

Repository Staringreeks B01 parameters:

- wcr = 0.02000000;
- wcs = 0.42749391;
- alpha = 0.02165898 cm^-1;
- n = 1.73473668;

produce:

`theta(-100 cm)=0.22929575043577552`.

PASS.

## A2–A5 regime classification

Frozen ELASTIC13 semantics are preserved:

- no peat + OM <=15% -> MINERAL;
- no peat + OM >15% -> ORGANIC_RICH_NONPEAT;
- peat present -> PEAT regardless of OM;
- no peat + unavailable OM -> UNKNOWN.

PASS.

## A6 fail closed

Invalid geometry, density, organic matter and retention parameters are rejected.

PASS.

## A7 source identity

Geometry and dry density are copied bit-identically from source input.

PASS.

## A8 downstream composition

A valid MINERAL horizon built by ELASTIC19:
- maps through admitted ELASTIC17;
- assembles through admitted ELASTIC16;
- produces a valid generated-prior parameter postimage.

PASS.

## A9 peat provenance

PEAT remains PEAT through descriptor construction and ELASTIC17 mapping.

The downstream admitted generated-prior policy rejects it exactly as intended.

PASS.

## A10 O0/O2 identity

Focused output is identical at O0 and O2.

PASS.

## A11 source scope

Production delta is exactly:

`src/adapter/mod_fmr_elastic_storage_horizon_descriptor_builder.f90`.

No runtime/kernel/legacy production source changes.

PASS.

## Admission meaning

A green ELASTIC19 admits only source-horizon descriptor construction:

`resolved source horizon + resolved Staringreeks retention parameters`
-> `rho_dry + theta(-100 cm) + regime + geometry`.

Still outside scope:
- BOFEK/BRO profile retrieval;
- Staringreeks code-to-parameter lookup;
- location/soil-profile selection;
- file syntax;
- automatic generated-prior request.

## Decision

Classification:

`QUALIFIED_ADMISSION_CANDIDATE`.
