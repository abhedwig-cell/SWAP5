# PUB-GC E3 initial result — controlled coupling-window and feedback matrix

## Status

**PREREGISTERED 48-CASE MATRIX COMPLETED — INFORMATIVE PARTIAL RESULT**

Date: 2026-09-18.

Source branch:

`work/pub-gc-e3-coupling-window-feedback-characterization`

Primary successful workflow run:

`PUB-GC E3 coupling feedback matrix` push run `35343426404`.

The matrix and interpretation rules were frozen in `PUB_GC_E3_PREREGISTRATION.md` before execution.

## Matrix outcome

All 48 prespecified cases produced structured records and the F-GC44/E1 control reproduced exactly inside the configured qualification route.

Status counts:

| status | count |
| --- | ---: |
| `CONVERGED` | 12 |
| `SWAP_PREDICTOR_UNAVAILABLE` | 36 |

All 12 converged cases are the original low-flux row:

```text
q_predictor = 1e-6 cm/day
```

across all three window lengths and all four MODFLOW conductivity values.

Every case at:

```text
q_predictor >= 1e-3 cm/day
```

failed before the MODFLOW feedback experiment began, during construction of the real SWAP predictor response. This failure is independent of MODFLOW `K` because it occurs before the groundwater model participates.

This supports the E3 null hypothesis H0-B in its broad form: the present experiment reaches a component/predictor envelope before it reaches a high-flux outer-coupling regime. The exact internal predictor failure stage still requires diagnostic resolution and is not inferred from the generic return code.

## Control reproduction

The preregistered control

```text
DeltaT = 1e-4 day
q_predictor = 1e-6 cm/day
K = 1.0 m/day
```

reproduced:

```text
H* =
  -0.7149999677331765 m

q_SWAP* =
  -1.2708557527755854e-13 m/s

r* =
   2.3219927791065243e-19 m/s
```

matching the E1/F-GC44 result.

## Converged low-flux regime

| window (day) | K (m/day) | loose relative mismatch | loose residual (m/s) | iterative head correction (m) | iterative q correction (m/s) | outer iterations | final residual (m/s) |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0.0001 | 0.01 | 7.543877e-2 | -8.918815e-15 | -1.998401e-15 | 0.000000e+0 | 2 | 7.970206e-21 |
| 0.0001 | 0.1 | 8.847891e-2 | -1.053185e-14 | -3.774758e-15 | 0.000000e+0 | 2 | 1.503760e-20 |
| 0.0001 | 1 | 2.096103e-1 | -2.663845e-14 | -5.895284e-14 | 0.000000e+0 | 2 | 2.321993e-19 |
| 0.0001 | 10 | 8.979753e-1 | -1.854032e-13 | -8.975709e-12 | 3.546546e-17 | 2 | 7.081681e-17 |
| 0.001 | 0.01 | 3.684270e-1 | -4.610879e-14 | -2.041634e-11 | 6.347803e-17 | 3 | 9.576432e-21 |
| 0.001 | 0.1 | 4.473004e-1 | -5.882345e-14 | -2.600820e-11 | 8.085096e-17 | 3 | 7.157673e-20 |
| 0.001 | 1 | 9.483916e-1 | -1.841502e-13 | -8.062706e-11 | 2.506226e-16 | 3 | 1.133613e-18 |
| 0.001 | 10 | 1.724597e+0 | -1.278665e-12 | -5.425480e-10 | 1.686742e-15 | 4 | 3.398164e-19 |
| 0.01 | 0.01 | 5.364819e-1 | -6.441684e-14 | -2.866721e-10 | 3.949259e-16 | 3 | 1.645772e-19 |
| 0.01 | 0.1 | 8.128454e-1 | -1.203215e-13 | -5.287326e-10 | 7.283988e-16 | 3 | 1.061493e-18 |
| 0.01 | 1 | 1.551687e+0 | -6.082266e-13 | -2.572808e-9 | 3.544374e-15 | 4 | 9.165455e-20 |
| 0.01 | 10 | 1.766532e+0 | -2.803424e-12 | -5.549887e-9 | 1.924234e-14 | 5 | 4.597133e-21 |

Three patterns are visible inside this restricted row.

### 1. Loose interface closure degrades with longer windows

At `K = 1 m/day`, the loose relative flux mismatch increases from approximately:

```text
0.210  at 1e-4 day
0.948  at 1e-3 day
1.552  at 1e-2 day
```

The absolute loose residual at `1e-2 day, K=10 m/day` reaches:

