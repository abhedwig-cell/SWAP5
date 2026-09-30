# F-MACRO-ALT07B — extended RFM-1A two-event result

Date: 2026-09-30

Status: `QUALIFIED_STANDALONE_RESEARCH_RESULT / CONTINUE_RFM1A`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Scope

Extend RFM-1A beyond the single-event geometry-only screen.

The standalone comparison now includes:

- a separate Main Bypass fraction that remains connected through the modeled column;
- terminating IC connectivity represented either as the five-endpoint stepped geometry or the continuous ALT05 function;
- two-event forcing;
- compact two-value Philip-event history;
- explicit matrix exchange;
- hard mass accounting.

Only the terminating-path geometry differs between paired runs.

## Shared model

Both variants use:

```text
MB fraction                  = 0.25
rain intensity               = 30
surface fast fraction        = 0.04
event duration               = 0.08 d
fast release rate            = 60 /d
vertical spacing             = 5 cm
dt                           = 0.0025 d
initial matrix theta         = 0.22
theta_s                      = 0.45
```

The exchange state is the reduced F-MACRO-ALT02B representation:

```text
S_event
age_event
```

No legacy multi-field sorption state is needed in this standalone operator.

## Geometry pair

### Stepped reference representation

Terminating endpoint depths:

```text
85.0, 54.2, 35.6, 26.9, 25.0 cm
```

### Continuous candidate

Bounded connectivity:

```text
Z_AH = 25 cm
Z_IC = 85 cm
R_AH = 0.2
a = 0.31
b = 0.55
```

The MB fraction is added identically to both and survives through the full modeled depth.

## Two-event experiments

The second 0.08 d event starts at:

```text
0.10 d
0.12 d
0.20 d
0.50 d
```

This spans short-gap event interaction through substantially separated events.

## Main numerical case: second event at 0.50 d

Stepped geometry:

```text
total fast input          0.1920000
termination/deposition    0.1208703
bottom flux               0.0201829
matrix exchange           0.0509468
residual storage          0
mass residual             3.1e-16
mean termination depth    43.04 cm
```

Continuous geometry:

```text
total fast input          0.1920000
termination/deposition    0.1218061
bottom flux               0.0192433
matrix exchange           0.0509506
residual storage          0
mass residual             2.5e-16
mean termination depth    42.87 cm
```

Paired differences:

```text
bottom                    -0.000940
matrix exchange           +0.0000038
mean termination depth    -0.174 cm
```

The bottom-flux difference is about 0.49% of total fast input and about 4.7% of the stepped bottom component in this deliberately small synthetic case.

## Short-gap robustness

When the second event starts at 0.10-0.20 d, the continuous geometry remains close to the stepped geometry while event-history is active/recent.

Across the tested short-gap cases:

- exchange differences remain small;
- bottom-flux differences remain below about 0.0007 absolute water units;
- mean termination-depth differences remain within about 0.55 cm;
- all paired mass residuals remain at floating-point scale.

This is important because the geometry reduction is not only matching an isolated pulse.

## Interpretation

The result supports the specific claim:

> A continuous terminating-path connectivity representation can replace the stepped five-endpoint representation in this standalone RFM-1A operator without destabilizing two-event routing, compact Philip-history exchange or mass conservation.

It does **not** establish:

- full SWAP equivalence;
- empirical validity of the chosen continuous function;
- equivalence of current SWAP activation;
- rapid-drainage equivalence;
- tracer equivalence;
- production readiness.

## Important modeling insight

The result also supports retaining a separate MB fraction.

Trying to force all pathways into one terminating connectivity curve would conflate:

- pathways that genuinely remain connected to the lower boundary;
- pathways whose functional role is deposition/termination within the profile.

The reduced model therefore keeps this functional split:

```text
f_MB                  continuous/deep pathways
1 - f_MB              terminating pathways described by C_IC(z)
```

but removes the need for multiple explicit IC subdomains.

## Current reduced parameterization target

The geometry side can now be expressed approximately as:

```text
f_MB
Z_AH
Z_IC
R_AH
a
b
```

with a deliberate goal to derive/fix as many of these as possible from profile information rather than calibrate all six.

Likely candidates:

- `Z_AH`: soil-horizon information;
- `Z_IC`: structural/profile maximum connectivity depth;
- `R_AH`: potentially derive or remove after sensitivity testing;
- `f_MB`, `a`, `b`: effective structural parameters.

## Next high-value block

The next step should be RFM-1B, not further embellishment of RFM-1A.

RFM-1B will replace only surface activation:

```text
legacy surface-area partition
        ->
matrix-infiltrability distribution
```

while keeping the now-stable RFM-1A geometry, transfer and exchange operator fixed.

This gives a clean test of whether the new activation law improves parameter parsimony and event responsiveness without sacrificing the geometry result.
