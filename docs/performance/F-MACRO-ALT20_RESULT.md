# F-MACRO-ALT20 — first bounded empirical discrimination from Griessfirn published data

Date: 2026-10-01

Status: `QUALIFIED_EXTERNAL_EMPIRICAL_RESULT / SIMPLE_INTENSITY_PROXY_FALSIFIED`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Purpose

Use the numerical values published in Hartmann et al. (2022) Table A1 to perform a real empirical discrimination while the raw GFZ archive remains inaccessible.

The experiment applies:

```text
40 mm total water
at 20, 40 and 60 mm/h
```

to the same structural plot classes.

## Derived diagnostic

For each moraine/intensity, the published 0-100 cm relative frequencies are grouped into:

```text
PF-associated categories =
    macropore flow with low interaction
  + mixed macropore flow
  + macropore/finger-shaped flow
  + heterogeneous matrix + finger-shaped flow

matrix-associated categories =
    homogeneous matrix flow
  + matrix flow between rocks
```

This grouping is a diagnostic only.

It is **not** interpreted as a measured preferential water-flux fraction.

## Result

Derived PF-associated categorical frequencies are:

```text
             20      40      60 mm/h
110 y       0.34    0.27    0.34
160 y       0.47    0.36    0.47
4900 y      0.61    0.67    0.79
13500 y     0.79    0.75    0.68
```

The core macropore/finger-shaped category alone behaves similarly in the old moraines:

```text
4900 y:     0.56 -> 0.62 -> 0.75
13500 y:    0.71 -> 0.67 -> 0.62
```

## Empirical consequence

The 4.9 ka profile gives the intuitive response expected from simple RFM activation:

```text
higher intensity
-> more preferential/finger occurrence
```

The 13.5 ka profile gives the opposite categorical response.

Therefore this hypothesis is falsified:

```text
"preferential activation amount can be validated by requiring
monotonic increase of categorical PF flow-type frequency with intensity"
```

It cannot.

## Why this does not falsify RFM activation itself

The paper explicitly shows that increasing intensity can change:

- number of paths;
- path width;
- merging of stained regions;
- dye coverage;
- classification between finger-shaped and matrix-like flow.

A larger water flux through fewer/wider connected paths can therefore produce a lower *frequency of a categorical flow type*.

RFM activation predicts a water partition.

Table A1 reports a morphological classification frequency.

Those quantities are related but not identical.

## Important correction to the empirical program

The primary F2/F5 observables must be quantitative:

```text
dye coverage / stained volume versus depth
surface area density / path count
maximum infiltration depth
runoff
deep arrival / response timing
```

Categorical flow type is a secondary descriptor only.

This avoids falsely validating or rejecting a flux model with a morphology label.

## What the published data do establish

### 4900 y

The 0-100 cm categorical pattern becomes progressively more preferential/finger-like from 20 to 60 mm/h.

This is consistent with source-responsive activation.

### 13500 y

Categorical finger/PF occurrence decreases with intensity.

The article reports that broader pathway use and classification shifts can occur, so this does not uniquely imply reduced preferential water flux.

It is nevertheless a strong warning that "more activation = more classified fingers" is not a generally valid observation operator.

### 110 and 160 y

Responses are non-monotonic and the paper reports considerably more surface runoff at the young moraines.

This independently supports the ALT17 surface-boundary requirement.

## RFM consequence

The physical architecture does not need another new process at this point.

What needs refinement is the **observation operator** between model output and dye evidence.

For model-data comparison distinguish:

```text
MODEL:
    preferential water amount
    connectivity/deposition by depth
    bottom receipt

OBSERVATION:
    stained fraction
    path count/SAD
    path width
    categorical flow type
```

Do not equate these directly without an explicit mapping.

## Decision

```text
GFZ_RAW_DOWNLOAD_RETRY = CLOSED

F2_MONOTONIC_EFFECTIVE_SOURCE_HYPOTHESIS =
    NOT FALSIFIED BY 4900-y DATA

F2_AS_CATEGORICAL_PF_FREQUENCY =
    FALSIFIED AS GENERAL OBSERVATION PROXY

SURFACE_BOUNDARY_LIMITATION =
    REINFORCED BY YOUNG-MORAINE RUNOFF

FIXED_STRUCTURAL_GEOMETRY_PER MORAINE =
    STILL TESTABLE / NOT FALSIFIED

RFM_PHYSICS_CHANGE =
    NOT AUTHORIZED
```

## Next step

ALT21 should build a minimal observation operator for dye experiments.

The first version should predict from RFM outputs only:

- normalized deposited/preferential water by depth;
- expected relative activation of connected pathways.

Then compare **rank/order** rather than exact dye percentage.

No new free calibration coefficient should be introduced in the first observation-operator screen.