```text
-2.8034238983696472e-12 m/s
```

which is about 2800 times the fixed `1e-15 m/s` coupling acceptance tolerance.

### 2. Iteration restores interface closure

All 12 valid cases converged under the existing coupling algorithm.

Required outer iterations ranged from 2 to 5:

```text
1e-4 day: 2,2,2,2
1e-3 day: 3,3,3,4
1e-2 day: 3,3,4,5
```

for `K = 0.01, 0.1, 1, 10 m/day`, respectively.

Accepted final residuals remained far below the coupling tolerance.

### 3. Physical head corrections remain extremely small

The largest difference between the loose MODFLOW head and the iteratively coupled head was:

```text
|DeltaH|max =
  5.549886994415942e-9 m
```

or approximately 5.55 nanometres.

The largest corresponding change in SWAP interface rate was:

```text
|Delta q_SWAP|max =
  1.924233663354988e-14 m/s.
```

Therefore the current low-flux regime presents a useful distinction:

> a loose solution can violate the strict interface-flux convergence condition by a large relative factor while still differing only minutely in groundwater head from the converged solution.

The scale of the largest absolute loose residual makes this distinction concrete. At the `1e-2 day`, `K=10 m/day` case,

```text
|r_loose| = 2.8034239e-12 m/s
DeltaT    = 864 s
```

so the unclosed interface amount over the whole window is only approximately

```text
2.42e-9 m water depth
```

or `2.42e-6 L` over the one-square-metre fixture. The fixed `1e-15 m/s` criterion is therefore a deliberately strict qualification criterion in this regime, not evidence that every violation of it is hydrologically material.

This does not prove that iterative coupling is hydrologically unimportant in general. It shows that the current F-GC44 low-flux regime is not a suitable positive demonstration of a large physical feedback effect, and that later operational coupling criteria must be interpreted against state and mass impact rather than iteration count alone.

## Important caution about the K trend

Within the low-flux fixture, larger MODFLOW `K` is associated with larger loose relative mismatch and more outer iterations at the longer windows.

This should **not** yet be interpreted as a general statement that larger aquifer conductivity means stronger SWAP–groundwater coupling.

The E3 control parameters change the complete groundwater response operator, and the actual coupled strength is governed by the product of groundwater and SWAP interface responses. E4 is required to evaluate that derivative structure directly.

## Predictor-envelope blocker

The original E3 matrix intentionally increased predictor flux by factors of 1000 and above.

All such cases fail in SWAP predictor construction:

```text
1e-3 cm/day  -> unavailable
1e-2 cm/day  -> unavailable
1e-1 cm/day  -> unavailable
```

for every tested window and every MODFLOW `K`.

Because this happens before MODFLOW is used, these 36 cases cannot be used to judge the outer coupling algorithm.

The immediate next step is therefore a **diagnostic predictor-envelope refinement**, explicitly marked as post-E3 follow-up rather than retroactively added to the preregistered matrix:

1. expose the exact qualification-stage failure code from the test bridge;
2. scan geometrically between `1e-6` and `1e-3 cm/day`;
3. determine whether the blocker is the real SWAP transaction, accepted-trajectory tangent construction, bottom-face mapping, or response assembly;
4. do not relax tolerances or silently expand production admission.

## Scientific interpretation

E3 currently supports two statements.

First, finite-window iterative coupling demonstrably improves **interface consistency** even in the very weak F-GC44 physical regime, and the required iteration count grows with the tested window/conductivity combinations.

Second, that regime is physically too weak to demonstrate an important groundwater-head correction. A stronger publishable coupling case must therefore come from a legitimately admitted hydrological state/forcing envelope, not from artificially loosening convergence or extrapolating the current predictor outside its qualified range.

This is a useful narrowing of the manuscript: RQ3 now has a validated weak-feedback control, but still needs an admitted non-trivial feedback case.

## Authority result

Every E3 diagnostic case retained:

```text
SWAP revision = 0
SWAP committed time = 0
ledger count = 0
ledger exchange = 0
```

before and after the loose and iterative calculations.

The characterization therefore did not create model history or authoritative interface mass.

## Decision

**E3 main matrix: completed, scientifically partial.**

- weak/low-flux control regime: characterized;
- outer iteration: effective for interface closure;
- large physical feedback: not demonstrated;
- higher-flux regime: blocked at SWAP predictor before groundwater coupling;
- next action: diagnose and map the predictor envelope, then select the next admitted non-trivial coupling regime without changing scientific tolerances.
