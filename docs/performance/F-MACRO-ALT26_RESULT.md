# F-MACRO-ALT26 — one-shape connectivity nested-model result

Date: 2026-10-01

Status: `QUALIFIED_STANDALONE_RESEARCH_RESULT / ONE_SHAPE_CONNECTIVITY_PROMOTED`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Purpose

Test whether the two remaining continuous connectivity shape parameters are both necessary.

Previous leading family:

```text
C(z) = (1-R_AH) * (1 - x^a)^b
```

with `R_AH` already disfavored as a free parameter by ALT25.

ALT26 tests the nested one-shape family:

```text
C(z) = 1 - x^p
x = (z-Z_AH)/(Z_IC-Z_AH)
```

for:

```text
Z_AH < z < Z_IC
```

with exact bounds:

```text
C(Z_AH)=1
C(Z_IC)=0
```

No separate `R_AH`, `a` or `b` is fitted.

## Why this family

It is the simplest bounded monotone survival retaining one structural shape degree of freedom.

Interpretation:

- small `p`: most terminating paths are shallow;
- intermediate `p`: broad depth distribution;
- large `p`: termination distribution concentrated deeper.

The family therefore has a physically interpretable single geometry-shape parameter.

## Nested representational test

ALT22 used three deliberately different two-shape structural examples to demonstrate:

- strong depth sensitivity;
- modest depth sensitivity;
- almost no depth response.

ALT26 treats their depth signatures as synthetic reference regimes, not observations.

The one-shape family is optimized only over `p` for each reference regime.

### Broad depth-sensitive reference

Original example:

```text
a=0.31
b=0.55
R_AH=0.20
```

Best one-shape fit is approximately:

```text
p = 0.66
RMSE ~2.3 cm
```

over the combined mean/max depth signatures at the three activation levels.

This preserves the important intensity/depth-response regime.

### Depth-insensitive reference

Original example:

```text
a=0.10
b=5.0
R_AH=0.20
```

The one-shape family approaches the same shallow/no-depth-response regime as:

```text
p -> very small
```

and the deterministic search reaches effectively zero signature error near its lower range.

Thus a separate second shape parameter is not needed merely to represent the depth-insensitive regime.

### Moderate depth-sensitive reference

Original example:

```text
a=3
b=3
R_AH=0.20
```

Best one-shape fit is approximately:

```text
p = 1.44
RMSE ~2.6 cm
```

over the same six depth signature values.

Again the regime is retained with small loss in synthetic representational accuracy.

## Regime range of p

The one-shape family spans a wide behavior range.

Examples for the same activation sequence:

```text
p ~0.01:
    effectively no depth response

p ~0.10:
    ~1.6 cm max-depth change

p ~0.30:
    ~11 cm max-depth change

p ~0.66:
    ~12 cm max-depth change

p ~1.4:
    ~8 cm max-depth change

p >>1:
    pathways are already deep and incremental deepening becomes small
```

This is important:

a single shape parameter can express both "more pathways without meaningful deepening" and "more activation with substantial deepening".

## Identifiability of the reduced core

The reduced local parameter set is:

```text
sigma_B
f_MB
p
```

Using the same multi-event observable stack as ALT25, at a representative point:

```text
sigma_B = 0.65
f_MB    = 0.25
p       = 0.66
```

the singular values are approximately:

```text
0.761
0.280
0.250
```

with condition number:

```text
~3.0
```

This is very well conditioned relative to:

```text
~375   for the five-parameter form
~7.6   after fixing R_AH but retaining two shape parameters
```

The one-shape reduction therefore improves both parsimony and local distinguishability.

## Parameter correlations

The remaining sensitivities have distinct roles.

At the representative point:

- `sigma_B` controls source activation;
- `f_MB` controls persistent deep receipt;
- `p` controls terminating-path depth structure.

None shows the near-perfect redundancy found for shape-a versus `R_AH`.

This is exactly the kind of role separation desired for robust calibration.

## What is sacrificed

The one-shape family cannot reproduce every arbitrary two-shape survival curve exactly.

The synthetic broad/moderate examples retain residual depth-signature errors of a few centimetres.

That is currently an acceptable research tradeoff because:

- the two-shape family has not been empirically shown necessary;
- observed depth metrics themselves are uncertain/coarse;
- lower parameter dimension materially improves identifiability;
- the one-shape family preserves all qualitative regimes required by current evidence.

If future high-resolution data show systematic lack of fit, the two-shape family remains a documented fallback.

## Updated leading parameter core

The RFM free structural/activation core now becomes:

```text
sigma_B
f_MB
p
```

with:

```text
Z_AH -> derived from horizon/profile data
Z_IC -> observed/derived structural maximum depth
K,S  -> derived from matrix hydraulics
R_AH -> removed from leading family
a,b  -> replaced by single p
```

Wall-exchange controls remain a separate unresolved parameterisation question.

## Original simplification objective

This is a material result.

Before wall-exchange parameters, the entire leading RFM preferential-flow structure can now be described by approximately three genuinely free high-level parameters:

```text
sigma_B : surface intake heterogeneity
f_MB    : persistent deep-path fraction
p       : terminating connectivity shape
```

Each parameter has a distinct observable role.

That is considerably more attractive than an architecture with multiple IC subdomains and partially confounded geometry controls.

## Decision

```text
TWO-SHAPE CONNECTIVITY =
    RETAIN AS FALLBACK ONLY

ONE-SHAPE CONNECTIVITY =
    PROMOTED TO LEADING RESEARCH CANDIDATE

FREE R_AH =
    REMOVE FROM LEADING CANDIDATE

LEADING FREE CORE =
    sigma_B, f_MB, p

LOCAL IDENTIFIABILITY =
    STRONG

EMPIRICAL NECESSITY OF SECOND SHAPE =
    NOT DEMONSTRATED
```

## Next phase

Do not reduce the structural core further by algebra alone.

The next simplification target should be the remaining wall-exchange parameter burden.

Required question:

> Can the retained Philip wall-exchange rate be derived sufficiently from matrix hydraulics and simple geometry so that no additional empirical wall-exchange coefficient is required?

That should be attacked with the same discipline:

1. inventory existing wall-exchange parameters and their physical roles;
2. identify which are scale/geometry quantities already represented elsewhere;
3. test sensitivity/identifiability;
4. retain an empirical parameter only if the observations genuinely require it.

This is now the dominant unresolved parameterisation burden in RFM.
