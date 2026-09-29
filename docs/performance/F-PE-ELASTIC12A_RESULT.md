# F-PE-ELASTIC12A — root-zone transfer semantics and sensitivity result

Date: 2026-09-29

Status: TRANSFER_AUDIT_PASSED_DIRECT_ROOT_ZONE_M5_APPLICATION_NOT_QUALIFIED

Qualified workflow:
`F-PE-ELASTIC12A root-zone transfer audit`

Run:
`36536601142`

Job:
`109301969788`

Qualified head:
`4275f7bc102b4855d1ba09b67163225e2a0c5d7f`

Artifact:
`f-pe-elastic12a-rootzone-transfer`

Artifact id:
`11018303280`

Artifact digest:
`sha256:d9a9b49ec23fef845afafe1c37ed65bbaf0b487357d73266b1ec149127d96296`

## Provenance reconstruction

The live BHR-P service was re-read against the frozen HYDROFIT identity authority.

Twice, independently:

- frozen hydrophysical identities: `31/31`;
- official BHR-P objects: `9`;
- clean ASSIGNED dry-bulk-density intervals: `21`;
- clean objects: `7`;
- exact hydrophysical DataArray identity: PASS;
- dryBulkDensity unit: `g/cm3`, PASS;
- hydraulic tuple units:
  - potential: `cm[H2O]`;
  - volumetric water content: `cm3/cm3`;
  - conductivity: `cm/d`;
- transfer rows: `525`.

Scientific postimages from the two independent retrievals were identical:

`F_PE_ELASTIC12A_SCIENTIFIC_POSTIMAGE_DETERMINISM=PASS`.

Complete live dispatch-response bytes remain archived separately as provenance.

## Water-content semantic bridge

The frozen conversion was:

`w_pct = 100 * theta * rho_w / rho_d`

with:
- `rho_w = 0.9982 g/cm3`;
- source-bound `rho_d`;
- source-bound BHR-P volumetric `theta`.

The resulting gravimetric water-content envelope overlaps the BHR-GT M5
calibration domain only partly.

### Wet maximum theta

21 source intervals:

- converted water-content range:
  `17.73 .. 508.74 %`;
- median:
  `30.54 %`;
- 16/21 intervals lie inside the M5 water-predictor domain.

### Nearest -10 cm

- range:
  `15.55 .. 463.94 %`;
- median:
  `28.63 %`;
- 16/21 intervals inside the water-predictor domain.

### Nearest -100 cm

- range:
  `8.52 .. 419.70 %`;
- median:
  `24.09 %`;
- 11/21 inside the water-predictor domain.

### Nearest -1000 cm

- range:
  `1.00 .. 289.25 %`;
- median:
  `16.61 %`;
- 7/21 inside the water-predictor domain.

### Dry minimum theta

- range:
  `0.72 .. 192.27 %`;
- median:
  `10.25 %`;
- 6/21 inside the water-predictor domain.

Thus the water-content semantics can be translated without unit ambiguity, but
the BHR-GT predictor domain does not cover every root-zone hydraulic state.

## Frozen stress sensitivity

M5 was evaluated without refit at the preregistered stress scenarios.

### 5 kPa

Entirely outside the calibrated stress domain.

Projected Ssk:

- min: `8.71e-7 cm^-1`;
- median: `3.55e-5 cm^-1`;
- max: `7.91e-4 cm^-1`.

Median relative to Pim Dik's `1e-6 cm^-1`:
`35.46x`.

### 10 kPa

Entirely outside the calibrated stress domain.

- min: `4.35e-7 cm^-1`;
- median: `1.77e-5 cm^-1`;
- max: `3.96e-4 cm^-1`.

Median relative to `1e-6`:
`17.73x`.

### 20 kPa

Entirely outside the calibrated stress domain.

- min: `2.18e-7 cm^-1`;
- median: `8.87e-6 cm^-1`;
- max: `1.98e-4 cm^-1`.

Median relative to `1e-6`:
`8.87x`.

### 50 kPa

Still below the calibrated M5 stress domain.

- min: `8.71e-8 cm^-1`;
- median: `3.55e-6 cm^-1`;
- max: `7.91e-5 cm^-1`.

