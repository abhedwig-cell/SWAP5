# F-MACRO-ALT07A — standalone RFM-1A geometry-reduction result

Date: 2026-09-30

Status: `QUALIFIED_STANDALONE_RESEARCH_RESULT`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Purpose

Execute the first actual RFM-1A screen rather than stopping at a conceptual design.

The experiment isolates one change only:

```text
stepped discrete terminating-path geometry
                ->
continuous bounded connectivity survival
```

Forcing and fast-transfer law are identical between both variants.

No activation, exchange, drainage or matrix physics is changed in this screen.

## Reference geometry

The SWAP manual example used in ALT05 contains five terminating endpoint depths:

```text
85.0
54.2
35.6
26.9
25.0 cm
```

representing four IC subdomains plus the Ah subdomain.

The stepped survival is:

```text
C_step(z) = fraction of endpoints deeper than/equal to z
```

## Continuous candidate

The standalone RFM-1A screen uses:

1. an explicit Ah termination fraction `R_AH = 0.2`;
2. a bounded Kumaraswamy survival distribution for the remaining pathways between `Z_AH=25 cm` and `Z_IC=85 cm`.

For normalized depth

```text
x = (z - Z_AH) / (Z_IC - Z_AH)
```

the candidate is:

```text
C_cont(z) = (1 - R_AH) * (1 - x^a)^b
```

inside the bounded interval.

This family was selected for the first executable screen because it:

- is exactly bounded by physical depths;
- has two continuous shape parameters;
- needs no numerical special-function library;
- can represent strongly skewed endpoint distributions.

## Fit result

A deterministic standard-library grid search gives approximately:

```text
a = 0.31
b = 0.55
RMS survival mismatch = 0.072
maximum pointwise survival mismatch = 0.179
```

against the deliberately stepped five-endpoint representation.

This is a stronger compression screen than the earlier unconstrained Weibull sketch because the candidate honors `Z_AH` and `Z_IC` exactly.

## Event-routing screen

A common research-only fast-routing operator was applied to both geometries.

Forcing:

```text
rain intensity          30
surface fast fraction   0.04
pulse duration          0.1 d
total fast input        0.12
```

Common transfer:

```text
linear reservoir release rate = 80 /d
depth spacing                  = 5 cm
dt                             = 0.0025 d
simulation                     = 1 d
```

The routing law is deliberately identical; connectivity only determines what fraction survives to the next depth interval versus terminates/deposits there.

## Numerical result

Stepped geometry:

```text
source                      0.12000000000000006
deposited                   ~0.120000000000000
bottom                      0
residual storage            ~1e-16
mean termination depth      46.50 cm
mass residual               ~1.5e-16
```

Continuous geometry:

```text
source                      0.12000000000000006
deposited                   0.120000000000000
bottom                      0
residual storage            ~1e-17
mean termination depth      45.59 cm
mass residual               ~5.6e-17
```

Difference in mean termination depth:

```text
~ -0.91 cm
```

## Interpretation

This is not a full SWAP equivalence result.

It establishes three narrower points:

1. a continuous bounded connectivity function can encode the broad vertical termination behavior of the stepped example with only two shape parameters plus the explicit Ah fraction;
2. the reduced representation can be used in a strictly mass-conserving event-routing operator;
3. an event-integrated depth metric is much closer than a pointwise comparison to the artificial staircase, which is important because the staircase itself is a discretization rather than observational truth.

The result therefore justifies moving RFM-1A from conceptual status to a controlled standalone model-reduction experiment.

## What is deliberately not claimed

Not tested yet:

- matrix exchange;
- Philip event history;
- wet-wall calculation;
- rapid drainage;
- MB continuous-path branch;
- bottom flux under a continuous MB component;
- tracer transport;
- full SWAP timestep coupling;
- held-out event transferability.

## Parameter-reduction implication

The legacy terminating-path geometry requires an explicit subdomain count and multiple controls for its frequency-distribution shape.

The first continuous candidate can be represented by:

```text
Z_AH        physical horizon depth, preferably known from profile
Z_IC        maximum terminating-path depth
R_AH        explicit Ah termination fraction if needed
a, b        continuous endpoint-distribution shape
```

No `NUMSBDM` is required.

The next reduction test should determine whether `R_AH` also needs to remain free or can be derived from horizon/connectivity information.

## Current leading architecture after the large ALT05..07 block

```text
RFM-1A
    current/reference activation
    continuous terminating-path connectivity
    MB branch retained separately
    compact fast-domain storage
    current/reference exchange semantics
        including two-value Philip event history

RFM-1B
    RFM-1A
    + matrix-infiltrability activation

RFM-2
    only if required:
    simplify fast-transfer law

RFM-3
    transit-time bounded surrogate
```

## Decision

```text
ALT07A_GEOMETRY_REDUCTION_STANDALONE = PASS_FOR_CONTINUED_RESEARCH
PRODUCTION_ADMISSION = NOT_REQUESTED
FULL_SWAPSIM_EQUIVALENCE = NOT_ESTABLISHED
```

## Next large block

Extend the standalone RFM-1A harness with:

1. a separate continuous MB fraction that survives to the configured deep extent;
2. matrix exchange with the two-value Philip-event sufficient state;
3. wet-wall fraction derived from current storage/interface rather than stored independently;
4. multi-event sequences;
5. held-out geometry/forcing tests;
6. diagnostics for bottom flux, deposition profile and timing.

Only after that should RFM-1A be coupled to the full SWAP reference path.
