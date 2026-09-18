# PUB-GC E3 result — coupling-window and groundwater-buffering characterization

## Status

**SUPPORTED_RESTRICTED — E3a matrix passed**

Date: 2026-09-18.

Qualified source head:

`c7ed6ee46527fa592317413c56a277f5ec127335`

Current-canonical baseline at the reconciled preregistration:

`585a8719242bf58e4c37c6283298dfad7b20a0ae`

Successful evidence runs:

- push run `35346520157` — PASS;
- pull-request run `35346683072` — PASS;
- F-GC44 real SWAP + live MODFLOW6 on the same head — PASS;
- F-VQ116 independent F-GC44 qualification — PASS;
- PUB-GC E1/E2 — PASS;
- Documentation — PASS.

The F-GC44 anchor case `DeltaT=1e-4 d, Sy=0.15` reproduced the admitted strong-coupling result.

## Experimental scope

E3a varied:

- finite coupling-window duration: 2.5e-5, 1e-4, 4e-4 and 1.6e-3 day;
- MODFLOW specific yield: 0.02, 0.15 and 0.30;
- coupling treatment:
  - L0 constant predictor flux;
  - L1 frozen affine predictor response;
  - S strong predictor/corrector coupling.

All cases use the same real FMR/SWAP reference-Richards column and one live MODFLOW6 6.8.0 centre cell.

The experiment changes transient groundwater buffering through specific yield while retaining the SWAP physics and groundwater conductivity.

## Short-window lower boundary

All three treatments failed SWAP predictor initialization at:

```text
DeltaT = 2.5e-5 day = 2.16 s
```

with qualification status `103`.

Status 103 is generated when the real predictor trial does not complete. The failure is independent of groundwater specific yield because it occurs before the MODFLOW treatment becomes relevant.

This is a bounded lower-window observation for the current FMR transaction/response configuration, not evidence that hydrological coupling is impossible at shorter physical time scales.

## Strong-coupling result

For every window at which the real SWAP predictor initialized successfully, strong coupling converged.

| window | Sy=0.02 | Sy=0.15 | Sy=0.30 |
| --- | ---: | ---: | ---: |
| 8.64 s | 3 iterations | 2 | 2 |
| 34.56 s | 3 | 3 | 2 |
| 138.24 s | 4 | 3 | 3 |

The final strong-coupling residual remained below the frozen `1e-15 m s-1` criterion in all nine successful cases.

The observed pattern is consistent with increasing coupling work for longer windows and lower groundwater storage, but the matrix is too small and too close to equilibrium to elevate that pattern to a general scaling law.

## Loose coupling versus strong coupling

Constant-flux one-pass coupling did not satisfy the strong-coupling interface criterion in any successful case.

Its diagnostic mismatch ranged from:

```text
11.2 x tolerance
```

at `DeltaT=8.64 s, Sy=0.30`, to:

```text
388.8 x tolerance
```

at `DeltaT=138.24 s, Sy=0.02`.

The mismatch increased with longer windows and, within each window, with lower specific yield.

This demonstrates a numerical/interface-consistency benefit of iteration.

However, the absolute groundwater-head correction remained very small in this near-equilibrium experiment:

```text
max |H_L0 - H_strong| = 1.06e-9 m.
```

The largest integrated one-window exchange difference between constant-flux and strong coupling was:

```text
5.33e-11 m water-equivalent depth
```

for the 138.24 s, Sy=0.02 case.

Therefore E3a does **not** establish that strong coupling produces a hydrologically material state correction in this envelope. It establishes that a loose solution can be materially inconsistent in interface flux while the absolute state effect remains negligible because the case itself is weakly forced.

This distinction is important for the manuscript.

## Frozen affine predictor response

The most important unexpected E3a result is that the frozen initial affine SWAP response did **not** improve one-pass interface consistency.

Across all nine successful cases:

```text
|r_L1| > |r_L0|.
```

The ratio:

```text
|r_L1| / |r_L0|
```

ranged from approximately 1.41 to 1.92.

At the longest window and lowest groundwater storage:

```text
constant-flux mismatch = 3.89e-13 m/s
affine-response mismatch = 7.47e-13 m/s
```

and the frozen affine groundwater exchange even had the opposite sign to the converged strong-coupling exchange in that controlled case.

This is direct evidence against treating the current predictor coefficient `u` as if it were automatically the actual finite-window Dirichlet-to-exchange derivative needed for a one-shot Newton-like correction.

The result does **not** imply that `u` is wrong. It implies that its scientific meaning and relation to:

```text
J_S = d DeltaS / dH

J_R = d V_u / dH
```

must be established before using `u` as an acceleration Jacobian.

That question is now promoted from a theoretical caution to an evidence-driven E4 priority.

## Groundwater buffering

Lower specific yield generally increased:

- one-pass interface mismatch;
- the difference in groundwater exchange relative to the strong solution;
- strong-coupling iteration count.

For example, at the 138.24 s window:

| Sy | constant residual / tolerance | affine residual / tolerance | strong iterations |
| ---: | ---: | ---: | ---: |
| 0.02 | 388.8 | 746.9 | 4 |
| 0.15 | 131.0 | 226.3 | 3 |
| 0.30 | 86.1 | 136.2 | 3 |

This supports using groundwater transient storage as a controlled feedback-strength axis in subsequent experiments.

It does not yet define the formal coupled strength:

```text
C = |(dH/dV_u) J_R|
```

because `J_R` is not yet measured. That belongs to E4.

## Work accounting

Strong coupling required:

- one predictor evaluation;
- 2–4 real SWAP correctors depending on case;
- therefore 3–5 operational full-window SWAP evaluations in E3a.

L0 and L1 each require one operational predictor evaluation. Their diagnostic SWAP corrector in this experiment is evidence overhead and is not counted as algorithmic work.

This confirms that strong coupling has a real component-work cost even in weakly coupled cases. Whether that cost is warranted must therefore be judged against physical error and not only against satisfaction of an arbitrarily strict interface residual.

## Interpretation

E3a supports four restricted conclusions.

1. **Strong coupling closes the interface consistently** across the successful matrix.
2. **Longer windows and lower groundwater storage increase coupling difficulty** in this bounded case.
3. **The current near-equilibrium envelope is hydrologically weak despite non-trivial interface residuals**: head and integrated-transfer corrections are extremely small in absolute terms.
4. **A frozen F-GC30/F-GC44 affine predictor response is not a reliable substitute for coupled correction** and can be worse than constant-flux one-pass coupling.

The fourth conclusion directly strengthens the need for E4 response identity.

## Manuscript consequences

The manuscript should not claim:

> iterative coupling is always hydrologically necessary.

The evidence supports instead:

> iterative coupling provides a rigorously converged interface solution, but whether that additional consistency is hydrologically material is regime-dependent and must be demonstrated.

Likewise the paper should not describe the predictor coefficient `u` as the interface Jacobian before E4.

## Next step

E3a does not yet contain a hydrologically consequential feedback regime.

The next evidence should therefore proceed on two fronts:

1. **E3b envelope expansion:** increase coupling-window duration and/or hydrological forcing until the state/exchange correction becomes scientifically measurable or the current coupling envelope fails;
2. **E4 response identity:** directly measure `u_FD`, `J_S` and `J_R` from the same accepted states.

Because the affine predictor result is already adverse, E4 should begin before any ACCELERATE/IQN experiment.
