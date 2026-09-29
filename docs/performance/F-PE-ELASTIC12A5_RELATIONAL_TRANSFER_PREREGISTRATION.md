# F-PE-ELASTIC12A5 — relational BOFEK/BRO profile transfer preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_RELATIONAL_TRANSFER_RESULTS

Parent:
`F-PE-ELASTIC12A4_PDOK_ATOM_PREREGISTRATION.md`.

Current canonical reconciliation:
`integration/f-ci-canonical@2a91ef7a4ed3a211528538ba2f809993f820f300`.

The canonical delta since the preceding ELASTIC12 reconciliation contains only
F-PE-NLGLOB11 documentation, tests and workflow files and does not intersect
the ELASTIC12 dependency surface.

## New source fact established by A4 inspection

The official PDOK BRO Bodemkaart GeoPackage:

`https://service.pdok.nl/tno/bro-bodemkaart/atom/downloads/BRO_DownloadBodemkaart.gpkg`

was retrieved as:

- bytes: `153059328`;
- SHA-256:
  `e3243d60bd23a72cd034bda549975d6f859ddd5aeac06e79b31a6a63008319e0`.

The GeoPackage contains a normalized relational model rather than a soil code
directly on the polygon table.

Relevant source tables include:

- `normalsoilprofiles`;
- `soilhorizon`;
- `soilarea`;
- `soilarea_normalsoilprofile`;
- `soilarea_soilunit`.

Observed source counts before this preregistration:

- `normalsoilprofiles`: 368 records;
- `soilhorizon`: 1568 records;
- all 1568 horizon records have a finite density value.

For the known BOFEK example profile `16160 / Rn47C`, the GeoPackage contains
the same five horizon boundaries and Staringreeks building blocks as the
official BOFEK2020 `allprofiles368_2020.csv` record.

A4 itself remains negative under its frozen requirement for a soil-code
attribute directly on the polygon table. A5 is a new preregistered relational
route and does not rewrite the A4 result.

## Purpose

Determine whether the official BOFEK2020 368-profile definition and the
current BRO Bodemkaart 368-profile/horizon representation are identity
compatible for the physical ELAS transfer.

Only after exact profile/layer reconciliation may the frozen ELASTIC11 M1
predictor be evaluated.

## Frozen source authorities

### BOFEK2020

URL:
`https://nhi.nu/documents/225/bofek_1.0.0.zip`

Required SHA-256:
`4380ba2fe8b817523e5f2fd6608152e248ef0f8181775debbf250f027c5707fd`.

Profile table:
`bofek/Data/allprofiles368_2020.csv`.

Required row count:
368.

### Staringreeks 2018

URL:
`https://nhi.nu/documents/224/staringreeks_1.0.0.zip`

Required SHA-256:
`9d06dff19392111dad110802058e3894c30355f553842ce32d89eed005071cd5`.

Member:
`staringreeks/Data/staringreeks_2018.csv`.

Required material set:
B01..B18 and O01..O18.

### BRO Bodemkaart GeoPackage

Use the exact A4 source URL and require the current retrieved file to match the
A4 SHA above. If it has changed, stop with `PDOK_SOURCE_DRIFT`; do not silently
mix versions.

## Density semantics

The BRO/WUR derived-profile `density` quantity is dry bulk density in
`g cm^-3`.

The ELASTIC11 predictor input `volumetricMassDensity` is field-moist/wet
volumetric mass density in `g cm^-3`.

These are not interchangeable.

## Frozen profile reconciliation

### Profile IDs

The exact set of 368 BOFEK `iprofile` values must equal the exact set of 368
BRO `normalsoilprofile_id` values.

Any missing or extra profile is a hard reconciliation failure.

### Soil code

For every profile:

`BOFEK bodemcode == BRO normalsoilprofiles.soilunit`.

### Layer sequence

For every BOFEK profile, ignore unused zero/empty layer slots and materialize
its ordered layers from:

- `isoil1..isoil9`;
- cumulative lower boundaries `iz1..iz9`.

For every BRO profile, use ordered `soilhorizon.layernumber`,
`lowervalue`, `uppervalue`, and `staringseriesblock`.

