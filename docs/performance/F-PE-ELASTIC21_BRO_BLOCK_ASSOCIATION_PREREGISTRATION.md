# F-PE-ELASTIC21 — BRO Staringreeks-block association preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@7032a7498abdec7adf879ab9ad0c05dee8049239`

Parent authority:
- `F-PE-ELASTIC20_CLOSURE.md`;
- qualified ELASTIC12A5 BOFEK/BRO relational bridge.

ELASTIC12A5 source identity:
- 368 / 368 BOFEK profiles matched BRO normal soil profiles;
- 1568 / 1568 layers matched source horizons;
- BOFEK Staringreeks coding and BRO `staringseriesblock` were identical.

Frozen encoding:
- BOFEK `isoil=1..18`
  -> Staringreeks `B01..B18`
  -> BRO `staringseriesblock=101..118`;
- BOFEK `isoil=19..36`
  -> Staringreeks `O01..O18`
  -> BRO `staringseriesblock=201..218`.

## Purpose

Add one stateless adapter that converts an already selected BRO source
horizon's `staringseriesblock` integer to the exact Staringreeks 2018 material
code consumed by ELASTIC20.

The seam is:

`BRO staringseriesblock`
-> exact `B01..B18/O01..O18`
-> ELASTIC20 catalog lookup.

No profile retrieval or spatial selection is performed here.

## Input contract

Input:
- integer `staringseriesblock`.

Accepted values are exactly:
- 101..118;
- 201..218.

No other integer is accepted.

## Frozen mapping

For `101 <= block <= 118`:

`index = block - 100`

`code = B01..B18`.

For `201 <= block <= 218`:

`index = block - 200`

`code = O01..O18`.

The adapter must emit the exact three-character Staringreeks code.

No:
- modulo mapping;
- range wrapping;
- nearest block;
- BOFEK `isoil` reinterpretation;
- string parsing

is allowed.

## Output contract

On success return:
- exact code `character(len=3)`;
- family code:
  - B family;
  - O family;
- family index 1..18;
- ELASTIC20 catalog index:
  - B01..B18 -> 1..18;
  - O01..O18 -> 19..36;
- status OK.

On invalid input:
- blank code;
- zero indices;
- status NOT_FOUND.

## Qualification matrix

A1. all blocks 101..118 map exactly to B01..B18.

A2. all blocks 201..218 map exactly to O01..O18.

A3. returned ELASTIC20 catalog indices are exactly 1..36 in the corresponding
frozen order.

A4. invalid blocks fail closed:
- 0;
- 100;
- 119;
- 120;
- 199;
- 200;
- 219;
- negative integer;
- large unrelated integer.

A5. every valid mapped code resolves successfully through admitted ELASTIC20
and returns the corresponding catalog index.

A6. representative mapped records compose through admitted ELASTIC19 horizon
descriptor construction and produce the same descriptor as direct code lookup.

A7. the mapping is exact for both topsoil B and subsoil O families; no family
collapse is permitted.

A8. O0/O2 identity.

A9. production source scope is exactly one new stateless adapter module; no
existing runtime/kernel/solver/legacy source is modified.

## Admission boundary

A green ELASTIC21 admits only already-resolved BRO
`staringseriesblock` -> Staringreeks 2018 material-code association.

It does not admit:
- BRO/BOFEK profile retrieval;
- horizon selection;
- location/profile selection;
- GeoPackage or database I/O;
- file syntax;
- automatic generated-prior request.
