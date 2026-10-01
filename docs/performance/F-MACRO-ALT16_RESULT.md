# F-MACRO-ALT16 — NEON empirical discrimination: acquisition and first external test

Date: 2026-10-01

Status: `PARTIAL_EMPIRICAL_RESULT / AGGREGATE_EXTERNAL_EVIDENCE_RECOVERED / EVENT_CSV_DOWNLOAD_PENDING`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Objective

Use the NEON Soil Preferential Flow Database to test the preregistered RFM falsification rules F1-F4 without changing RFM physics.

## External authority recovered

Li et al. (2025), Geophysical Research Letters, analyzes high-frequency multi-depth NEON soil moisture and precipitation observations across 40 terrestrial sites / 17 ecoregions.

The current published HydroShare resource is:

```text
NEON Soil Preferential Flow Database
HydroShare resource: 847b15cd15524b78acd58a2a8be242c1
published: 2025-09-30
license: CC BY
size: ~1015.6 MB
```

It replaces the 2024 resource.

The public analysis code is:

```text
github.com/libonancaesar/neon-pf-database
```

## Dataset schema verified from source repository

Per site/profile event CSV:

```text
XXXX_PF_database_00Y
```

with Y = 1..5.

Key event fields include:

- storm start/end;
- storm sum;
- storm peak intensity in mm/10 min;
- duration in hours;
- sensor response/onset/peak;
- soil moisture immediately before precipitation;
- NSR flow type;
- NSR flow position;
- computed velocity;
- modeled matrix-flow velocity percentiles;
- VT preferential-flow flag;
- texture/porosity/root/site covariates.

This is sufficient in principle for F1-F4 event-level discrimination.

## Detection implementation verified

The public code shows:

### Precipitation

- resampled to 10 min;
- event termination separation: 6 h;
- maximum event end: 5 days;
- current code has `sum_amount=0` with a comment that 2 mm can be restored.

### Soil moisture

- 10-min processing in the current main script;
- gap interpolation bounded by configuration;
- derivative/Hampel processing;
- onset threshold 0.01;
- event association to precipitation.

### NSR

`nonSequentialFlow` is assigned when at least two sensors respond and a deeper sensor responds before a shallower sensor.

This matches the physical observable needed for preferential arrival ordering.

## Data-acquisition state

The event CSV payload is not stored in the GitHub analysis repository.

The README points to a public Oregon State Box folder and HydroShare hosts the current ~1 GB published resource.

Within the available connector/browser path in this workunit, metadata/schema/code are accessible but direct file payload enumeration/download of the HydroShare/Box event CSVs is not.

Therefore ALT16 does **not** fabricate event-level statistics.

A reusable event preprocessor has been persisted so analysis can begin immediately when the CSV payload is materialized.

## Persisted event preprocessor

`tools/research/macropore_alt16_neon_discrimination.py`

It reads native PF database CSVs and emits:

- storm peak intensity in mm/h;
- storm duration and amount;
- mean antecedent sensor moisture;
- within-profile antecedent moisture CV diagnostic;
- NSR PF flag;
- any-sensor VT PF flag;
- sensor onset-time map;
- intensity-bin PF fractions.

No RFM parameter is fitted by this script.

## First external falsification check from published aggregate evidence

Although event CSV execution is pending, the published analysis already tests several qualitative RFM predictions.

### F2 — intensity response: supported in direction

The NEON analysis identifies rainfall intensity as:

- the most important predictor for the NSR method;
- the third-most important predictor for the VT method.

The partial dependence exhibits a steep increase in PF likelihood between approximately:

```text
5 and 12 mm/h
```

This is independently notable because ALT13's representative RFM crossover from sub-legacy to >4% preferential activation for 0.5 h pulses occurred across roughly:

```text
6.1 to 11.5
```

depending on top hydraulic state.

This numerical overlap is **not validation**, because the RFM crossover is profile-dependent and the NEON result is an aggregate statistical response.

But the external evidence does not falsify the predicted smooth threshold-like intensity response.

### High-intensity plateau — important constraint

NEON reports a plateau in PF occurrence above approximately:

```text
13 mm/h
```

