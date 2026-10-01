# F-MACRO-EMP02 — direct unponded preferential-entry acquisition result

Date: 2026-10-01

Status: HIGH_VALUE_CANDIDATE_IDENTIFIED / EXECUTION_DATA_NOT_YET_MATERIALIZED / RFM_PHYSICS_FROZEN

Canonical authority:

    integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

Parent authority:

    docs/performance/F-MACRO-EMP01_AUTHORITY.md

## Purpose

Find a quantitative matrix-versus-preferential infiltration observation in the
same boundary class as frozen RFM sigma_B:

    source-controlled rainfall
    rather than
    ponded/head-controlled infiltration.

The observation must quantify preferential water amount, not merely binary PF
occurrence or visible dye morphology.

## Previously strongest quantitative candidates

### Zhang et al. 2019, Geoderma 347, 150-159

DOI:

    10.1016/j.geoderma.2019.03.026

The study uses paired double-ring infiltrometers and partitions total versus
matrix infiltration. It reports:

    preferential cumulative infiltration = about 66-82% of total
    initial PIR/MIR = about 2.6-10.2
    steady PIR/MIR = about 2.3-4.9

However, the method is explicitly based on infiltration under ponding
conditions.

Decision:

    DIRECT_AMOUNT = YES
    SAME_BOUNDARY_AS_sigma_B = NO
    sigma_B_CALIBRATION = REJECTED

### Zhang et al. 2022, Geoderma 428, 116205

Already qualified in EMP01.

It gives replicate-level PFIR/SIR but uses maintained positive head.

Decision remains:

    DIRECT_AMOUNT = YES
    SAME_BOUNDARY_AS_sigma_B = NO

## New high-value candidate: Wen et al. 2026

Citation:

    Wen, Y. et al. (2026)
    Preferential flow reduces overland flow on slopes:
    insights from a field experiment on the Chinese Loess Plateau.
    Journal of Hydrology 671, 135241.
    DOI 10.1016/j.jhydrol.2026.135241

### Why this candidate is materially different

The experiment combines:

    field artificial rainfall
    high-frequency soil-moisture monitoring
    a surface-covering method that suppresses preferential pathways

and explicitly quantifies the contribution of preferential flow to infiltration
and slope runoff.

The published result reports:

    PF occurrence = approximately 18.9-40.0%
    PF contribution to total infiltration = approximately 59.6-78.7%

This is the closest public empirical match found so far to the frozen
source-controlled RFM activation question.

Unlike the double-ring datasets, the water source is artificial rainfall over
a field slope rather than a maintained infiltrometer head.

## Current execution gap

The currently accessible publication text establishes the method and aggregate
PF contribution but is not sufficient to execute a frozen sigma_B fit or
held-out transferability test.

EMP02 still requires, at event/plot level:

1. imposed rainfall intensity and temporal forcing;
2. total applied rainfall;
3. total and matrix-only infiltration, or the exact quantities used to derive
   PF contribution;
4. antecedent water content for the corresponding plot;
5. enough soil hydraulic information to construct an independently justified
   matrix hydraulic state;
6. runoff/ponding timing or a defensible statement that each calibration
   interval remains source-controlled.

The aggregate 59.6-78.7% range may not be back-solved into sigma_B.

## Why runoff/ponding matters

The experiment explicitly studies slope runoff as well as infiltration.

Once surface water ponds or runoff becomes the controlling boundary process,
the frozen unponded RFM sigma_B operator no longer owns the whole source
partition.

Therefore a valid EMP02 execution must either:

    restrict the comparison to source-controlled intervals before ponding/runoff
    ownership changes;

or:

    use a separately frozen coupled surface-boundary owner.

No such interval split may be guessed from aggregate article statistics.

## Relation to NEON

NEON remains much broader and gives strong activation ordering:

    AUC about 0.666 on 34,355 hydraulically valid events

but only binary/categorical PF outcomes.

Wen et al. 2026 has the complementary strength:

    direct quantitative PF contribution under artificial rainfall

but currently lacks a materialized event-level payload in this research branch.

The combination is potentially decisive:

    NEON -> broad transferability/order
    Wen 2026 -> absolute amount under controlled rainfall

if the underlying Wen event/plot data can be obtained.

## Acquisition verdict

    CLEAN_UNPONDED_DIRECT_AMOUNT_DATASET = NOT YET EXECUTABLE
    HIGH_VALUE_NEAR_MATCH = WEN_2026
    AGGREGATE_PF_FRACTION = AVAILABLE
    EVENT_LEVEL_SIGMA_B_FIT = NOT AUTHORIZED YET
    POST_HOC_BACK_CALCULATION_FROM_AGGREGATE = FORBIDDEN
    RFM_PHYSICS_CHANGE = NONE

## Resume condition

Resume EMP02 immediately when the Wen et al. event/plot table or supplementary
data become available with sufficient forcing/state information.

Freeze calibration and held-out plots/events before inspecting sigma_B
residuals.

If the data demonstrate source-controlled intervals, this dataset becomes the
leading candidate for the first quantitative absolute sigma_B qualification.
