# F-PE-ELASTIC12 — BOFEK/Staringreeks transfer preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_TRANSFER_RESULTS

Baseline:
`research/f-pe-elastic11-predictor-model@9165727771998cec2d1fa09aee62637d9d78ce68`

Current canonical reconciliation:
`integration/f-ci-canonical@30e507fc8bdf7f7c37f327ab378e5c4a8ae39b94`.

Parent authority:
- `F-PE-ELASTIC11_CLOSEOUT.md`;
- independently qualified M1 mechanical predictor;
- spent ELASTIC11 holdout may not be reused for tuning.

## Purpose

Test whether the independently validated BHR-GT mechanical predictor can be
transferred, without new statistical fitting, to the BOFEK2020/Staringreeks
soil-layer representation used by SWAP.

This is a transfer study, not a new ELAS regression.

No solver/runtime/performance result may enter the parameter mapping.

## Official source authorities

BOFEK2020:
`https://nhi.nu/documents/225/bofek_1.0.0.zip`

Staringreeks 2018:
`https://nhi.nu/documents/224/staringreeks_1.0.0.zip`

Existing ELASTIC02 authority already binds the Staringreeks member
`staringreeks/Data/staringreeks_2018.csv` and its 36 B01..B18/O01..O18
materials.

The BOFEK2020 WUR/NHI documentation states that:
- 368 derived standard soil profiles underlie BOFEK2020;
- 79 BOFEK2020 units are clusters of those profiles;
- profile layers are coupled to Staringreeks building blocks.

The WUR soil-physics profile service additionally exposes horizon-level
composition, density and Staringreeks unit. Its documented profile data are
derived/modal soil profiles rather than direct field observations.

## Predictor-state semantics

The frozen ELASTIC11 M1 predictor was trained on BHR-GT source fields:

- `volumetricMassDensity`: field-moist/wet volumetric mass density, source unit
  `g/cm3`;
- `waterContent`: gravimetric water content, source unit `%`;
- BHR-GT specimen state in the calibration corpus is predominantly
  `sampleMoistness=veldvochtig`.

The BOFEK/derived-profile density field is dry bulk density.

Therefore the BHR-GT predictors are NOT copied directly from BOFEK density.

## Physical state bridge

For BOFEK/Staringreeks layer dry bulk density `rho_d [g/cm3]` and volumetric
water content `theta(h) [cm3/cm3]` at a declared pressure head `h`:

`rho_wet(h) = rho_d + theta(h)`

assuming water density `1 g/cm3`.

The corresponding gravimetric water content on dry-mass basis is:

`w(h) [%] = 100 * theta(h) / rho_d`.

These are unit conversions/state reconstructions, not fitted relations.

The frozen ELASTIC11 M1 equation is then evaluated unchanged:

`log10(Ss [cm^-1]) =
 -5.144312248981006
 -0.25581251314464676 * z(rho_wet)
 +0.15229775506831100 * z(w)`.

No coefficient may be altered in ELASTIC12.

## Reference-state uncertainty

BHR-GT `veldvochtig` is not one fixed matric pressure head.

Therefore ELASTIC12 must not select a single reference head after seeing
resulting ELAS values.

The transfer audit evaluates the following frozen state grid:

- h = -10 cm
- h = -33 cm
- h = -100 cm
- h = -330 cm
- h = -1000 cm

No state on this grid is a priori declared the production value.

The purpose is to quantify state sensitivity and determine whether a robust
order-of-magnitude layer prior is possible.

## Phase A source audit

Before any transfer calculation:

1. fetch the exact BOFEK and Staringreeks official zip files;
2. persist URL, retrieval time, byte size and SHA-256;
3. inventory archive members;
4. identify profile/layer tables only by explicit schema/header/content;
5. verify whether dry bulk density and Staringreeks building-block code are
   present for the 368 derived profiles;
6. verify units and missing-value conventions;
7. do not infer fields from filename alone.

If the BOFEK archive does not contain a source-bound dry-density/profile table,
classification is `TRANSFER_SOURCE_INCOMPLETE` and no silent substitute is
allowed.

## Phase B transfer audit

Authorized only after Phase A establishes source binding.

For every source-bound BOFEK/derived-profile layer with:
- finite positive dry bulk density;
- valid Staringreeks B01..B18/O01..O18 building block;

calculate at every frozen pressure head:
- theta(h) from the exact Staringreeks 2018 MvG retention relation;
- reconstructed wet density;
- reconstructed gravimetric water content;
- frozen M1 ELAS/Ss prediction.

No clipping to the ELASTIC11 calibration target range is allowed during the
audit.

## Extrapolation diagnostics

For each reconstructed predictor pair report standardized positions relative to
the frozen ELASTIC11 calibration:

`z_rho = (rho_wet - 1.4337873737373736) / 0.34422692442216535`

`z_w = (w - 191.8190909090909) / 182.02868188688447`.

Classify each layer/state as:
- `IN_DOMAIN`: |z_rho| <= 2 and |z_w| <= 2;
- `EDGE`: either predictor has 2 < |z| <= 3 and neither exceeds 3;
- `EXTRAPOLATION`: either predictor has |z| > 3.

This is a transfer-risk diagnostic, not a model refit.

## Required summaries

Report separately by:
- pressure-head state;
- Staringreeks building block;
- BOFEK2020 unit where source mapping is available;
- topsoil B versus subsoil O family.

At minimum report:
- layer count;
- predicted Ss minimum, median, maximum;
- 10th and 90th percentiles;
- fraction IN_DOMAIN / EDGE / EXTRAPOLATION;
- ratio of predicted Ss between h=-10 and h=-1000 for identical layers;
- fraction below, near and above `1e-6 cm^-1`.

For descriptive comparison only, define:
- below: Ss < 0.5e-6 cm^-1;
- near: 0.5e-6 <= Ss <= 2e-6 cm^-1;
- above: Ss > 2e-6 cm^-1.

These bins do not define correctness.

## Advancement rule

A static BOFEK-layer ELAS prior may advance to a later production-oriented
work unit only if:

1. at least 95% of source-bound layers are IN_DOMAIN or EDGE at one or more
   physically interpretable reference states;
2. no single pressure-head choice is selected solely because it produces a
   preferred ELAS magnitude;
3. state sensitivity is explicitly quantified;
4. the resulting mapping remains a physical prior, not a solver-optimized value;
5. uncertainty of the independently validated predictor (approximately factor
   2.1 typical multiplicative holdout error) is carried forward.

If no state meets the domain-coverage condition:

`TRANSFER_NOT_SUPPORTED_WITH_CURRENT_PREDICTOR_DOMAIN`.

If source coverage is insufficient:

`TRANSFER_SOURCE_INCOMPLETE`.

If a bounded transfer is supported:

`BOFEK_LAYER_PRIOR_TRANSFER_FEASIBLE`.

## Prohibited actions

ELASTIC12 must not:
- refit M1;
- reuse the spent ELASTIC11 holdout for tuning;
- infer wet density by equating it with BOFEK dry density;
- use MvG parameters as statistical predictors;
- choose h by minimizing SWAP runtime;
- choose h by forcing results toward `1e-6 cm^-1`;
- add production parser/input semantics;
- activate elasticity in production runs.

## Outcome

ELASTIC12 answers only whether the validated mechanical relation can be
translated into a source-bound BOFEK/Staringreeks layer prior with transparent
state uncertainty.