and attributes this plausibly to rainfall exceeding infiltration capacity so that runoff limits further infiltrating supply to PF pathways.

A purely unponded RFM activation formula would continue increasing with source intensity and therefore cannot represent this plateau by itself.

This externally strengthens the ALT11 decision that RFM must preserve an explicit surface-boundary transition:

```text
unponded infiltrability partition
        ->
ponding/runoff/head-controlled regime
```

The ponding/runoff boundary is therefore a required part of RFM physics, not optional implementation detail.

### F4 — mean antecedent wetness: not falsified, but site aggregate differs from some local studies

NEON partial dependence indicates wetter mean antecedent conditions generally increase PF likelihood, although the VT effect is weaker.

The paper also documents that other studies show positive, negative, or absent antecedent-moisture relations.

This is consistent with the RFM decision not to hard-code a universal dry/wet ordering: RFM derives the ordering from the competition between `K_surface` and `S_surface`.

### Antecedent moisture variability — pressure on fixed sigma_B

A more serious finding is that the coefficient of variation of antecedent soil moisture was more important than mean antecedent moisture.

PF likelihood decreased strongly as antecedent soil-moisture CV increased through roughly 30-45%.

Current RFM-1B uses:

```text
one structural sigma_B
+ one representative top hydraulic state
```

and therefore does not explicitly represent event-dependent spatial moisture heterogeneity.

This is the first external evidence that directly pressures the "fixed sigma_B alone is sufficient" assumption.

Current decision:

```text
FIXED_SIGMA_B_FALSIFIED = NOT YET
FIXED_SIGMA_B_SUFFICIENCY = UNDER_EMPIRICAL_PRESSURE
```

The event-level data are required to determine whether moisture heterogeneity can be explained indirectly by profile/state information or whether the infiltrability distribution width itself must become state dependent.

## Important model-development rule

Do **not** immediately make `sigma_B` event dependent to fit the published result.

The preregistered discipline remains:

1. test fixed `sigma_B` on event data;
2. quantify failure by antecedent CV;
3. only then test a mechanistically constrained state-dependent spread if required.

Otherwise the model would gain flexibility before falsification.

## Site-level aggregate context recovered

The public repository contains a paper table for 40 sites with counts of NSR and VT preferential-flow detections.

Examples include:

```text
MLBS: 434 NSR, 913 VT
BLAN: 260 NSR, 889 VT
SERC: 218 NSR, 798 VT
ORNL: 207 NSR, 755 VT
ONAQ:   0 NSR,  29 VT
```

This confirms substantial variation in event response among sites and reinforces the need for profile/site-specific structural parameters rather than one global geometry.

These counts alone are not suitable for RFM calibration.

## ALT16 decision

```text
NEON_DATASET_SUITABILITY = CONFIRMED
EVENT_SCHEMA = CONFIRMED
DETECTION_CODE = CONFIRMED
EVENT_PAYLOAD_DIRECT_ACCESS = BLOCKED_IN_CURRENT TOOL PATH

F2_INTENSITY_SHAPE = EXTERNALLY_SUPPORTED_IN_DIRECTION
HIGH_INTENSITY_PLATEAU = REQUIRES_PONDING/RUNOFF REGIME
F4_MEAN_WETNESS = NOT FALSIFIED
FIXED_SIGMA_B = EMPIRICALLY CHALLENGED BY MOISTURE_VARIABILITY
```

## Next workunit

F-MACRO-ALT17 has two authorized paths.

### Preferred path — payload acquisition

Materialize the public HydroShare/Box PF event CSV payload and run the persisted ALT16 preprocessor.

Then fit/test with strict split:

```text
train/calibration:
    one sigma_B per structural profile/site class

held-out:
    events from same profile across intensity/duration/antecedent states
```

Primary metrics:

- PF/non-PF ranking AUC or rank statistic;
- calibration by intensity bin;
- failure residual versus antecedent moisture CV;
- onset-depth ordering.

### If payload remains inaccessible

Use the controlled Griessfirn intensity experiment next, because its article-level treatment structure is accessible and directly tests F2/F5 without requiring a 1 GB event database.

No new RFM physics is authorized until one of these empirical tests is completed.
