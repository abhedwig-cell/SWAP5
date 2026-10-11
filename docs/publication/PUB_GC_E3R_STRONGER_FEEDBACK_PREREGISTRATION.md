# PUB-GC E3-R preregistration — admitted stronger-flux coupling refinement

## Status

**PREREGISTERED AFTER E3-D, BEFORE E3-R EXECUTION**

Date: 2026-09-18.

E3 main result established a low-flux weak physical-feedback control. E3-D then identified larger predictor fluxes that remain valid without changing any SWAP tolerance:

```text
DeltaT=1e-4 day: q <= 3e-5 cm/day demonstrated
DeltaT=1e-3 day: q <= 1e-4 cm/day demonstrated
DeltaT=1e-2 day: q <= 1e-4 cm/day demonstrated
```

E3-R uses only those demonstrated predictor points.

## Motivation

The original F-GC44 MODFLOW fixture used constant-head cells at:

```text
H_ref + 0.002 m
H_ref - 0.002 m
```

Changing aquifer conductivity therefore changed both groundwater responsiveness and background lateral through-flow. The resulting `K` trend is not a clean coupling-strength experiment.

E3-R removes this confounder.

## Groundwater fixture

The centre cell remains the SWAP-coupled API cell.

Both constant-head end cells are set to:

```text
H_ref
```

so the uncoupled reference state has zero lateral head gradient.

All other geometry, storage, MODFLOW6 version and nonlinear tolerances remain as in E3/F-GC44.

The `K` axis can then be interpreted more directly as altering resistance between the coupled cell and its fixed-head surroundings, although formal coupling strength still requires `J_GW J_R` and remains an E4 quantity.

## Prespecified cases

For each window use the original low-flux control and the largest E3-D-demonstrated predictor flux:

```text
DeltaT=1e-4 day:
    q = 1e-6, 3e-5 cm/day

DeltaT=1e-3 day:
    q = 1e-6, 1e-4 cm/day

DeltaT=1e-2 day:
    q = 1e-6, 1e-4 cm/day
```

For every pair:

```text
K = 0.01, 0.1, 1.0, 10.0 m/day
```

Total:

```text
6 window/flux combinations * 4 K values = 24 cases
```

No cases are dropped after observing results.

## Loose and iterative definitions

Exactly as in the main E3 experiment:

### Loose diagnostic

- solve MODFLOW under the fixed predictor affine response;
- evaluate one real SWAP prescribed-head corrector from the immutable accepted origin;
- record the resulting interface mismatch;
- discard the candidate;
- publish nothing.

### Iterative solve

- fresh MODFLOW instance from the same groundwater origin;
- repeated SWAP correctors from the same accepted SWAP origin;
- fixed admitted predictor slope with intercept re-anchoring;
- accept numerically only when MODFLOW reports convergence and

```text
|q_SWAP - q_GW| <= 1e-15 m/s.
```

The final SWAP candidate is discarded after measurement. E3-R publishes no state or mass.

## Recorded metrics

Same E3 metrics:

- loose and iterative heads;
- loose and iterative SWAP/GW fluxes;
- interface residuals;
- outer iteration count;
- `DeltaH = H_iterative-H_loose`;
- `DeltaQ_SWAP`;
- relative loose flux mismatch.

Additional response-facing metrics:

```text
DeltaH_from_origin_loose =
    H_loose - H_ref

DeltaH_from_origin_iterative =
    H_iterative - H_ref
```

These distinguish the total groundwater response from the smaller iterative correction.

## Primary comparisons

For each window and K:

1. low-flux versus largest-admitted-flux groundwater head displacement;
2. low-flux versus largest-admitted-flux loose coupling residual;
3. low-flux versus largest-admitted-flux iterative correction;
4. required outer iterations.

## Interpretation

A stronger physical feedback case requires more than a large relative residual.

Evidence of a materially stronger coupled response would include an increase in absolute groundwater head displacement and a non-negligible difference between loose and iterative accepted interface states.

No post-hoc “important” threshold is introduced in E3-R; continuous values are reported.

If even the largest currently valid predictor points still produce negligible head effects, the next stronger case must come from a different hydrological state/geometry or an expanded component qualification envelope, not from relaxing coupling tolerances.

## Stop rule

E3-R does not use any predictor flux that failed E3-D.

A SWAP predictor/corrector failure is recorded as bounded envelope data. It is never converted to success by changing retry, temporal or mass tolerances.
