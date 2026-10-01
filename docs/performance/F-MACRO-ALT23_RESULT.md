# F-MACRO-ALT23 — dynamic activation-weighted connectivity result

Date: 2026-10-01

Status: `QUALIFIED_STANDALONE_RESEARCH_RESULT / DYNAMIC_COMPOSITION_PASS`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Purpose

Test whether the ALT22 activation-weighted connectivity selector remains:

- dynamically stable;
- mass conservative;
- tracer conservative;
- transferable across 20/40/60 mm/h forcing;
- compatible with multiple events;

without changing structural geometry between events.

## Shared structural configuration

All experiments use the same:

```text
f_MB        = 0.25
Z_AH        = 25 cm
Z_IC        = 85 cm
R_AH        = 0.2
shape a     = 0.31
shape b     = 0.55
sigma_B     = 0.65
```

No event-specific geometry parameter is allowed.

## Dynamic implementation

Preferential source input is calculated with the existing RFM-1B activation law.

For each input step:

```text
activation fraction a
    ->
ALT22 endpoint quantile recruitment
    ->
fixed IC endpoint reservoir classes
```

The continuous MB fraction is kept separate and routes to the lower boundary.

IC water is assigned to endpoint classes when it enters the fast domain.

This is important:

- later changes in event intensity do not retroactively change a parcel's selected pathway;
- structural connectivity is fixed;
- event activation controls only which pre-existing endpoint classes are recruited.

The router aggregates water by endpoint class rather than allocating a separate object per timestep.

This is both computationally cheaper and closer to the reduced-model objective.

## Conservative tracer

A conservative tracer with input concentration 1 is partitioned identically to water.

Every water transfer therefore has a paired tracer receipt.

No dispersion, reaction or sorption is included in this qualification screen.

## 20 mm/h case

For 40 mm applied water:

```text
preferential source       21.04406
IC termination/deposition 15.78304
MB bottom receipt          5.26015
residual fast storage      0.000866
water balance residual    -8.7e-14
tracer balance residual   -8.7e-14
```

## 40 mm/h case

```text
preferential source       25.67568
IC termination/deposition 19.25676
MB bottom receipt          6.41839
residual fast storage      0.000529
water balance residual    +1.5e-13
tracer balance residual   +1.5e-13
```

## 60 mm/h case

```text
preferential source       28.03888
IC termination/deposition 21.02916
MB bottom receipt          7.00925
residual fast storage      0.000469
water balance residual    +1.9e-14
tracer balance residual   +1.9e-14
```

## Two-event case

The 40 mm total input is split into two 20 mm events with a one-hour separation.

Result:

```text
preferential source       21.40845
IC termination/deposition 16.05634
MB bottom receipt          5.35151
residual fast storage      0.000608
water balance residual    -2.5e-14
tracer balance residual   -2.5e-14
```

The lower preferential total relative to the single 40 mm/h event follows from restarting the surface-event age for the second event.

The capillary matrix-intake term is therefore restored at event restart.

This is expected behavior of the dynamic `b50(tau)` hypothesis.

## Main qualification result

The selector is dynamically composable.

Across all experiments:

```text
same structural geometry
same sigma_B
same routing rules
same tracer rules
```

and balances remain at floating-point scale.

Therefore:

```text
ACTIVATION_WEIGHTED_CONNECTIVITY
    does not require event-specific geometry
    does not break water balance
    does not break conservative tracer balance
    remains well-defined for repeated events
```

## Important physical result

For the fixed Griessfirn-style 40 mm total input series:

```text
20 -> 40 -> 60 mm/h
```

the preferential amount increases:

```text
21.04 -> 25.68 -> 28.04
```

while the endpoint distribution recruited by each incremental parcel changes with the instantaneous activation state.

This means the new operator can alter both:

- amount of preferential water;
- active depth distribution;

without changing structural `C_struct(z)`.

## Interpretation of the two-event result

The two-event case is especially useful.

If a 40 mm event is divided into two events, RFM predicts less total preferential activation because each event gets a renewed early-time sorptivity contribution.

That is a new falsifiable temporal prediction:

> storm fragmentation matters even at equal total water and nominal intensity.

This should later be tested against event data.

## What ALT23 does not establish

It does not yet show:

- quantitative agreement with Griessfirn;
- correct absolute travel time;
- correct wall-exchange magnitude;
- correct ponding/runoff transition;
- correct tracer dispersion;
- production suitability.

The current dynamic router is an explicit research operator.

## Decision

```text
ALT22 QUANTILE RECRUITMENT =
    DYNAMIC PASS

WATER CONSERVATION =
    PASS

CONSERVATIVE TRACER =
    PASS

TWO-EVENT SEMANTICS =
    PASS

EVENT-SPECIFIC GEOMETRY =
    NOT REQUIRED

ACTIVATION-WEIGHTED CONNECTIVITY =
    PROMOTED TO LEADING RFM RESEARCH ARCHITECTURE
```

## Leading RFM architecture after ALT23

```text
surface boundary
    |
    v
matrix-infiltrability activation
    |
    v
activation fraction a
    |
    +--> MB continuous pathways
    |
    +--> fixed structural IC connectivity
            |
            v
        event-active quantile recruitment
            |
            v
        endpoint/deposition routing

fast-domain state
    + compact Philip wall-event memory
```

## Next decision

The architecture is now rich enough.

Do not add further physics before returning to evidence.

The next high-value step is either:

1. quantitatively compare the dynamic endpoint-rank predictions against accessible dye-depth values; or
2. create a source-level SWAP5 research adapter so this RFM option can consume actual accepted hydraulic state without becoming production physics.

The preferred order is empirical comparison first.
