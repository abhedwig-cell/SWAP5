# F-MACRO-ALT50 — GFZ empirical subphase closeout

Date: 2026-10-01

Status: GFZ_SUBPHASE_CLOSED / DYE_DIRECT_p_OPERATOR_REJECTED / DEPTH-TIMING_VALIDATION_RETAINED

Canonical authority: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

## Purpose

Close the GFZ/Hartmann empirical subphase after materializing and evaluating:

- 333 trinary dye profiles;
- multi-depth soil-moisture time series;
- stable-water-isotope profile structure.

No RFM physics is changed in this closeout.

## Dataset authority

The user-supplied GFZ archive corresponds to DOI:

    10.5880/GFZ.4.4.2024.001

and contains:

    soil-moisture response files
    isotope-profile files
    333 trinary dye-image files

for siliceous and calcareous moraine chronosequences.

The soil-moisture plots contain sensors at 10, 30 and 50 cm plus additional 10-cm sensors.

The irrigation experiments were conducted on three consecutive days with irrigation intensity increasing step-wise each day and a different deuterium label each day.

## ALT49 dye result

A direct morphology operator was tested:

    stained_fraction(z)
      = A_profile * [1 - (z / zmax)^p]

with profile-specific amplitude A and one shared structural p per plot.

This is the simplest quantitative mapping between the frozen RFM active-survival shape and visible stained-area depth morphology.

Result across 23 structural plots:

    median shared-p R2 ~ -0.004

Many fits hit the p search bounds.

A treatment-specific p reduces SSE by >10% in 9/23 plots, but the dominant issue is that many stained-depth shapes are not represented well by the basic one-shape survival curve even before treatment invariance is considered.

Therefore:

    stained fraction proportional to active-pathway survival = REJECTED as a general observation operator.

This does not falsify RFM C_struct(z)=1-x^p because visible dye morphology integrates path widening, merging, exchange, rocks, excavation geometry and post-entry redistribution.

## Model-free dye information retained

The trinary archive still gives reliable descriptive depth observables:

    stained fraction
    stained-depth centroid
    maximum stained depth
    deep-stained fraction

Some moraine classes show deeper normalized morphology with increased treatment.

Examples:

    C 4900 y:
        normalized centroid ~0.400 -> 0.479 -> 0.459

    C 13500 y:
        ~0.340 -> 0.417 -> 0.437

Other classes do not show that ordering.

Examples:

    C 110 y:
        ~0.434 -> 0.402 -> 0.393

    S 10000 y:
        ~0.363 -> 0.166 -> 0.166

Thus treatment-dependent active-depth response is real but not universal.

## Soil-moisture response evidence

The associated experiment analysis defines event response time as the delay until soil moisture increases by more than 0.04 cm3/cm3.

Five event signatures are used:

    response time
    relative peak timing
    available peak storage
    relative maximum storage increase
    relative event storage increase

The published analysis shows that response timing differs systematically by geology, age and depth and that some apparent rapid/deep response is accompanied by steady-state drainage or lateral water input.

This makes the raw 10/30/50-cm response timing a valuable qualitative routing observable.

It is not a clean one-parameter p calibration target because:

- the three experiments at each plot are sequential;
- intensity and isotopic endmember both change by day;
- antecedent state changes between days;
- lateral redistribution occurs in parts of the dataset;
- response timing combines conductivity, storage, routing and connectivity.

## Isotope-profile evidence

The post-irrigation isotope profiles integrate three consecutive irrigation days with different isotope labels.

A single delta2H value at a given depth cannot independently solve the contribution of all three event endmembers plus background water without an additional transport/mixing model.

The published HYDRUS-1D comparison itself finds profile underprediction at several moraine/plot combinations and interprets those deviations as evidence of preferential water transport.

That is useful independent evidence that one-dimensional matrix transport is insufficient in part of the dataset.

However:

    isotope residual -> sigma_B
    isotope residual -> p

is not identifiable without a frozen transport observation model.

ALT50 therefore does not introduce one.

## Final GFZ verdict

    GFZ raw payload = MATERIALIZED
    dye depth metrics = QUALIFIED
    direct dye-to-p quantitative mapping = REJECTED
    one-shape RFM connectivity itself = NOT FALSIFIED
    soil-moisture depth/timing evidence = RETAINED FOR QUALITATIVE VALIDATION
    isotope evidence = RETAINED FOR MATRIX-FLOW FALSIFICATION / ROUTING CHECKS
    sigma_B calibration from GFZ = NOT IDENTIFIABLE
    p calibration from direct stained-shape fit = NOT AUTHORIZED

## Consequence for RFM-RC1

The empirical evidence increasingly supports a separation between:

1. activation / event ordering;
2. structural depth routing;
3. the observation process.

NEON supports activation ordering.

HILLSCAPE provides a quantitative downstream fast-water receipt.

GFZ shows that visible flow-path morphology cannot be mapped to RFM connectivity through a naive proportional-staining operator.

Therefore no additional RFM parameter should be added to repair the dye mismatch.

## Resume condition

Use GFZ again only if a separately justified observation/transport model is available.

Otherwise preserve GFZ as qualitative depth/timing validation and continue quantitative parameter work only with observables that carry a direct conservative water/tracer mass meaning.
