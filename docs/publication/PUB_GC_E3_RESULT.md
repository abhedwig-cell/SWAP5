# PUB-GC E3 consolidated result — coupling window, feedback and component envelope

## Status

**E3 CLOSED — SUPPORTED_RESTRICTED**

Date: 2026-09-18.

This document is the publication-facing consolidation of:

- E3 main coupling-window/feedback matrix;
- E3-D predictor-envelope scan;
- E3-D2 predictor failure-mechanism diagnosis;
- E3-R admitted stronger-flux refinement.

The detailed preregistrations, raw result summaries and workflow artifacts remain the evidence authority for individual numbers.

## Central result

The current real-SWAP + MODFLOW6 near-equilibrium fixture contains a reproducible **weak physical-feedback regime**.

Within that regime:

1. a loose/one-pass interface solution can violate the strict finite-window flux residual criterion by orders of magnitude;
2. iterative coupling restores the interface equation in a small number of outer iterations whenever SWAP can provide valid corrector candidates;
3. the corresponding groundwater-head correction remains extremely small;
4. attempts to create materially stronger feedback by increasing flux and window length encounter the bounded SWAP predictor/corrector execution envelope before a large groundwater-head correction is produced.

The result therefore supports strong coupling as a method for reproducible interface closure, but it does **not** support a broad claim that strong iteration is hydrologically important in every operational regime.

## E3 main matrix

Preregistered matrix:

```text
DeltaT = 1e-4, 1e-3, 1e-2 day
q      = 1e-6, 1e-3, 1e-2, 1e-1 cm/day
K      = 0.01, 0.1, 1, 10 m/day
```

Total: 48 cases.

Outcome:

```text
CONVERGED                 12
SWAP_PREDICTOR_UNAVAILABLE 36
```

All 12 converged cases are the `q=1e-6 cm/day` row.

Across those cases:

- outer iterations: 2–5;
- maximum loose relative interface mismatch: 1.7665;
- maximum absolute loose residual: `2.8034e-12 m/s`;
- maximum loose-to-iterative head correction: `5.55e-9 m`;
- maximum SWAP interface-rate correction: `1.92e-14 m/s`.

The largest loose residual integrated over the 864 s window corresponds to only about:

```text
2.42e-9 m water depth
```

or `2.42e-6 L` over the one-square-metre fixture.

Thus strict algebraic interface closure and hydrologically material state error are distinct quantities.

## E3-D predictor envelope

A post-matrix, separately preregistered scan evaluated 21 predictor-only cases between `1e-6` and `1e-3 cm/day`.

Outcome:

```text
READY   14
FAILED   7
```

All failures occurred at:

```text
104 = PREDICTOR_WHOLE_WINDOW_TRIAL_INCOMPLETE
```

before tangent construction, response assembly or MODFLOW participation.

Boundary:

| window | largest READY q | smallest failed q |
| ---: | ---: | ---: |
| 1e-4 day | 3e-5 cm/day | 1e-4 cm/day |
| 1e-3 day | 1e-4 cm/day | 3e-4 cm/day |
| 1e-2 day | 1e-4 cm/day | 3e-4 cm/day |

The response coefficient `u` also changes substantially with window duration and measurably with flux. It must not be interpreted as a static soil property.

## E3-D2 failure mechanism

Six ready/fail boundary cases were diagnosed without changing any scientific or execution tolerance.

All failed cases returned:

```text
CANONICAL_STATUS_TRANSACTION_FAILED
```

No mass rejection and no temporal-certificate-unavailable rejection occurred.

The mechanism varies with window:

- `1e-4 day, q=1e-4`: solver-rejection dominated;
- `1e-3 day, q=3e-4`: mixed solver and temporal rejection;
- `1e-2 day, q=3e-4`: temporal-rejection dominated.

The largest valid long-window predictor itself required 59 attempts, 45 temporal retries and 14 accepted substeps.

The high-flux boundary is therefore a genuine bounded SWAP component transaction envelope, not a coupling-interface or MODFLOW failure.

## E3-R admitted stronger-flux refinement

E3-R removed the original background lateral head gradient and used only predictor fluxes already demonstrated valid by E3-D.

Matrix:

