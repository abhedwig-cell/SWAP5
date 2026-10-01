# F-MACRO-ALT21 — minimal dye observation operator and fixed-geometry pressure test

Date: 2026-10-01

Status: `QUALIFIED_RESEARCH_RESULT / OBSERVATION_OPERATOR_CLOSED / FIXED_GEOMETRY_UNDER_PRESSURE`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Purpose

Build the first parameter-free observation operator between RFM outputs and the published Griessfirn dye evidence.

No dye percentage is fitted.

No observation coefficient is introduced.

The comparison is rank/direction only.

## Observation operator

Three RFM quantities are exposed.

### 1. Pathway activation fraction

```text
preferential input / total atmospheric input
```

This is the closest model-side quantity to "how much of the event activates the fast domain".

### 2. Deep receipt fraction

For the current fixed-geometry screen:

```text
deep receipt proxy = activation fraction * f_MB
```

This represents the fraction of total event input assigned to continuously connected deep pathways.

### 3. Normalized deposition-depth distribution

The continuous IC survival function is converted to termination probability by depth.

From that we calculate:

```text
mean termination/deposition depth
```

normalized independently of total activated water.

This is the key fixed-geometry diagnostic.

## Critical fixed-geometry prediction

With:

```text
one unchanged f_MB
one unchanged C_IC(z)
```

across 20, 40 and 60 mm/h, activation changes the amount of preferential water but does **not** change the normalized depth distribution of terminating connectivity.

Therefore the leading RFM-1B geometry predicts:

```text
activation amount       increases with intensity
deep receipt amount     increases with intensity
normalized mean
deposition depth        unchanged
```

for the same structural profile.

This is a genuine falsifiable prediction.

## Published Griessfirn constraint

Hartmann et al. report that representative maximum infiltration depth has a statistically significant relationship with irrigation intensity only at the 13.5 ka moraine, where infiltration depth increases with intensity.

At the other age classes, no significant intensity relationship in representative maximum infiltration depth was found.

The same study also shows that categorical flow-type frequency is not a reliable direct proxy for water partition, as established in ALT20.

## Immediate consequence

The 13.5 ka result puts the strongest pressure so far on the simplest fixed-connectivity RFM geometry.

A model in which intensity only scales total activated water through a fixed connectivity distribution cannot, by itself, move the penetration-depth distribution deeper.

In the current standalone operator:

```text
20 -> 40 -> 60 mm/h

activation amount:
    increases

deep MB receipt:
    increases

normalized IC deposition depth:
    invariant
```

while the 13.5 ka experiment reports:

```text
representative infiltration depth:
    increases significantly with intensity
```

## What this means — and what it does not

This does **not** yet falsify the continuous connectivity concept.

It falsifies the stronger/simple implementation assumption:

```text
source intensity affects only total activation,
not which part of the connectivity distribution becomes active
```

There are at least two distinct mechanisms that could explain the observed depth response.

### Hypothesis G1 — activation-weighted connectivity

Stronger events may activate a larger/deeper subset of the existing connectivity distribution.

Then:

```text
structural C(z) remains fixed
effective C_active(z | event) changes
```

without changing structural geometry parameters.

### Hypothesis G2 — state-dependent physical connectivity

Wetting, filling, crack opening/closure or saturation state may physically change effective connectivity during the event.

This is a stronger model change and should not be introduced before G1 is tested.

## Preferred next hypothesis

G1 is much more parsimonious.

The structural connectivity remains:

```text
C_struct(z)
```

but actual event-active connectivity becomes:

```text
C_active(z) = C_struct(z) * A(z | source/state)
```

where the activation selector must be derived from the same event forcing/state and must not add depth-specific calibration parameters.

A simple first candidate is to let progressively larger activation recruit progressively deeper quantiles of the pre-existing connectivity distribution.

This is conceptually different from re-fitting geometry for each event.

## Important constraint from 4.9 ka

At 4.9 ka, categorical finger/PF frequency increases strongly with intensity but representative maximum infiltration depth does not show a significant intensity relation.

Therefore any active-connectivity selector must **not automatically deepen every profile whenever activation increases**.

The mechanism must allow:

```text
more pathways / more stained volume
without necessarily greater maximum depth
```

This makes a single global "depth = function(intensity)" rule unacceptable.

## Young moraines

At 110 and 160 y, runoff and surface limitations dominate enough that direct intensity-to-connectivity inference is unsafe.

These remain primarily a test of the surface-boundary owner, not the deep connectivity selector.

## ALT21 decision

```text
DYE_OBSERVATION_OPERATOR =
    CLOSED FOR RANK-ONLY RESEARCH USE

FIXED_STRUCTURAL_CONNECTIVITY =
    NOT FALSIFIED

FIXED ACTIVE DEPTH DISTRIBUTION =
    UNDER DIRECT EMPIRICAL PRESSURE AT 13.5 ka

EVENT-SPECIFIC GEOMETRY REFIT =
    STILL REJECTED

ACTIVATION-WEIGHTED CONNECTIVITY =
    NEXT PARSIMONIOUS HYPOTHESIS
```

## Persisted harness

`tools/research/macropore_alt21_dye_observation_operator.py`

The harness deliberately demonstrates the fixed-geometry prediction rather than tuning it away.

## Next workunit

F-MACRO-ALT22 should test whether an activation-weighted connectivity selector can produce both published behaviors with the **same structural geometry**:

```text
4.9 ka:
    more activation/path use with intensity
    little/no significant deepening

13.5 ka:
    intensity-dependent deepening
```

The selector is only admissible if it can be expressed from existing activation/state variables and adds no event-specific fitted geometry coefficient.