Depth units are reconciled as:

`BOFEK iz [cm] / 100 = BRO uppervalue [m]`.

The previous BOFEK lower boundary is zero for layer 1 and the previous
cumulative `iz` thereafter.

### Staringreeks code mapping

BOFEK `isoil` is the Staringreeks numerical unit 1..36.

BRO `staringseriesblock` is interpreted only by its explicit encoded family:

- 101..118 -> B01..B18;
- 201..218 -> O01..O18.

The corresponding Staringreeks numerical unit must equal:
- B01..B18 -> 1..18;
- O01..O18 -> 19..36.

No nearest or approximate material mapping is allowed.

### Reconciliation gate

All 368 profiles and every active BOFEK layer must match exactly on:
- profile id;
- bodemcode/soilunit;
- layer count;
- layer order;
- upper/lower boundaries within `1e-9 m`;
- Staringreeks material identity.

If any mismatch occurs, classification is:

`BOFEK_BRO_PROFILE_RECONCILIATION_FAILED`

and no ELAS transfer result may advance.

## Frozen retention relation

For pressure head `h < 0 cm`, with Staringreeks 2018 parameters:

- residual water content `theta_r = wcr`;
- saturated water content `theta_s = wcs`;
- `alpha` in `cm^-1`;
- `n = npar`;
- `m = 1 - 1/n`;

calculate:

`theta(h) = theta_r + (theta_s-theta_r) /
             (1 + (alpha*abs(h))^n)^m`.

This is used only to reconstruct a declared water state from an already
assigned Staringreeks building block. MvG parameters are not statistical
predictors for ELAS.

Frozen pressure-head grid:

- -10 cm;
- -33 cm;
- -100 cm;
- -330 cm;
- -1000 cm.

## Frozen BHR-GT predictor-state bridge

For each reconciled horizon and each frozen pressure head:

`rho_wet = rho_dry + theta(h)`

with water density fixed at `1 g cm^-3`.

Gravimetric water content:

`w_percent = 100 * theta(h) / rho_dry`.

Then evaluate the frozen ELASTIC11 M1 equation without refit:

`log10(Ss [cm^-1]) =
 -5.144312248981006
 -0.25581251314464676 *
   ((rho_wet-1.4337873737373736)/0.34422692442216535)
 +0.15229775506831100 *
   ((w_percent-191.8190909090909)/182.02868188688447)`.

`Ss = 10^log10(Ss)`.

No clipping is allowed.

## Domain and uncertainty diagnostics

For every layer/state calculate the frozen ELASTIC12 z-domain classification:

- IN_DOMAIN: both absolute z <= 2;
- EDGE: at least one 2 < absolute z <= 3, neither > 3;
- EXTRAPOLATION: either absolute z > 3.

The independently measured ELASTIC11 holdout uncertainty remains part of every
interpretation:

typical multiplicative MAE approximately `2.12x`.

No ELASTIC12 calculation reduces that empirical predictor uncertainty.

## State-sensitivity diagnostics

For every layer report:

`state_ratio = max(Ss over frozen heads) / min(Ss over frozen heads)`.

Summary gates:

- median state ratio;
- 90th percentile state ratio;
- maximum state ratio;
- fraction with ratio <= 1.25;
- fraction with ratio <= 1.5;
- fraction with ratio <= 2.0.

No pressure head is selected after seeing these values.

## Transfer advancement

Classification `BOFEK_LAYER_PRIOR_TRANSFER_FEASIBLE` requires:

1. exact 368-profile/layer reconciliation passes;
2. all dry densities are finite and positive;
3. at least one frozen pressure-head state has >=95% of layers classified
   IN_DOMAIN or EDGE;
4. no source or model coefficient changed after preregistration.

Otherwise:
- source/profile mismatch -> `BOFEK_BRO_PROFILE_RECONCILIATION_FAILED`;
- predictor-domain failure -> `TRANSFER_NOT_SUPPORTED_WITH_CURRENT_PREDICTOR_DOMAIN`.

A feasible result remains a physical prior with explicit state and predictor
uncertainty. It is not production admission.
