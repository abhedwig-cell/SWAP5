# F-PE-ELASTIC19 — source horizon descriptor builder preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_PRODUCTION_CHANGE

Baseline:
`integration/f-ci-canonical@262190047ff97399cb1368cf45d7965dedf6de86`

Parent authority:
- `F-PE-ELASTIC13_CLOSEOUT.md`;
- `F-PE-ELASTIC17_CLOSURE.md`;
- `F-PE-ELASTIC18_CLOSURE.md`.

## Purpose

Add one stateless adapter that builds an ELASTIC17 source horizon from already
resolved source attributes.

The adapter closes exactly this seam:

`resolved BRO horizon attributes + resolved Staringreeks retention parameters`
-> `fmr_elastic_storage_horizon_t`.

It performs no profile lookup and no external I/O.

## Input contract

Already resolved source inputs:

- horizon top depth [m below surface];
- horizon bottom depth [m below surface];
- dry bulk density [g/cm3];
- organic-matter availability;
- organic-matter content [%];
- explicit peat-type-present flag;
- Staringreeks residual water content `wcr` [cm3/cm3];
- saturated water content `wcs` [cm3/cm3];
- Staringreeks `alpha` [cm^-1];
- Staringreeks `n > 1`.

The association from a source horizon's Staringreeks code to these numeric
retention parameters remains external to ELASTIC19.

## Frozen reference state

Use the already qualified ELASTIC13 operational reference:

`h_ref = -100 cm`.

No alternate pressure head may be selected by ELASTIC19.

## Frozen retention calculation

Let:

`m = 1 - 1/n`

and:

`theta_ref =
 wcr + (wcs - wcr) / (1 + (alpha * 100)^n)^m`.

This is the same Staringreeks MvG retention calculation used in the qualified
ELASTIC12/13 transfer chain.

No fitting or clipping is allowed.

## Frozen regime classification

Exactly ELASTIC13 semantics:

1. if explicit peat type is present:
   `PEAT`;
2. else if organic matter is unavailable:
   `UNKNOWN`;
3. else if organic matter > 15%:
   `ORGANIC_RICH_NONPEAT`;
4. else:
   `MINERAL`.

The 15% separator may not be retuned.

Peat status takes precedence over organic-matter percentage.

## Validation

Fail closed on:

- non-finite geometry;
- top depth < 0;
- bottom <= top;
- non-finite or non-positive dry density;
- non-finite organic matter when declared available;
- organic matter < 0 or > 100%;
- non-finite retention parameters;
- `wcr < 0`;
- `wcs <= wcr` or `wcs > 1`;
- `alpha <= 0`;
- `n <= 1`;
- non-finite derived `m` or `theta_ref`;
- derived theta outside [wcr,wcs].

## Output contract

On success return one
`fmr_elastic_storage_horizon_t` with:

- source geometry copied exactly;
- dry density copied exactly;
- `theta_ref_cm3_cm3` from the frozen -100 cm retention evaluation;
- frozen regime classification.

No ELAS value is computed here.

## Qualification matrix

A1. representative mineral Staringreeks parameters reproduce independently
rederived theta(-100 cm).

A2. organic matter <=15%, no peat -> MINERAL.

A3. organic matter >15%, no peat -> ORGANIC_RICH_NONPEAT.

A4. explicit peat flag -> PEAT regardless of organic-matter value.

A5. organic matter unavailable and no peat -> UNKNOWN.

A6. invalid geometry, density, organic matter, or retention parameters fail
closed.

A7. output source geometry and density are bit-identical to inputs.

A8. valid MINERAL output composes through ELASTIC17 mapping and ELASTIC16
assembly exactly as a manually constructed horizon with the same theta/regime.

A9. PEAT output remains PEAT through ELASTIC17 and is rejected downstream by
the admitted generated-prior policy.

A10. O0/O2 identity.

A11. source scope is exactly one new stateless adapter module plus tests/docs;
no existing runtime/kernel/legacy production source changes.

## Admission boundary

A green ELASTIC19 admits only source-horizon descriptor construction.

It does not admit:
- BOFEK/BRO data loading;
- profile selection;
- Staringreeks code lookup;
- file syntax;
- automatic prior request;
- state-dependent ELAS;
- peat generated-prior assignment.