Median relative to `1e-6`:
`3.55x`.

### 100 kPa

Inside the calibrated M5 stress range.

- min: `4.35e-8 cm^-1`;
- median: `1.77e-6 cm^-1`;
- max: `3.96e-5 cm^-1`.

56/105 water-state rows are also inside the M5 water-content predictor domain.

Median relative to `1e-6`:
`1.77x`.

## Root-zone mechanical-domain mismatch

The 21 clean transfer intervals are genuinely shallow:

- maximum interval end depth: `0.76 m`;
- median interval midpoint depth: approximately `0.33 m`;
- 14/21 end at or above `0.50 m`;
- 20/21 end at or above `0.75 m`.

Source-bound dry bulk density spans:

`0.176 .. 1.802 g/cm3`.

Using each interval's source wet theta, the highest observed wet bulk density
among the clean population is approximately:

`2.1214 g/cm3`.

As a deliberately conservative within-population overburden scale, applying
that maximum wet bulk density uniformly from the surface to the deepest clean
interval end at 0.76 m gives only about:

`15.8 kPa`

of total vertical overburden.

This is far below the M5 calibration stress minimum:

`61.25 kPa`.

For the actual saturated ELAS-active constitutive branch (`h >= 0`), positive
pore-water pressure cannot raise effective vertical stress above total vertical
stress in the no-external-load root-zone setting.

Therefore the mechanically relevant saturated root-zone stress domain in this
population has **no demonstrated overlap** with the M5 calibration stress
domain.

## Interpretation of Pim Dik's 1e-6 cm^-1

The transfer audit does not falsify `1e-6 cm^-1`.

It does show that its physical interpretation cannot be decided by simply
evaluating the qualified deep BHR-GT relation at a nominal root-zone stress.

At 100 kPa, where M5 is calibrated, the projected median is close in order of
magnitude to Pim's proposal (`1.77e-6 cm^-1`).

At shallow saturated stress scenarios, M5 predicts much larger values because
of its frozen inverse-stress dependence, but these are extrapolations outside
the qualified mechanical stress domain.

Those larger projections are sensitivity results only and are **not**
admissible ELAS recommendations.

## Organic / low-density signal

The clean BHR-P population includes very low-density, high-organic intervals,
including dry bulk densities below `0.25 g/cm3` and organic matter above
`70 %`.

Their translated gravimetric water contents can exceed several hundred percent,
consistent with a physically distinct organic/peat regime.

This reinforces the earlier conclusion that one universal ELAS value is
unlikely to be physically adequate across mineral and organic soils.

No organic-soil ELAS rule is fitted here.

## Decision

F-PE-ELASTIC12A succeeds as a provenance-complete transfer and sensitivity
audit.

Qualified:

- BHR-GT gravimetric-water predictor can be translated from BHR-P volumetric
  water content when source-bound dry bulk density exists;
- the clean Dutch root-zone population is reproducible;
- water-predictor overlap is partial;
- stress-domain overlap for the saturated ELAS-active root zone is not
  demonstrated.

Not qualified:

- direct application of M5 as a root-zone ELAS generator;
- use of 5, 10, 20 or 50 kPa M5 projections as production values;
- BOFEK/Staringreeks ELAS assignment;
- a universal `1e-6 cm^-1` default;
- any performance-tuned physical parameter.

Classification:

`ROOT_ZONE_WATER_BRIDGE_FEASIBLE_STRESS_TRANSFER_NOT_IDENTIFIED`.

## Next safe step

Do not extrapolate M5 further.

The next physical workunit should seek direct low-stress mechanical evidence in
the ELAS-active range.

Priority:

1. search BHR-GT settlement determinations for valid unload/reload or effective-
   stress segments at low stress, prospectively `<= 25 kPa`;
2. if sufficient target rows exist, freeze a low-stress object-level corpus and
   test whether inverse-stress M5 scaling continues toward the root-zone regime;
3. otherwise record a low-stress mechanical-data blocker and keep ELAS as a
   broad soil-dependent prior rather than a deterministic generator.

No SWAP runtime performance may be used as the low-stress target.
