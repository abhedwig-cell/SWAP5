# F-MACRO-ALT13 — paired direct surface-activation comparator

Date: 2026-10-01

Status: `QUALIFIED_STANDALONE_RESEARCH_RESULT / PHYSICAL_CONTRAST_ESTABLISHED`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Purpose

Perform the first direct paired comparison between:

1. the current SWAP direct atmospheric macropore-entry concept;
2. the RFM-1B unponded matrix-infiltrability activation.

The paired comparison uses identical:

- top matrix hydraulic state;
- atmospheric forcing;
- event duration.

The ponding route is deliberately excluded because ALT11 retains it as a common head-controlled mechanism in the first RFM comparison.

## Reference direct route

For the direct atmospheric component:

```text
q_pref,legacy = A_mp * P
```

For the official Andelst example, the static surface macropore fraction is:

```text
A_mp,static = 0.04
```

Dynamic shrinkage can increase total surface macropore area, so 0.04 is not a universal full-case value.

For this structural comparator:

```text
A_mp = 0.04
```

is held fixed to isolate the direct activation law.

Thus the legacy direct preferential fraction is:

```text
q_pref / P = 0.04
```

for every unponded source intensity in the comparator.

## RFM-1B route

For the same top state:

```text
K_surface = K(h_i, theta_i)
S_surface = constitutive surface sorptivity
b50(tau)  = K_surface + S_surface/(2 sqrt(tau))
```

with:

```text
B ~ LogNormal(log b50, sigma_B)
sigma_B = 0.65
```

and:

```text
q_matrix = E[min(P,B)]
q_pref   = P - q_matrix
```

No free `b50`, bypass fraction or characteristic infiltration time is used.

## Research profile

The comparator uses the same representative default-MvG research profile as ALT12.

This is not claimed to be the exact Andelst top soil.

Top states:

```text
h = -10, -50, -100, -300, -1000 cm
```

Source rates:

```text
P = 4, 8, 15, 30, 60
```

Durations:

```text
0.1, 0.5, 2.0 h
```

## Core 0.5 h result

### Near-wet top state, h = -10 cm

```text
P=4:
  legacy pref = 0.080
  RFM pref    = 0.0014

P=8:
  legacy pref = 0.160
  RFM pref    = 0.051

P=15:
  legacy pref = 0.300
  RFM pref    = 0.599

P=30:
  legacy pref = 0.600
  RFM pref    = 4.273

P=60:
  legacy pref = 1.200
  RFM pref    = 16.822
```

The RFM preferential fraction therefore moves from effectively zero under weak forcing to more than 50% under strong forcing.

### Moderately dry top state, h = -100 cm

```text
P=4:
  legacy pref = 0.080
  RFM pref    = 0.014

P=8:
  legacy pref = 0.160
  RFM pref    = 0.226

P=15:
  legacy pref = 0.300
  RFM pref    = 1.451

P=30:
  legacy pref = 0.600
  RFM pref    = 6.499

P=60:
  legacy pref = 1.200
  RFM pref    = 19.852
```

### Very dry top state, h = -1000 cm

```text
P=4:
  legacy pref = 0.080
  RFM pref    = 0.0035

P=8:
  legacy pref = 0.160
  RFM pref    = 0.0857

P=15:
  legacy pref = 0.300
  RFM pref    = 0.766

P=30:
  legacy pref = 0.600
  RFM pref    = 4.524

P=60:
  legacy pref = 1.200
  RFM pref    = 16.457
```

## Crossover intensity

For a 0.5 h pulse, the source rate at which integrated RFM preferential fraction equals the fixed 4% legacy direct fraction is approximately:

```text
h =   -10 cm   -> 11.48
h =   -50 cm   ->  6.11
h =  -100 cm   ->  6.97
h =  -300 cm   ->  8.87
h = -1000 cm   ->  9.99
```

This non-monotonic state dependence is caused by the competition between:

- declining point conductivity as soil dries;
- increasing capillary sorptivity as soil dries.

That is an intended physical feature of the RFM hypothesis.

## Onset behavior

Legacy direct entry begins immediately whenever:

```text
P > 0 and A_mp > 0
```

RFM activation may be effectively zero early in a weak event because the transient matrix intake capacity is initially high.

The standalone comparator records the first event age at which preferential fraction exceeds a small diagnostic threshold.

This creates a directly testable prediction:

> Structural macropores can exist at the surface without necessarily accepting appreciable water during every weak input event.

That prediction differs fundamentally from the direct `A_mp P` route.

## Interpretation

ALT13 establishes a clear and falsifiable physical contrast.

### Legacy direct route

```text
structure present -> fixed proportional direct entry
```

### RFM route

```text
structure + source exceeds distributed matrix intake
    -> preferential activation
```

At weak sources, RFM can predict much less preferential input than the current direct route.

At intense sustained sources, RFM can predict far more.

This is exactly why the route requires observational/reference testing rather than equivalence tuning.

## What ALT13 does not establish

It does not show that RFM is more accurate.

It does not use the exact Andelst top-soil state time series.

It does not include:

- dynamic surface crack-area changes in the reference `A_mp`;
- ponding inflow;
- rainfall interruption/reset sensitivity;
- infiltration feedback on top-node state during the same event;
- observed tracer or moisture-arrival data.

Therefore:

```text
PHYSICAL CONTRAST = ESTABLISHED
MODEL SUPERIORITY = NOT CLAIMED
FULL REFERENCE CASE = OPEN
```

## Key falsification consequence

The next experiment should no longer ask whether RFM can mimic the 4% direct fraction.

It should ask which activation behavior is supported by independent evidence.

High-value observables are:

- preferential arrival at depth under weak versus strong rainfall;
- event threshold/gradual onset;
- antecedent moisture response;
- direct tracer breakthrough;
- runoff/ponding transition.

A model that is tuned to reproduce `A_mp P` by construction would defeat the purpose of the alternative hypothesis.

## Decision

```text
ALT13_PAIRED_COMPARATOR = PASS
RFM1B_PHYSICS_DIFFERENCE = LARGE_AND_INTERPRETABLE
EQUIVALENCE_TARGET = REJECTED
EMPIRICAL_FALSIFICATION_TARGET = REQUIRED
```

## Next large block

F-MACRO-ALT14 should build an empirical/synthetic falsification matrix rather than modify the equations again.

Priority cases:

1. weak rain, visible structural macropores;
2. intense short pulse;
3. intense long pulse;
4. dry versus wet antecedent state;
5. ponding transition;
6. tracer/wetting arrival at depth.

Use current SWAP as one comparator, not as physical truth.