```text
1e-4 day: q = 1e-6, 3e-5 cm/day
1e-3 day: q = 1e-6, 1e-4 cm/day
1e-2 day: q = 1e-6, 1e-4 cm/day

K = 0.01, 0.1, 1, 10 m/day
```

Total: 24 cases.

Outcome:

```text
CONVERGED                    20
SWAP_LOOSE_TRIAL_FAILED       3
SWAP_ITERATIVE_TRIAL_FAILED   1
```

At `1e-3 day, q=1e-4 cm/day` — 100 times the original F-GC44 flux — all four K cases converged in 3–5 outer iterations.

Their loose interface residuals were approximately:

```text
-3.72e-12 m/s
```

but the loose-to-iterative head correction remained only:

```text
1.60e-9 to 1.83e-9 m.
```

The largest interface-rate correction was:

```text
6.11e-15 m/s.
```

## Long-window corrector boundary

At:

```text
DeltaT = 1e-2 day
q      = 1e-4 cm/day
```

the full comparison could not be completed.

For three K values the first loose prescribed-head SWAP corrector failed.

At `K=1 m/day` the loose corrector succeeded, but the iterative solve reached a SWAP corrector failure at outer iteration four.

The relevant candidate-head offsets from the predictor reference were only order:

```text
1e-8 to 1e-7 m.
```

Therefore the current long-window prescribed-head corrector envelope becomes limiting before a materially large groundwater-head feedback is obtained.

## Answer to RQ3 within the current envelope

The evidence supports the bounded statement:

> Iterative coupling is required to satisfy the strict finite-window interface equation in the tested cases, but the hydrological state correction is negligible in the currently admitted near-equilibrium fixture. Increasing window length and interface flux eventually reaches the SWAP component execution envelope before producing a materially large groundwater-head response.

This is not a general statement that vadose-zone/groundwater coupling is weak.

It establishes a negative-control regime and identifies what a future positive strong-feedback case must avoid.

## Scientific consequences

### For PUB-GC

The paper can now separate:

```text
numerical coupling consistency
```

from:

```text
hydrological impact of coupling correction.
```

Iteration count or residual reduction alone must not be used as evidence of hydrological importance.

### For ACCELERATE

The current weak-feedback regime is not a suitable positive acceleration showcase.

It can serve as a negative control for the later oracle/IQN comparison.

### For E4

The valid weak-feedback regimes are useful for response-identity experiments because they permit controlled perturbation without outer-coupling instability.

E4 should determine:

```text
u_FD
J_S = d DeltaS / dH
J_R = d V_u / dH
```

and their perturbation/window dependence before any stronger acceleration claim is made.

### For future strong-feedback evidence

Do not manufacture a strong case by relaxing retry, temporal, mass or coupling tolerances.

A stronger case should instead arise from:

- a different admitted hydrological state;
- a different physically defensible groundwater-response geometry;
- or a separately qualified component-envelope extension.

## Evidence references

- `PUB_GC_E3_PREREGISTRATION.md`
- `PUB_GC_E3_INITIAL_RESULT.md`
- `PUB_GC_E3_INITIAL_RESULT.json`
- `PUB_GC_E3D_PREDICTOR_ENVELOPE_PREREGISTRATION.md`
- `PUB_GC_E3D_PREDICTOR_ENVELOPE_RESULT.md`
- `PUB_GC_E3D_PREDICTOR_ENVELOPE_RESULT.json`
- `PUB_GC_E3D2_PREDICTOR_FAILURE_PREREGISTRATION.md`
- `PUB_GC_E3D2_PREDICTOR_FAILURE_RESULT.md`
- `PUB_GC_E3D2_PREDICTOR_FAILURE_RESULT.json`
- `PUB_GC_E3R_STRONGER_FEEDBACK_PREREGISTRATION.md`
- `PUB_GC_E3R_STRONGER_FEEDBACK_RESULT.md`
- `PUB_GC_E3R_STRONGER_FEEDBACK_RESULT.json`

Key successful workflows:

- E3 main matrix: `35343426404`;
- E3-D predictor envelope: `35343968268`;
- E3-D2 mechanism: `35344946609`;
- E3-R stronger feedback: `35344946652`.

## Decision

**E3 is closed as SUPPORTED_RESTRICTED.**

Proceed to E4 response identity.

The search for a materially non-trivial strong-feedback hydrological case remains a separate later evidence need and must not block response characterization in already valid regimes.
