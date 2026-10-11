# F-PE-ELASTIC20 — immutable Staringreeks 2018 catalog preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@7b34fb5a980b647423d8c5062d0ec64f0568e0f7`

Parent authority:
- `F-PE-ELASTIC19_CLOSURE.md`;
- F-PE-ELASTIC02 official Staringreeks 2018 source record.

Official source authority:
- URL: `https://nhi.nu/documents/224/staringreeks_1.0.0.zip`;
- official zip SHA-256:
  `9d06dff19392111dad110802058e3894c30355f553842ce32d89eed005071cd5`;
- member:
  `staringreeks/Data/staringreeks_2018.csv`;
- member SHA-256:
  `ed2e47bcacdbb6e5fe18eb4f712c3ead996f26f97d647fa550dafd8683d64494`;
- exact rows: 36;
- exact material codes: B01..B18 and O01..O18.

## Purpose

Add one immutable, stateless catalog adapter that resolves an already selected
Staringreeks 2018 material code to the exact retention parameters consumed by
ELASTIC19.

The seam is:

`B01..B18/O01..O18`
-> exact `wcr,wcs,alpha,npar`
-> `fmr_elastic_storage_retention_t`.

No file I/O is performed at runtime.

## Input contract

Input:
- exact material code as character data.

Accepted codes:
- `B01` through `B18`;
- `O01` through `O18`.

The lookup may ignore trailing character padding only.

No:
- lowercase normalization;
- aliases;
- whitespace trimming on the left;
- numeric-only IDs;
- historical Staringreeks years

are accepted.

This prevents silent source-family substitution.

## Frozen catalog values

The production constants are copied exactly from the validated 2018 source
member for:
- `wcr`;
- `wcs`;
- `alpha`;
- `npar`.

The conductivity columns `lambda` and `ksfit` are deliberately excluded
because ELASTIC19 only needs retention.

The code order is frozen:

`B01..B18,O01..O18`.

## Provenance contract

The module publicly exposes:
- catalog year = 2018;
- catalog count = 36;
- source member SHA-256 string.

This metadata is diagnostic/provenance only and does not alter physical values.

## Lookup result

On success return:
- `fmr_elastic_storage_retention_t`;
- integer catalog index 1..36;
- status OK.

On any unsupported or malformed code:
- status NOT_FOUND;
- catalog index = 0;
- default/zero retention record.

No nearest-code fallback is allowed.

## Qualification matrix

A1. all 36 exact codes resolve successfully and in frozen order.

A2. every returned `wcr,wcs,alpha,npar` value is bit-identical to a separately
compiled oracle table transcribed from the validated repository mirror.

A3. B01 and O18 endpoint records match the official source values exactly.

A4. malformed codes fail closed:
- B00;
- B19;
- O00;
- O19;
- lowercase;
- leading-space code;
- empty code;
- numeric-only code.

A5. valid catalog output composes through admitted ELASTIC19 and reproduces the
same horizon descriptor as direct retention input.

A6. all 36 catalog records produce finite ELASTIC19 theta(-100 cm) values inside
their own [wcr,wcs] bounds.

A7. O0/O2 identity.

A8. production source scope is exactly one new stateless adapter/catalog module;
no existing runtime/kernel/solver/legacy source is modified.

## Admission boundary

A green ELASTIC20 admits only immutable code-to-retention lookup for the frozen
2018 Staringreeks catalog.

It does not admit:
- BOFEK/BRO profile retrieval;
- profile/location selection;
- horizon-to-Staringreeks-code association;
- file syntax;
- alternate Staringreeks years;
- automatic generated-prior request.
