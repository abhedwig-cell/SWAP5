# F-MACRO-ALT22 — activation-weighted connectivity feasibility

Date: 2026-10-01

Status: `QUALIFIED_STANDALONE_RESEARCH_RESULT / PARSIMONIOUS_SELECTOR_FEASIBLE / EMPIRICAL_FIT_NOT_YET_DONE`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Purpose

ALT21 showed a direct weakness of the simplest RFM geometry implementation:

```text
fixed structural connectivity
+ intensity changes only total preferential amount
```

cannot change the normalized active penetration-depth distribution.

Yet the 13.5 ka Griessfirn moraine shows significant intensity-dependent infiltration depth, while the 4.9 ka moraine does not.

ALT22 tests the most parsimonious correction:

> keep structural geometry fixed, but let event activation recruit progressively different quantiles of that pre-existing connectivity distribution.

No event-specific geometry parameter is introduced.

## Structural model

Each profile class owns a fixed terminating-path survival:

```text
C_struct(z)
```

The corresponding endpoint-depth CDF is:

```text
F_end(z) = 1 - C_struct(z)
```

Let the already-computed RFM activation fraction be:

```text
a in [0,1]
```

ALT22 uses a parameter-free shallow-to-deep quantile recruitment rule:

```text
C_active_abs(z | a)
    = max(0, a - F_end(z))
    = max(0, a - [1 - C_struct(z)])
```

Interpretation:

- weak events recruit the shallowest-connected part of the structural pathway population;
- increasing activation progressively recruits pathways with deeper endpoints;
- the structural endpoint distribution itself never changes.

## Why this is parsimonious

The event supplies only:

```text
a
```

which already exists from RFM-1B activation.

The profile supplies only its existing:

```text
C_struct(z)
```

No new event coefficient, depth coefficient or rainfall-specific geometry fit appears.

## Common activation sequence

Using the same ALT12 representative hydraulic state and the Griessfirn design of 40 mm total input:

```text
20 mm/h -> activation ~0.526
40 mm/h -> activation ~0.642
60 mm/h -> activation ~0.699
```

These activation fractions are identical for every structural-shape example in the selector screen.

## Feasibility screen

Three fixed structural connectivity shapes were used deliberately as synthetic examples.

They are **not fitted Griessfirn parameter sets**.

### Broad depth-sensitive structural example

```text
a_shape = 0.31
b_shape = 0.55
```

Approximate maximum active termination depth:

```text
20 mm/h -> 37.4 cm
40 mm/h -> 50.6 cm
60 mm/h -> 58.0 cm
```

Depth shift:

```text
~20.6 cm
```

### Moderate depth-sensitive example

```text
a_shape = 3
b_shape = 3
```

Maximum active termination depth:

```text
20 mm/h -> ~57.5 cm
40 mm/h -> ~62.0 cm
60 mm/h -> ~64.1 cm
```

Depth shift:

```text
~6.6 cm
```

### Depth-insensitive structural example

```text
a_shape = 0.10
b_shape = 5
```

Across the same activation sequence the active termination depth remains essentially at the shallow bound in this screen.

Thus the same activation increase can produce:

- strong deepening;
- modest deepening;
- negligible deepening;

solely through differences in fixed structural connectivity shape.

## Main result

This establishes feasibility of explaining the qualitative Griessfirn contrast without event-specific geometry refitting.

A 4.9 ka-like response:

```text
more pathway use with intensity
little/no significant depth change
```

and a 13.5 ka-like response:

```text
more activation
significant deeper penetration
```

can arise from:

```text
same activation law
same recruitment rule
different fixed structural C_struct(z)
```

## Important scientific boundary

ALT22 does **not** prove that the real 4.9 ka and 13.5 ka profiles have these example structural shapes.

It proves only:

```text
an event-independent structural explanation exists
without introducing event-specific geometry
```

That is sufficient to keep the reduced connectivity route alive.

## New falsifiable hypothesis

The next empirical hypothesis becomes:

> profile-specific structural endpoint distributions control how strongly penetration depth responds to increasing activation.

This is stronger and more useful than:

```text
higher rainfall always causes deeper flow
```

because it predicts different intensity-depth sensitivity among structural soil classes.

## Relationship to MB

ALT22 operates on the terminating IC pathway population.

The separate MB fraction remains a deep/continuous pathway class.

This is intentional:

- MB controls persistent deep continuity;
- IC quantile recruitment controls how far the terminating population is activated during an event.

The two roles should not be collapsed.

## Decision

```text
FIXED STRUCTURAL CONNECTIVITY =
    RETAIN

FIXED EVENT-ACTIVE DEPTH DISTRIBUTION =
    REJECT

ACTIVATION-WEIGHTED CONNECTIVITY =
    FEASIBLE WITHOUT NEW EVENT PARAMETER

EVENT-SPECIFIC GEOMETRY REFIT =
    STILL REJECTED

G1 ACTIVATION-WEIGHTED CONNECTIVITY =
    CONTINUE

G2 PHYSICAL STATE-DEPENDENT STRUCTURAL GEOMETRY =
    NOT YET REQUIRED
```

## Persisted harness

`tools/research/macropore_alt22_activation_weighted_connectivity.py`

## Next step

ALT23 should test whether the quantile-recruitment idea remains mass-conserving and dynamically stable when inserted into the existing RFM-1B event router.

Required paired tests:

- 20/40/60 mm/h with 40 mm total input;
- same structural profile parameters across all three events;
- MB kept separate;
- water and tracer balance;
- deep receipt;
- termination-depth distribution;
- two-event memory case.

Only after this dynamic test should activation-weighted connectivity be considered part of the leading RFM architecture.
