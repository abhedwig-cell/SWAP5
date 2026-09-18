# PUB-GC E3 preregistration — coupling-window and controlled-feedback experiment

## Status

**PREREGISTERED BEFORE E3 EXECUTION**

Date: 2026-09-18.

Canonical baseline:

`integration/f-ci-canonical@06e585cc16710da00267deed878567ca1936fe7e`

Publication line: PUB-GC / COUPLE.

E1 and E2 are already closed as `SUPPORTED_RESTRICTED`. E3 asks a different question:

> When does loose one-pass coupling cease to approximate the same coupled hydrological evolution as a converged implicit exchange when the coupling-window duration and groundwater feedback strength are controlled independently?

This workunit changes no production hydrology and no production coupling semantics. The real SWAP/FMR participant is reused. Groundwater is represented by a deliberately transparent one-cell response operator so feedback can be prescribed rather than inferred from a particular MODFLOW discretization.

## 1. Why a controlled groundwater cell

Live MODFLOW6 interoperability, prepared-solve semantics and exactly-once publication were already demonstrated in E1/E2.

Using MODFLOW6 itself to create the first feedback-regime map would mix several effects:

- storage;
- lateral conductance;
- discretization geometry;
- solver tolerances;
- API package realization;
- SWAP response.

E3 therefore uses a scalar groundwater storage-response operator as an experimental control. It is **not** presented as a replacement groundwater model or as hydrological novelty.

A later realistic experiment returns to live MODFLOW6.

## 2. Real SWAP component

Every SWAP trial:

- uses the real FMR serialized-reference Richards route already used by F-GC44;
- starts from the current accepted SWAP checkpoint for that coupling window;
- uses prescribed groundwater head at the SWAP lower boundary;
- returns the accepted whole-window mean outward interface flux `q_swap`;
- is discarded unless selected as the accepted coupling solution;
- advances persistent SWAP state only through the existing participant commit.

No rejected trial may mutate accepted SWAP state.

## 3. Controlled groundwater response

For coupling window `n`:

```text
H_(n+1)
  = H_n
  + DeltaH_ext,n
  + beta * DeltaT_s * (q_swap(H_(n+1)) - q_ref)
```

where:

- `H_n` is the accepted groundwater head at the start of the window;
- `DeltaH_ext,n` is a prescribed external groundwater tendency;
- `q_swap` is positive outward from SWAP and therefore into the groundwater cell;
- `q_ref` is the real SWAP whole-window flux at the initial reference head;
- `beta` is the controlled feedback multiplier;
- `DeltaT_s` is the coupling-window duration in seconds.

The corresponding groundwater response to interface flux is:

```text
dH / dq_swap = beta * DeltaT_s
```

This resembles a storage-only one-cell response but `beta` is treated strictly as an experimental feedback control, not as an inferred field-scale specific yield.

## 4. Predictor-normalized feedback classes

E1 measured at the canonical F-GC44 window:

```text
u_base = 3.402936037279093e-5
```

For the F-GC30 predictor linearization:

```text
J_pred = u / DeltaT_s
```

E3 defines four target feedback classes:

```text
C* = beta * u_base
```

with:

| class | C* |
| --- | ---: |
| weak | 0.05 |
| moderate | 0.30 |
| strong | 0.80 |
| supercritical-control | 1.20 |

Thus:

```text
beta = C* / u_base
```

The word `supercritical` refers only to this **predictor-normalized control parameter**. It does not claim that the true coupled Jacobian spectral radius exceeds one. E4 must determine the actual finite-window response `J_R`.

For every window duration E3 will also report:

```text
C_pred(window) = abs(beta * u(window))
```

so any window dependence of the predictor response is visible rather than suppressed.

## 5. Fixed simulation horizon and window matrix

All cases represent the same total simulated horizon:

```text
T_total = 4.0e-4 day = 34.56 s
```

The total prescribed external groundwater tendency is:

```text
DeltaH_ext,total = +0.002 m
```

distributed linearly over the coupling windows.

The coupling-window matrix is:

| windows over T_total | DeltaT_day | DeltaT_s |
| ---: | ---: | ---: |
| 16 | 2.5e-5 | 2.16 |
| 8 | 5.0e-5 | 4.32 |
| 4 | 1.0e-4 | 8.64 |
| 2 | 2.0e-4 | 17.28 |
| 1 | 4.0e-4 | 34.56 |

The 16-window converged solution is the E3 short-window reference for each feedback class.

No adaptive subdivision is allowed inside a matrix case. A failure is recorded as a failure, not repaired by silently changing its coupling window.

## 6. Coupling methods

### 6.1 LOOSE — sequential one-pass exchange

At each window:

