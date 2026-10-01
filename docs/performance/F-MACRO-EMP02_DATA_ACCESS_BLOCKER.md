# F-MACRO-EMP02 — Wen 2026 execution-access audit

Date: 2026-10-01

Status: TRUE_DATA_EXECUTION_BLOCKER / HIGH_VALUE_DATASET_IDENTIFIED

## Target

Wen et al. (2026), Journal of Hydrology 671, 135241.

DOI:

    10.1016/j.jhydrol.2026.135241

The paper is the strongest candidate identified in EMP02 because it combines:

    artificial field rainfall
    high-frequency soil-moisture observations
    a surface-covering matrix-flow treatment
    quantitative preferential-flow contribution to infiltration

The aggregate paper result reports preferential-flow contribution of roughly:

    59.6% to 78.7% of total infiltration

across vegetation-restoration treatments.

## Acquisition attempt

Targeted searches were performed for:

    supplementary data
    data availability
    event/plot dataset
    treatment-level tables

The accessible publisher record exposes the article, methods summary and
aggregate quantitative results.

No machine-readable event/plot dataset or supplement containing the required
partition table was located through the available public execution path.

The article is listed on ResearchGate as request-only full text; no independent
public raw-data repository was located in this acquisition pass.

## Why article-level aggregates are insufficient

The aggregate preferential-flow range cannot be inverted to sigma_B.

The frozen RFM activation requires event/interval-specific:

    source intensity
    source duration/event age
    accepted antecedent hydraulic state
    matrix hydraulic capacity
    quantitative preferential fraction

and must stop or transfer ownership when ponding/runoff controls the surface
boundary.

Because the Wen experiment explicitly studies runoff, treatment-average PF
contribution does not establish which intervals remain source-controlled.

Using the aggregate values as direct RFM targets would therefore confound:

    surface activation
    runoff/ponding transition
    treatment/soil differences
    antecedent state

and is rejected.

## Exact minimum payload required

Any one of the following can unblock EMP02:

1. supplementary/table data giving, per experimental plot/treatment:
   rainfall intensity, duration, total infiltration and matrix-only
   infiltration, plus antecedent water content;

2. the underlying raw rainfall/runoff/infiltration time series plus the
   surface-covering controls;

3. author-provided table/data with enough information to reconstruct the same
   quantities.

Independent retention/hydraulic parameters are preferred. If absent, a
separately preregistered hydraulic-sensitivity layer may be used, but it may not
be fitted jointly with sigma_B.

## Decision

    WEN_2026_AS_EMPIRICAL_TARGET = HIGH_VALUE
    DIRECT_QUANTITATIVE_PF_AMOUNT = PUBLISHED_IN_AGGREGATE
    EVENT_PLOT_PAYLOAD = NOT_MATERIALIZED
    AGGREGATE_BACK_CALCULATION_OF_sigma_B = FORBIDDEN
    sigma_B_QUANTITATIVE_EXECUTION = BLOCKED_ON_DATA
    RFM_PHYSICS_CHANGE = NONE
    PRODUCTION_CHANGE = NONE

## Recovery point

    research/f-macro-empirical01-multievent-qualification

Resume with the Wen event/plot data. No model change is needed before then.
