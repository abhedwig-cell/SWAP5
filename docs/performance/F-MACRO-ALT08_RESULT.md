# F-MACRO-ALT08 — RFM-1B activation transferability result

Date: 2026-09-30

Status: `QUALIFIED_STANDALONE_RESEARCH_RESULT / ACTIVATION_FORM_CONTINUES`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Purpose

Test the first RFM-1B activation hypothesis without changing the already screened RFM-1A geometry, transfer or exchange concepts.

The question is deliberately narrow:

> Can one fixed structural heterogeneity parameter `sigma_B` produce physically ordered preferential partitioning across both source intensity and different matrix-infiltrability states, without event-specific retuning?

## Activation law

Let local matrix infiltrability be lognormally distributed:

```text
B ~ LogNormal(log(b50), sigma_B)
```

For source intensity `R`:

```text
q_matrix = E[min(R, B)]
q_pref   = R - q_matrix
```

This has a closed-form evaluation and requires no time integration or iterative solve.

## Transferability screen

A single:

```text
sigma_B = 0.65
```

is used for every case.

Rain/source rates:

```text
2, 4, 8, 15, 30, 60
```

Prescribed matrix-infiltrability scales:

```text
b50 = 8, 12, 20
```

These `b50` values are test states only.

This workunit does **not** yet claim a qualified physical mapping from current SWAP matrix hydraulics to `b50`.

## Numerical result

For `b50 = 8`, preferential fractions are approximately:

```text
R=2   -> 0.003
R=4   -> 0.037
R=8   -> 0.182
R=15  -> 0.422
R=30  -> 0.677
R=60  -> 0.836
```

For `b50 = 20`:

```text
R=2   -> 0.00003
R=4   -> 0.0012
R=8   -> 0.018
R=15  -> 0.103
R=30  -> 0.330
R=60  -> 0.604
```

The intermediate `b50=12` case lies monotonically between them.

All screen checks pass:

```text
preferential fraction increases monotonically with source intensity
preferential fraction decreases monotonically with matrix infiltrability scale
same sigma_B used in all cases
```

## Interpretation

This is a stronger result than a fixed bypass fraction.

A fixed surface fraction gives approximately:

```text
q_pref / R = constant
```

unless a separate ponding route activates.

The RFM-1B candidate instead produces a continuous response:

```text
weak source + capable matrix  -> almost no preferential activation
strong source                -> increasing preferential activation
less capable matrix          -> more preferential activation
more capable matrix          -> less preferential activation
```

with no hard source threshold and no event-specific `sigma_B`.

## What this result does not establish

The major unresolved item is `b50`.

RFM-1B is not scientifically closed until the characteristic matrix-infiltrability scale can be tied to accepted SWAP matrix state and soil parameters.

Candidates include quantities derived from:

- top-layer hydraulic conductivity;
- current pressure head/water content;
- sorptivity/capillary contribution;
- event duration or a bounded characteristic infiltration time;
- surface sealing/crust state where represented.

A purely empirical `b50(theta)` fit would weaken the parameter-reduction argument and is not the preferred route.

## Leading parameter contract

The preferred target remains:

```text
sigma_B = structural heterogeneity parameter
b50     = derived state quantity from matrix hydraulics
```

rather than:

```text
sigma_B + b50 = two free event calibration parameters
```

## Falsification criterion for the next step

F-MACRO-ALT09 must derive one or more candidate `b50` formulations from matrix physics and test them across:

- dry and wet initial states;
- low and high source intensities;
- different hydraulic soils;
- multiple pulse durations.

A candidate fails if maintaining plausible activation requires per-event adjustment of `b50` beyond what follows from the matrix state.

## Current RFM status

```text
RFM-1A geometry reduction:
    standalone two-event screen PASS for continued research

RFM-1B activation functional form:
    monotonic transferability screen PASS

RFM-1B physical b50 closure:
    OPEN

RFM-2 transfer reduction:
    NOT YET NEEDED

production admission:
    NOT REQUESTED
```

## Next large block

ALT09 should focus on the physics of `b50`, not add more free parameters.

The most promising route is to construct a characteristic matrix intake capacity from existing SWAP hydraulic relations and a physically explicit short infiltration timescale, then test whether that state-derived scale reproduces the desired activation ordering.
