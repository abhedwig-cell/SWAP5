# F-MACRO-ALT25 — structural parameter identifiability screen

Date: 2026-10-01

Status: `QUALIFIED_STANDALONE_RESEARCH_RESULT / R_AH_FREE_PARAMETER_NOT_SUPPORTED`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Purpose

Test whether the remaining leading RFM parameters are distinguishable from the model observables that the evidence program can realistically provide.

Parameters screened:

```text
sigma_B
f_MB
shape_a
shape_b
R_AH
```

This is a structural/local identifiability test around the current research point.

It is not an empirical calibration.

## Event design

The sensitivity matrix combines six forcing cases spanning weak through intense input:

```text
R=4,  total=2
R=8,  total=4
R=15, total=7.5
R=20, total=40
R=40, total=40
R=60, total=40
```

For every event the stacked observables are:

```text
preferential fraction
deep/MB receipt fraction
mean active IC endpoint depth
maximum active IC endpoint depth
```

Depth observables are normalized before the identifiability analysis.

## Method

Each parameter is perturbed symmetrically by 1%.

The finite difference is taken with respect to log(parameter), so the sensitivity columns compare relative parameter perturbations.

The stacked sensitivity matrix is then evaluated through:

- column norm;
- pairwise sensitivity correlation;
- singular values;
- condition number.

The persisted harness is standard-library only.

## Main result — shape_a and R_AH are practically redundant

The sensitivity correlation is approximately:

```text
corr(shape_a, R_AH) = -0.9995
```

around the current research point.

This is near-perfect compensation.

Both parameters can alter the shallow/deep distribution of the terminating-path survival curve in almost indistinguishable ways for the current observable set.

Therefore the current five-parameter structural set is over-parameterized for the available evidence.

## Conditioning

With all five parameters free, the singular values are approximately:

```text
1.218
0.281
0.269
0.168
0.00325
```

giving condition number:

```text
~375
```

The very small fifth singular value corresponds to the near-degenerate structural direction.

When `R_AH` is fixed/derived and only:

```text
sigma_B
f_MB
shape_a
shape_b
```

remain, the singular values become approximately:

```text
1.218
0.278
0.245
0.160
```

with condition number:

```text
~7.6
```

That is a major improvement.

## Parameter-role separation

The screen also supports useful role separation.

### sigma_B

Primarily controls event/source activation and therefore preferential amount across forcing intensity.

It is not strongly confounded with `f_MB`.

### f_MB

Primarily controls how activated fast water is allocated to persistent deep receipt rather than terminating IC pathways.

This gives it an observable role distinct from activation.

### shape_b

Has the strongest depth-distribution sensitivity in the current parameterization.

It is clearly observable in principle if multiple depth/path observables are available.

### shape_a

Carries depth-shape information but is almost perfectly exchangeable with `R_AH` in the current formulation.

### R_AH

Does not currently earn an independent calibration role.

Keeping both `shape_a` and free `R_AH` would add parameter freedom with almost no new observable information.

## Decision on R_AH

The leading reduced parameterization should **not** treat `R_AH` as a freely calibrated parameter unless future orthogonal evidence demonstrates independent sensitivity.

Preferred alternatives, in order:

1. derive `R_AH` from explicit A-horizon/profile structure;
2. fix it through a structural convention;
3. absorb its role into the continuous connectivity shape and remove it.

The third option is attractive if a simpler bounded survival family can represent the required geometry without a separate surface atom.

## Updated candidate free parameter set

The current leading RFM parameter set becomes approximately:

```text
sigma_B
f_MB
shape_a
shape_b
```

with:

```text
Z_AH   derived from horizons
Z_IC   derived/observed maximum structural depth
R_AH   derived/fixed/removed
K,S    derived from hydraulic state
```

This is a materially stronger simplification claim than ALT24 because one previously open geometry parameter has now failed the identifiability test.

## Important limitation

The result is local and synthetic.

A parameter can appear distinguishable in a local sensitivity matrix yet remain poorly estimable under noisy real observations.

Conversely, new orthogonal measurements could separate currently confounded parameters.

Therefore the correct claim is:

```text
FREE R_AH IS NOT SUPPORTED BY THE CURRENT OBSERVATION SET
```

not:

```text
R_AH HAS NO PHYSICAL MEANING
```

## Original simplification objective

ALT25 improves the answer to the original parameterization question.

The likely genuinely free RFM structural parameters are now reduced toward:

```text
1 activation parameter:
    sigma_B

1 persistent deep-path parameter:
    f_MB

2 continuous connectivity-shape parameters:
    shape_a
    shape_b
```

plus wall-exchange controls not yet reduced.

This is a compact and interpretable core.

## Next workunit

ALT26 should test whether `shape_a` and `shape_b` themselves both remain necessary.

Do this by comparing nested connectivity families:

```text
2-shape-parameter bounded survival
vs
1-shape-parameter constrained survival
```

against the same multi-event/depth observable design.

Admission criterion for a one-shape family:

- no material loss of representable depth-response regimes;
- no degradation of mass/tracer semantics;
- improved identifiability;
- still capable of reproducing both depth-sensitive and depth-insensitive structural classes.

If one shape parameter is sufficient, the RFM core would fall to roughly three genuinely free structural/activation parameters before wall-exchange calibration.