```text
H_(n+1)^loose
  = H_n
  + DeltaH_ext,n
  + beta * DeltaT_s * (q_lag - q_ref)
```

SWAP is evaluated once at that head and the resulting candidate is accepted.

The lagged flux is:

- `q_ref` for the first window;
- the previously accepted SWAP flux thereafter.

After the SWAP evaluation, E3 computes the implicit closure defect using the newly returned flux:

```text
r_H
  = H_(n+1)^loose
  - [H_n + DeltaH_ext,n
     + beta*DeltaT_s*(q_swap(H_(n+1)^loose)-q_ref)]
```

Loose coupling is not re-iterated to remove this defect.

### 6.2 IMPLICIT — converged scalar whole-window exchange

For each window solve:

```text
f(H)
  = H
  - [H_n + DeltaH_ext,n
     + beta*DeltaT_s*(q_swap(H)-q_ref)]
  = 0
```

using repeated real SWAP trials from the same accepted window origin.

The publication experiment uses a safeguarded scalar bracket/false-position procedure only as an **experimental reference solver**. It is not the production coupling algorithm and no acceleration novelty is claimed from it.

Convergence criterion:

```text
abs(f(H)) <= 1.0e-8 m
```

Maximum accepted SWAP trial evaluations per window:

```text
40
```

Bracket search is symmetric about the uncoupled predicted head with radii:

```text
0.00025, 0.0005, 0.001, 0.002,
0.004, 0.008, 0.016 m
```

If a valid sign-changing bracket cannot be obtained inside this bounded head envelope, the matrix case is recorded as `NO_BRACKET`.

A SWAP transaction/retry failure at a required evaluation is recorded as `SWAP_TRIAL_FAILED`.

## 7. Baseline flux

For each fresh case:

1. initialize real SWAP for that case's coupling-window duration;
2. obtain the predictor reference head and predictor response;
3. evaluate one real non-committing SWAP trial at the reference head;
4. use that returned flux as `q_ref`;
5. discard the trial.

This makes the controlled feedback term zero at the exact accepted initial state.

The calibration trial counts as component work.

## 8. Outputs and metrics

For every case record:

- feedback class and `C*`;
- `beta`;
- coupling-window duration;
- predictor `u(window)`;
- `C_pred(window)`;
- method;
- success/failure route;
- number of accepted coupling windows;
- total real SWAP trial evaluations;
- final accepted groundwater head;
- final committed SWAP storage;
- cumulative committed SWAP bottom exchange;
- maximum absolute per-window coupling closure defect;
- final closure defect.

For every successful case compare against the same-feedback 16-window implicit reference:

```text
DeltaH_ref
DeltaStorage_ref
DeltaExchange_ref
```

Both signed and absolute errors are retained.

## 9. Repeatability check

The complete `moderate / 4-window / implicit` case is executed twice in fresh processes.

The two result records must be identical within:

```text
head:        1e-12 m
storage:     1e-12 native storage units
exchange:    1e-14 m
trial count: exact integer equality
route:       exact equality
```

A repeatability failure blocks scientific interpretation.

## 10. Interpretation rules

E3 does not use iteration count alone as a scientific success metric.

The central outputs are continuous regime maps of:

```text
window duration
feedback control
loose closure defect
loose-vs-implicit difference
long-window-vs-short-window-reference difference
component work
failure boundary
```

A publishable non-trivial coupling result is supported if the matrix contains both:

1. a weak-feedback regime where loose coupling is demonstrably close to the converged/reference solution; and
2. a stronger and/or longer-window regime where loose coupling develops a reproducible coupling defect or reference error clearly above deterministic repeatability while a converged coupled solution remains available.

If all loose and implicit solutions remain indistinguishable at repeatability scale over the complete bounded matrix, the manuscript must not claim demonstrated practical need for iterative coupling from E3.

If the real SWAP route fails before the controlled groundwater feedback becomes non-trivial, that is reported as a bounded SWAP/coupling-envelope result and no tolerance is relaxed to force the desired regime.

## 11. Explicit exclusions

E3 does not establish:

- that `u = J_R`;
- the true coupled Jacobian spectral radius;
- performance advantage of tangent information;
- IQN/Anderson superiority or inferiority;
- physical validity of N:1 spatial aggregation;
- broad MODFLOW field-scale behaviour;
- active drainage/root uptake/macropore/snow/temperature envelopes.

Those belong to E4/E5/E6/SCALE.

## 12. Gate

E3 is complete when:

1. the preregistered matrix has been attempted without post-hoc parameter substitution;
2. repeatability passes;
3. successful and failed cases are both retained;
4. machine-readable results and figure-ready CSV are persisted;
5. manuscript Results 4.3 is updated only from those persisted results;
6. the claim-evidence ledger is updated without upgrading claims beyond the observed regime.
