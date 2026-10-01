# F-MACRO-ALT47 — quantitative preferential-flow observable search and qualification

Date: 2026-10-01

Status: QUALIFIED_DATASET/OBSERVATION-OPERATOR RESULT / SIGMA_B QUANTITATIVE OBSERVABLE STILL BLOCKED

Canonical authority: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

## Purpose

Find a quantitative observation that can move RFM-RC1 from:

    event ordering / PF occurrence

to:

    absolute preferential-water amount

without inventing a post-hoc observation model after seeing RFM residuals.

RFM physics and the RC1 parameter contract remain frozen.

## Parameter-specific observability

The search confirms that the required observation is parameter-specific.

### sigma_B

sigma_B controls the magnitude/spread of the distributed surface intake threshold.

It therefore needs a quantity tied to:

    preferential entry / total effective source

or an independently calibrated conservative-tracer equivalent.

Binary PF occurrence, categorical dye class and normalized depth shape cannot identify its absolute magnitude.

### f_MB

f_MB needs a deep/continuous-path receipt:

    bottom/deep conservative tracer,
    rapid/deep drainage,
    or another independently mass-balanced deep fast-flow receipt.

### p

The one-shape connectivity parameter p is naturally informed by normalized depth information:

    dye/tracer depth distribution,
    depth centroid,
    deep fraction,
    maximum/quantile receipt depth.

This can be estimated without requiring absolute preferential-water amount if the profile is normalized by its own preferential receipt.

## Candidate 1 — GFZ Hartmann 2024

Dataset DOI:

    10.5880/GFZ.4.4.2024.001

The public dataset contains:

- controlled irrigation experiments;
- soil-moisture time series at multiple depths;
- stable-water-isotope profiles;
- trinary Brilliant Blue profiles.

The associated 2024 analysis states that the isotope irrigation used three consecutive days with stepwise increasing irrigation intensity and changing delta2H label.

This is excellent for flow-path/depth information but creates an important limitation:

    the final isotope profile integrates sequential labelled events.

A single post-event isotope value cannot uniquely allocate the water between three event-specific source fractions without an additional transport/mixing model.

### Frozen GFZ dye operator

For trinary dye profiles, ALT47 preregisters only shape observables:

    normalized depth centroid
    normalized deep-stained fraction
    maximum stained depth

These may identify/test p.

They are NOT allowed to calibrate sigma_B because stained area is not assumed to be proportional to water volume.

### Preferential Flow Fraction (PFF)

The Hartmann work defines PFF as the fraction of profile depth rows classified into preferential flow classes.

PFF is continuous in [0,1], but remains a morphological occurrence/depth statistic rather than a water-volume partition.

It is therefore suitable for geometry/depth validation, not absolute sigma_B calibration.

## Candidate 2 — HILLSCAPE Maier 2021

Dataset DOI:

    10.5880/fidgeo.2021.011

This is open and contains quantitative water-routing information from controlled sprinkling experiments.

The associated experiment measured:

- overland flow;
- shallow subsurface flow in trenches;
- flow rate;
- EC/tracer mixing;
- soil properties.

This is much closer to a true water receipt than dye morphology.

However, the measured trench SSF is a lateral hillslope outflow after interacting with profile storage, layering and saturation.

It is not a direct observation of:

    vertical surface preferential entry / effective source.

Therefore HILLSCAPE can test deep/external routing and potentially f_MB-like behavior, but it cannot identify sigma_B in isolation without a model for lateral redistribution.

## Candidate 3 — Weiherbach bromide experiments

The Spechtacker and site-33 experiments used by Sternagel et al. provide a particularly valuable combination:

- controlled block rainfall with bromide;
- observed vertical bromide mass profiles;
- measured macropore numbers, diameters and depth distribution;
- known soil hydraulic parameters.

These data are highly suitable for p and f_MB/deep tracer checks.

ALT47 did not locate the original raw numerical experiment profiles in an openly machine-readable repository. The article reports observed profiles, but extracting numbers from figures would violate the no-pseudo-data principle.

Even with raw profiles, the small number of controlled experiments would not by itself test profile-level sigma_B transferability across a broad event set.

## Candidate 4 — dual-infiltration quantitative PF

A published North-China farmland study directly defines:

    preferential-flow infiltration rate = steady infiltration rate - matrix infiltration rate

and compares it with dye-based estimates.

Conceptually this is the closest observation found to the RFM sigma_B target.

Its data availability statement is:

    data available on request.

So it is scientifically promising but not currently an open-data execution route.

## Candidate 5 — NEON PF v1.1

NEON remains valuable for:

- large-sample activation ordering;
- held-out ranking;
- intensity/state stratification;
- transferability tests that do not require absolute PF amount.

ALT46 already establishes that its binary PF labels do not identify sigma_B magnitude.

## Observation-operator decision

ALT47 freezes this rule:

    no morphological or binary proxy may be rescaled post hoc into preferential-water fraction for sigma_B fitting.

A quantitative sigma_B calibration is admitted only if one of these becomes available:

1. direct preferential/matrix infiltration partition;
2. conservative tracer mass partition with independent mass closure;
3. controlled experiment where preferential entry can be separated from later routing;
4. an observation operator calibrated independently of the RFM events used for sigma_B fitting.

## Best currently executable science

GFZ and Weiherbach-type data can advance:

    p
    f_MB / deep routing
    wall/geometry validation

NEON can continue to validate:

    activation ordering

HILLSCAPE can test:

    quantitative external/deep routing behavior.

But none of the currently materialized/open candidates gives a clean event-level sigma_B amount target.

## Recommended empirical campaign

If dedicated experiments are possible, ALT41 remains close to ideal.

For each structural profile:

- controlled unponded application;
- weak and intermediate intensity;
- short and long duration;
- continuous and fragmented pairs;
- direct water balance;
- conservative tracer;
- depth-resolved tracer/water response;
- independent macropore geometry.

The critical added measurement relative to typical dye experiments is:

    direct matrix versus preferential source partition
    or an equivalent conservative mass receipt.

## Decision

    QUANTITATIVE_OBSERVABLE_SEARCH = CLOSED
    GFZ_DYE_AS_SIGMA_AMOUNT = REJECTED
    GFZ_DYE_FOR_p = ADMISSIBLE
    GFZ_ISOTOPE_FOR_EVENT_SIGMA = NOT IDENTIFIABLE WITHOUT EXTRA MODEL
    HILLSCAPE_FOR_f_MB_ROUTING = PROMISING
    WEIHERBACH_FOR_p_AND_DEEP_TRACER = PROMISING_IF_RAW_DATA
    NEON_FOR_ACTIVATION_ORDERING = RETAINED
    DIRECT_SIGMA_B_AMOUNT_TARGET = STILL BLOCKED

## Next

Do not change RFM equations.

Two useful routes remain:

1. acquire/request a direct quantitative PF dataset (North-China DI or original Weiherbach data);
2. materialize GFZ/HILLSCAPE and execute the already frozen p/f_MB observation operators.

The latter can continue immediately without waiting for sigma_B calibration.
