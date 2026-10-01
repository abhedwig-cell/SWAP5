# F-MACRO-ALT49 — GFZ/Hartmann dye-shape test of the one-shape connectivity observation operator

Date: 2026-10-01

Status: DIRECT_DYE_TO_CONNECTIVITY_OPERATOR_FALSIFIED / RFM_ONE_SHAPE_GEOMETRY_NOT_FALSIFIED

Canonical authority: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

## Purpose

Execute the ALT47 frozen depth-shape route on the user-supplied GFZ/Hartmann dataset:

    2024-001_Hartmann-et-al_Data.zip

The dataset contains 333 trinary vertical flow-path profiles:

    171 calcareous
    162 siliceous

with 1-mm image pixels classified as:

    1 = stone/grass
    2 = unstained soil
    3 = blue stained soil.

## Experimental structure

For the calcareous forefield, treatment varies irrigation intensity at a common applied amount:

    40 mm at 20, 40, 60 mm/h.

For the siliceous forefield, treatment varies applied amount at a common intensity:

    20, 40, 60 mm at 20 mm/h.

The five photographed vertical profiles within each treated subplot provide spatial morphology through the soil.

## First model-free dye metrics

For every trinary profile ALT49 computes:

- total stained fraction of soil pixels;
- stained-pixel depth centroid;
- maximum stained depth;
- centroid normalized by maximum stained depth;
- fraction of stained pixels below half of maximum stained depth.

The data show substantial treatment- and age-specific shape behavior.

Examples of aggregate normalized centroid response:

Calcareous 4900 y:

    20 mm/h -> ~0.400
    40 mm/h -> ~0.479
    60 mm/h -> ~0.459

Calcareous 13500 y:

    20 mm/h -> ~0.340
    40 mm/h -> ~0.417
    60 mm/h -> ~0.437

These are compatible with treatment-dependent deep recruitment.

But other structural classes behave differently.

Calcareous 110 y:

    ~0.434 -> 0.402 -> 0.393

Siliceous 10000 y:

    ~0.363 -> 0.166 -> 0.166

Therefore no universal monotone dye-depth response to intensity/amount is present.

## Frozen direct shape operator tested

ALT47 had allowed dye morphology to inform p but prohibited treating stained area as preferential-water volume.

ALT49 now tests the simplest quantitative morphology operator consistent with that restriction:

    stained_fraction(z)
      = A_profile * C_active_normalized(z)

For the frozen RFM quantile-recruitment law:

    C_struct(x) = 1 - x^p

and:

    C_active = max(0, a - x^p).

After scaling depth by the active maximum depth:

    y = z / z_max_active

the active-survival shape becomes:

    1 - y^p

independent of activation magnitude a.

Therefore, if stained fraction were directly proportional to active pathway occupancy, one structural p should describe the normalized dye-depth shape across treatments at the same plot; each profile is allowed its own nuisance amplitude A.

This is a strong, parameter-economical observation hypothesis.

## Result

The operator fails as a general quantitative mapping.

Across 23 structural plot combinations:

    median shared-p R2 ~ -0.004

Only a minority of plots have a good shared-p fit.

Examples with useful fits include:

    C 110 y middle    R2 ~0.72
    S 30 y middle     R2 ~0.68
    S 30 y right      R2 ~0.59
    S 10000 y plots   R2 ~0.58-0.69

But many plots have R2 near or below zero and push p to the search boundaries.

Allowing a different p for each treatment reduces SSE by more than 10% in:

    9 of 23 plots

and by more than 25% in:

    2 of 23 plots.

The problem is not merely treatment dependence: in many structural plots the basic shape `1-y^p` is already a poor direct representation of stained-area profile morphology.

## Interpretation

ALT49 does NOT falsify:

    RFM C_struct(z) = 1 - x^p

as a hydrological connectivity law.

It falsifies the stronger observation assumption:

    local dye stained fraction
      proportional to
    RFM active-pathway survival.

Dye staining integrates processes not represented by that direct mapping, including:

- path width and merging;
- local matrix exchange;
- incomplete staining;
- excavation/image geometry;
- rocks and disconnected visible stain;
- redistribution after entry.

This is consistent with the earlier ALT20 warning that flow-path morphology is not one-to-one with preferential water flux.

## Consequence for p

The GFZ dye archive is still valuable for:

- maximum-depth response;
- qualitative deep-recruitment patterns;
- morphology-class falsification;
- testing whether simulated endpoint/depth ordering is plausible.

But:

    p must not be calibrated by direct least-squares matching of stained fraction to 1-x^p.

A quantitative p estimate requires either:

1. an independently justified dye observation model;
2. conservative tracer mass by depth;
3. a direct endpoint/path-frequency observable with known relationship to flow occupancy.

## Decision

    GFZ_TRINARY_PAYLOAD = MATERIALIZED
    DIRECT_DYE_DEPTH_METRICS = QUALIFIED
    STAINED_FRACTION_PROPORTIONAL_TO_C_ACTIVE = FALSIFIED_AS_GENERAL_OPERATOR
    p_FROM_DIRECT_DYE_SHAPE_FIT = REJECTED
    RFM_ONE_SHAPE_CONNECTIVITY = NOT FALSIFIED
    DYE_FOR_QUALITATIVE_DEPTH_RESPONSE = RETAINED

## Next

Do not add a new dye conversion parameter.

The useful next GFZ step is the isotope/soil-moisture route, but only for questions that do not require separating the three sequential irrigation endmembers from one post-event isotope value.

The most defensible remaining use is to compare observed multi-depth response timing and maximum/deep response ordering against frozen RFM qualitative predictions.
