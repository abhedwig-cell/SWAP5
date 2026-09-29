# F-PE-ELASTIC21 — BRO Staringreeks block-code mapping preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@d4d70ca5b776385db8f0ca9ffa9c9dfa5625c705`

Parent authority:
- `F-PE-ELASTIC12A5_RELATIONAL_BRIDGE_PREREGISTRATION.md`;
- `F-PE-ELASTIC12A5_RESULT.md`;
- `F-PE-ELASTIC20_CLOSURE.md`.

## Purpose

Add one stateless adapter that maps the already resolved BRO/BOFEK
`staringseriesblock` integer to the exact immutable ELASTIC20
Staringreeks-2018 code.

The seam is:

`101..118 -> B01..B18`

`201..218 -> O01..O18`.

No profile, location or file lookup is performed.

## Source authority

The ELASTIC12 exact BOFEK/BRO relational bridge qualified the following
identity over all 1568 source layers:

- BOFEK topsoil codes 1..18 correspond to BRO
  `staringseriesblock=101..118`;
- BOFEK subsoil codes 19..36 correspond to BRO
  `staringseriesblock=201..218`.

ELASTIC21 freezes only the BRO block-to-ELASTIC20 code projection.

## Frozen mapping

For block `b`:

- when `101 <= b <= 118`:
  `code = 'B' // two_digit(b-100)`;
- when `201 <= b <= 218`:
  `code = 'O' // two_digit(b-200)`.

No other integer is accepted.

## Fail-closed rule

Rejected:
- 0;
- 1..36;
- 100;
- 119..200;
- 219 and above;
- negative values.

No modulo, clamping, nearest-code, B/O family inference or historical-series
fallback is permitted.

## Output contract

On success return:
- exact character(len=3) Staringreeks code;
- exact ELASTIC20 catalog index:
  - 1..18 for B01..B18;
  - 19..36 for O01..O18;
- status OK.

The adapter may call ELASTIC20 to verify catalog identity, but it may not
duplicate retention parameters.

## Qualification matrix

A1. all 18 B-blocks map exactly to B01..B18 and catalog indices 1..18.

A2. all 18 O-blocks map exactly to O01..O18 and catalog indices 19..36.

A3. every valid mapped code resolves through admitted ELASTIC20.

A4. malformed/out-of-range blocks fail closed with blank code and index 0.

A5. representative B01 and O18 mappings compose through ELASTIC20 and
ELASTIC19 identically to direct material-code lookup.

A6. O0/O2 identity.

A7. production source scope is exactly one new stateless adapter module; no
existing runtime/kernel/solver/legacy source is modified.

## Admission boundary

A green ELASTIC21 admits only BRO/BOFEK Staringreeks block-code projection.

It does not admit:
- BOFEK/BRO profile retrieval;
- location/profile selection;
- source-horizon retrieval;
- file syntax;
- alternate Staringreeks years;
- automatic generated-prior request.
