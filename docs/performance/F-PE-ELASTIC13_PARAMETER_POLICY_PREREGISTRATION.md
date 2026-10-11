# F-PE-ELASTIC13 — physical ELAS parameter-policy preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_POLICY_AUDIT

Baseline:
`research/f-pe-elastic12-bofek-transfer@41c173dbfb2b592552ff30ecce21d13abd8fe4cb`

Canonical reconciliation:
`integration/f-ci-canonical@e59f1b2ffd97fb210c9d682332e740a1552a9f46`

Parent authorities:
- `F-PE-ELASTIC11_CLOSEOUT.md`;
- `F-PE-ELASTIC12_CLOSEOUT.md`;
- frozen ELASTIC11 M1 coefficients and normalization;
- exact BOFEK/BRO 368-profile / 1568-layer relational bridge.

## Purpose

Define a physically defensible operational **prior policy** for per-layer SWAP
ELAS without yet changing production code.

The work unit answers four questions:

1. which soil regimes may receive an automatically generated static ELAS prior;
2. which reference moisture state is used to reconstruct the ELASTIC11 predictor
   variables;
3. how independently observed predictor uncertainty is carried forward;
4. which regimes remain explicit research-only / user-supplied cases.

No solver runtime, convergence, timestep, mass-error or performance result may
enter the policy decision.

## Frozen source evidence

Use only already frozen sources:

- ELASTIC12 transfer run `36551561152`, artifact `11025251845`;
- PDOK BRO Bodemkaart GeoPackage run `36550782840`, artifact
  `11024079961`.

No new model fitting is authorized.

## Soil-regime classification

Regimes are frozen before inspecting policy results.

### PEAT

A layer is `PEAT` when BRO `soilhorizon.peattype` is present and non-empty.

This is the primary explicit peat indicator.

### ORGANIC_RICH_NONPEAT

A layer is `ORGANIC_RICH_NONPEAT` when:
- `peattype` is absent; and
- finite `organicmattercontent > 15%`.

The 15% boundary is fixed before analysis. It is used as a conservative
screening boundary because WUR/Staringreeks reference tables characterize
common mineral topsoil classes up to about 15% organic matter, while moerige
classes occupy materially higher organic-matter ranges.

This boundary is an operational research separator, not a new Dutch soil
classification standard.

### MINERAL

A layer is `MINERAL` when:
- `peattype` is absent;
- finite `organicmattercontent <= 15%`.

### UNKNOWN

Missing/non-finite organic matter with no explicit peat type is `UNKNOWN`.

UNKNOWN layers may not receive an automatic ELAS policy in this work unit.

## Static versus state-aware policy

ELASTIC13 does **not** introduce a state-dependent ELAS constitutive law.

The candidate production-shaped representation is one **static per-layer
physical prior**.

A future state-aware constitutive model would be a separate physical model and
requires separate evidence.

## Reference-state convention

Primary static reference:

`h_ref = -100 cm` (pF approximately 2.0).

Rationale:
WUR soil-water guidance commonly uses pF 2.0 / approximately -100 cm as a
field-capacity reference for Dutch agricultural soils, while also noting that
field capacity is not represented by one universal pressure head.

Therefore this is a reproducible convention, not a claim that every layer is
physically at field capacity at -100 cm.

Frozen sensitivity state:

`h_sens = -200 cm`.

This is included because WUR guidance notes approximately -200 cm as a
practical field-capacity reference for profiles with low groundwater levels.

The choice of -100 cm is fixed **before** ELAS policy results are inspected.
It may not be changed to obtain preferred ELAS magnitudes.

## Frozen conversion

For every source-bound layer:

`theta(h)` is evaluated from exact Staringreeks 2018 retention parameters.

Then:

`rho_wet(h) = rho_dry + theta(h)`

`waterContent(h)[%] = 100 * theta(h) / rho_dry`.

The frozen ELASTIC11 M1 equation is evaluated unchanged.

