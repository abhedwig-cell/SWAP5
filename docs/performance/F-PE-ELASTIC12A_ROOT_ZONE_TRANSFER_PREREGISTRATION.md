# F-PE-ELASTIC12A — root-zone transfer semantics and stress-domain audit

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_ROOT_ZONE_TRANSFER

Parents:
- F-PE-ELASTIC11D qualified deep BHR-GT holdout;
- F-PE-ELASTIC11B-A predictor metadata authority;
- F-PE-ELASTIC06C BHR-P descriptor coverage.

## Purpose

Test whether the qualified deep BHR-GT mechanical relation can be translated into
a physically interpretable **root-zone prior envelope** without changing the
meaning of its predictors.

This workunit is target-free with respect to root-zone ELAS. It is a transfer
semantics and sensitivity audit, not a calibration.

## Frozen deep mechanical relation

M5 remains fixed:

`log10(Ssk_cm_inv) =
 -5.213084677584852
 + 1.0383403589566573 * log10(water_content_pct)
 - log10(stress_midpoint_kpa)`.

No coefficient may be refit in F-PE-ELASTIC12A.

## Predictor semantics

### BHR-GT water content

The BHR-GT `waterContent` predictor is geotechnical gravimetric water content
reported in percent and referenced to dry solids.

Represent:

`w = mass_water / mass_dry_solids`.

### SWAP / BHR-P water content

SWAP and the BHR-P hydrophysical corpus use volumetric water content:

`theta = volume_water / bulk_soil_volume`.

These quantities are not interchangeable.

### Permitted bridge

A volumetric water content may be translated to the BHR-GT gravimetric
convention only when a source-bound dry bulk density is available.

With:
- `theta` volumetric water content [cm3/cm3];
- `rho_w` water density [g/cm3];
- `rho_d` dry bulk density [g/cm3];

the permitted deterministic conversion is:

`water_content_pct = 100 * theta * rho_w / rho_d`.

F-PE-ELASTIC12A freezes `rho_w = 0.9982 g/cm3` for numerical sensitivity.

No conversion may use BHR-GT `volumetricMassDensity` as if it were dry bulk
density unless separately source-bound.

## Root-zone source population

Use the already frozen BHR-P/HYDROFIT hydrophysical interval population.

Include only intervals for which:

1. hydrophysical volumetric-water-content observations are source-bound;
2. `dryBulkDensity` is ASSIGNED by the corrected cross-component provenance;
3. begin/end depth identity matches exactly;
4. dry bulk density unit is the source-bound BHR-P/BRO unit already audited;
5. no ambiguous descriptor is averaged or imputed.

Expected clean maximum from the existing audit:
21 intervals.

No Staringreeks MvG parameter is used to manufacture dry bulk density.

## Water-state scenarios

Do not choose one arbitrary SWAP water state.

For every included BHR-P interval evaluate only source-bound volumetric water
contents from its measured hydrophysical curve.

Report at minimum:

- maximum observed theta / wet end;
- source observation nearest -10 cm pressure head/potential where available;
- source observation nearest -100 cm;
- source observation nearest -1000 cm;
- minimum observed theta / dry end.

No interpolation is required in this first audit. Nearest source observations
must retain their original potential.

These scenarios are sensitivity states, not claims that BHR-GT laboratory
specimen water content equals a field equilibrium at the same hydraulic
potential.

## Mechanical stress scenarios

The qualified M5 calibration stress domain is frozen:

`log10(stress_midpoint_kpa) in [1.7871769925, 2.6651446014]`

or approximately:

`61.25 .. 462.6 kPa`.

Root-zone effective stress will frequently be below this domain.

F-PE-ELASTIC12A therefore evaluates fixed declared stress scenarios:

- 5 kPa;
- 10 kPa;
- 20 kPa;
- 50 kPa;
- 100 kPa.

Classification:

- 100 kPa is inside the M5 calibration stress domain;
- 50 kPa and below are stress extrapolation.

No overburden model is fitted here.

## Outputs

For every clean interval x source water state x stress scenario record:

- exact BHR-P identity;
- depth bounds;
- source potential;
- source theta;
- source dry bulk density;
- converted gravimetric water content percent;
- stress scenario;
- whether water predictor lies in the M5 calibration domain;
- whether stress lies in the M5 calibration domain;
- M5-projected `Ssk_cm_inv`;
- ratio relative to Pim Dik's `1e-6 cm^-1`.

Aggregate descriptively by:
- stress scenario;
- depth band;
- organic/mineral indicators only where source-bound;
- fully in-domain versus extrapolative rows.

## Frozen interpretation rules

1. No projected value is a validated root-zone ELAS target.
2. In-domain predictor projection is still **transfer**, not validation, because
   the population changed from BHR-GT geotechnical specimens to BHR-P
   hydrophysical soil intervals.
3. Stress-extrapolative values are reported as sensitivity only.
4. No clipping to `1e-6` or any preferred range is allowed.
5. No coefficient or scenario is selected from SWAP runtime performance.
6. No BOFEK/Staringreeks production mapping follows from this workunit.

## Questions

1. Does the BHR-GT gravimetric water-content calibration domain overlap
   source-bound root-zone BHR-P states after density conversion?
2. How much of the projected Ssk variation is driven by water-state variation
   versus the explicit 1/stress term?
3. Where does Pim Dik's `1e-6 cm^-1` sit within these sensitivity envelopes?
4. Does the root-zone transfer immediately leave the calibrated stress domain,
   indicating that a fixed scalar ELAS requires an explicit reference-stress
   convention?
5. Do organic/low-density intervals produce clearly separate projected regimes?

## Pass / fail meaning

This is not a model-performance gate.

The workunit succeeds if it produces a deterministic, provenance-complete
transfer matrix with no semantic substitution or imputation.

It fails closed if:
- dry bulk density authority cannot be bound;
- hydrophysical theta identity cannot be reconstructed;
- units are ambiguous;
- the intended 21-interval clean population cannot be reproduced.

## Claim boundary

A successful F-PE-ELASTIC12A may establish only:

`qualified deep mechanical relation + explicit water/stress transfer
assumptions -> root-zone sensitivity/prior envelope`.

It may not establish a production ELAS generator.
