# F-PE-ELASTIC19R — all-36 Staringreeks preservation preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRESERVATION_REPLAY

Baseline:
`integration/f-ci-canonical@7b34fb5a980b647423d8c5062d0ec64f0568e0f7`

Parent authority:
- `F-PE-ELASTIC19_CLOSURE.md`;
- admitted production blob
  `e098362e84f8dab2f063f875546d80efc1bb7e5c`.

## Purpose

Strengthen ELASTIC19 preservation from one representative B01 retention case
to all 36 frozen Staringreeks-2018 B01..B18/O01..O18 materials.

No production source change is authorized.

## Oracle

Read:
`tests/fpe/data/fpe_elastic05_staringreeks_2018.csv`.

For every material:
- build a valid MINERAL horizon with the admitted ELASTIC19 builder;
- independently evaluate
  `theta(-100)=wcr+(wcs-wcr)/(1+(alpha*100)^n)^(1-1/n)`;
- require real64 agreement within `2e-15`;
- require theta within [wcr,wcs].

Retain the existing ELASTIC19 regime, fail-closed, source-identity and
downstream-composition checks.

## Qualification

R1. admitted production blob exact.

R2. all 36 materials execute and match the independent equation oracle.

R3. original ELASTIC19 A1-A11 semantics remain green.

R4. O0/O2 identity.

R5. production diff is empty.

A green ELASTIC19R is preservation evidence only.