## Predictor-domain gate

Use frozen ELASTIC11 calibration normalization:

`z_rho = (rho_wet - 1.4337873737373736) / 0.34422692442216535`

`z_w = (waterContent - 191.8190909090909) / 182.02868188688447`.

Domain classes remain:
- `IN_DOMAIN`: both |z| <= 2;
- `EDGE`: maximum |z| > 2 and <= 3;
- `EXTRAPOLATION`: either |z| > 3.

An automatically generated prior is prohibited for any regime/state with
non-zero EXTRAPOLATION.

## Reference-state robustness gate

For every MINERAL layer define:

`R = Ss(-200 cm) / Ss(-100 cm)`.

The static -100 cm prior is considered locally robust enough to advance only if:

1. at least 95% of MINERAL layers have `0.8 <= R <= 1.25`;
2. all MINERAL layers have `0.67 <= R <= 1.5`;
3. both -100 and -200 cm have zero predictor EXTRAPOLATION.

This gate tests whether a modest, physically defensible change in field-capacity
convention is small relative to the known predictor uncertainty.

No broader -10..-1000 cm criterion is used to select the operational reference.

## Uncertainty policy

The independent ELASTIC11 holdout established typical multiplicative error:

`F = 2.123968031921196`.

For every generated prior persist descriptively:

- `ELAS_prior`;
- `ELAS_lower = ELAS_prior / F`;
- `ELAS_upper = ELAS_prior * F`;
- reference head;
- source profile/layer identity;
- soil regime;
- predictor-domain class.

This factor band is **not** a 95% confidence interval.

It is a transparent operational uncertainty envelope derived from the frozen
independent holdout MAE.

## Regime policy before results

### MINERAL

Eligible for automatic static-prior advancement if all frozen domain and
reference-state robustness gates pass.

### ORGANIC_RICH_NONPEAT

Research-only prior in ELASTIC13.

Even if predictor-domain gates pass, no automatic production policy is
authorized here because transfer from specimen-scale mechanics to high-organic
soil may involve deformation/history effects not represented by a single
linear static coefficient.

### PEAT

Explicitly excluded from automatic static-prior advancement in ELASTIC13.

Prior work already established that peat can show materially stronger,
history-dependent deformation/storage behavior. A single scalar linear ELAS may
be only a first-order approximation.

ELASTIC13 may report the frozen M1 transfer for comparison, but it is
`RESEARCH_ONLY_NOT_AUTO_ASSIGNED`.

### UNKNOWN

No automatic assignment.

## Required result summaries

Report by regime at -100 cm and -200 cm:

- layer count;
- number of distinct BOFEK profiles;
- dry-density range;
- organic-matter range;
- median/p10/p90/min/max ELAS prior;
- predictor-domain fractions;
- fraction below / near / above `1e-6 cm^-1`;
- uncertainty-band range;
- -200/-100 ratio distribution.

Also report:
- count of explicit peat layers;
- distribution of `peattype`;
- count of high-organic non-peat layers;
- exact list of any UNKNOWN layers.

## Advancement classification

If MINERAL passes all frozen gates:

`STATIC_MINERAL_ELAS_POLICY_QUALIFIED_FOR_PRODUCTION_SHAPING`.

If MINERAL fails:

`STATIC_MINERAL_ELAS_POLICY_NOT_QUALIFIED`.

Regardless of MINERAL outcome:

- PEAT remains `RESEARCH_ONLY_NOT_AUTO_ASSIGNED`;
- ORGANIC_RICH_NONPEAT remains `RESEARCH_ONLY_NOT_AUTO_ASSIGNED`;
- UNKNOWN remains `NO_AUTO_ASSIGNMENT`.

## Production boundary

ELASTIC13 changes no production source.

A later production work unit may only materialize the exact qualified policy.

User-supplied explicit ELAS must remain possible.

Default-off behavior must remain preserved until a separate production
activation/admission contract explicitly changes it.
