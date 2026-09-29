# F-PE-ELASTIC21 — BRO Staringreeks-block association preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@e46985908b19f83cf2f17f86507aa3495df971a2`

Parent authority:
- `F-PE-ELASTIC12_CLOSEOUT.md`;
- `F-PE-ELASTIC19_CLOSURE.md`;
- `F-PE-ELASTIC20_CLOSURE.md`.

## Purpose

Add one stateless adapter that translates the source-bound BRO
`soilhorizon.staringseriesblock` integer to the exact immutable Staringreeks
2018 material code consumed by ELASTIC20.

This closes only:

`BRO staringseriesblock`
-> `B01..B18/O01..O18`
-> ELASTIC20 catalog lookup.

No profile selection, data retrieval or physical calculation is introduced.

## Source association authority

ELASTIC12 established exact identity between BOFEK layer coding and BRO
`staringseriesblock` for all 1568 source horizons.

Frozen mapping:

- 101..118 -> B01..B18
- 201..218 -> O01..O18

No other integer values are admitted.

## Input contract

Input:
- integer `staringseriesblock`.

Output on success:
- exact three-character Staringreeks 2018 code;
- family flag B or O;
- 1..18 family index;
- status OK.

## Fail-closed rule

Unsupported values return NOT_FOUND with:
- empty code;
- family index 0.

No:
- nearest-code fallback;
- modulo arithmetic;
- coercion from 119..200;
- historical code-family substitution

is allowed.

## Qualification matrix

A1. all 18 topsoil values 101..118 map exactly to B01..B18.

A2. all 18 subsoil values 201..218 map exactly to O01..O18.

A3. endpoint identity: 101=B01, 118=B18, 201=O01, 218=O18.

A4. unsupported values fail closed:
0, 100, 119, 199, 200, 219, negative, large positive.

A5. every mapped code resolves successfully through admitted ELASTIC20 and
preserves exact catalog index/order.

A6. mapped code + ELASTIC20 + ELASTIC19 yields the same horizon descriptor as
direct code selection for representative B and O cases.

A7. O0/O2 identity.

A8. production source scope is exactly one new stateless adapter module plus
tests/docs; no existing runtime/kernel/solver/legacy source is modified.

## Admission boundary

A green ELASTIC21 admits only BRO block-to-Staringreeks-code association.

It does not admit:
- BOFEK/BRO file or network loading;
- normalsoilprofile selection;
- horizon selection;
- location lookup;
- alternate Staringreeks years;
- automatic generated-prior request.
