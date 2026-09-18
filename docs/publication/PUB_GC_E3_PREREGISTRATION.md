# PUB-GC E3 preregistration — coupling-window and groundwater-buffering characterization

## Status

**PREREGISTERED BEFORE MATRIX EXECUTION**

Date: 2026-09-18.

Canonical baseline:

`integration/f-ci-canonical@585a8719242bf58e4c37c6283298dfad7b20a0ae`

Reconciliation note: the preregistration was first drafted against `06e585cc...`; canonical advanced before any E3 matrix execution. The E3-relevant F-GC44 bridge/build files were unchanged across that delta, so the same frozen matrix and interpretation rules were carried forward before first execution.

Publication line: PUB-GC / COUPLE.

## Purpose

E3 asks whether iterative SWAP5-MODFLOW6 coupling materially changes the coupled solution relative to a one-pass exchange, and how that need changes with:

1. the duration of the finite coupling window;
2. the physical buffering of the groundwater cell.

This first E3 block is an intentionally controlled **single-window convergence characterization**. It does not yet claim same-horizon temporal accuracy for different window lengths.

## Frozen vadose-zone configuration

The SWAP side reuses the real FMR/reference-Richards configuration qualified by F-GC44 and PUB-GC E1/E2:

- one real SWAP column;
- same soil and initial hydraulic profile;
- same top and predictor bottom flux;
- drainage, root extraction, macropore flow, snow and soil temperature inactive;
- accepted-trajectory analytic predictor response;
- every corrector replayed from one immutable accepted origin.

Only the window duration is varied.

## Groundwater configuration

One live MODFLOW6 6.8.0 model is used per case:

- 1 layer x 1 row x 3 columns;
- centre cell coupled to SWAP through the API package;
- fixed-head cells at the two ends with the same +/-0.002 m gradient used in F-GC44;
- hydraulic conductivity fixed at 1.0 m/day;
- centre-cell specific yield varied as the groundwater-buffering control;
- specific storage fixed at 0.02 1/m;
- all solver tolerances unchanged from F-GC44.

Changing specific yield changes the transient head response to a given exchange while leaving the SWAP model and lateral groundwater conductivity unchanged. Specific yield is therefore treated as a **controlled groundwater-buffering axis**, not as the formal coupled Jacobian C. Formal response derivatives remain E4/E5 work.

## Matrix

Coupling-window durations:

```text
2.5e-5 day   = 2.16 s
1.0e-4 day   = 8.64 s   [F-GC44 anchor]
4.0e-4 day   = 34.56 s
1.6e-3 day   = 138.24 s
```

Groundwater specific-yield values:

```text
0.02   low storage / stronger transient head response
0.15   F-GC44 anchor
0.30   higher storage / weaker transient head response
```

Total matrix: 12 cases.

These values are experimental controls. They are not asserted to span all realistic aquifers.

## Three coupling treatments per case

### L0 — constant-flux loose coupling

Freeze the groundwater exchange at the predictor reference flux:

```text
Q(H) = Q_ref
```

Solve MODFLOW to its own nonlinear convergence without updating SWAP.

After MODFLOW convergence, run one **diagnostic only** SWAP corrector from the accepted origin at the resulting head and measure the interface mismatch:

```text
r_L0 = q_SWAP(H_L0) - q_GW,L0
```

The diagnostic corrector is not counted as operational L0 work.

### L1 — fixed affine predictor response

Freeze the initial SWAP predictor response:

```text
Q(H) = HCOF_0 H - RHS_0
```

and solve MODFLOW to its own nonlinear convergence.

Then run one diagnostic SWAP corrector and measure:

```text
r_L1 = q_SWAP(H_L1) - q_GW,L1
```

This separates the value of the initial compact response from full coupled corrector iteration.

### S — converged strong coupling

Use the current F-GC44 corrector iteration:

1. publish current affine response;
2. execute one MODFLOW nonlinear iteration;
3. evaluate a real SWAP corrector from the immutable origin at the candidate head;
4. test conjunctive convergence;
5. if not converged, discard the SWAP candidate and update the affine reference;
6. retain the fixed admitted response slope within the window.

Acceptance criterion:

```text
MODFLOW nonlinear convergence == true
AND
|q_SWAP - q_GW| <= 1.0e-15 m/s
```

Maximum coupled iterations: 40, bounded by the existing prepared-solve limit.

No case may relax this tolerance to obtain convergence.

## Primary outputs

For every case record:

- window duration;
- specific yield;
- predictor reference head and response coefficients;
- L0 MODFLOW solve calls;
- L0 head and diagnostic interface residual;
- L1 MODFLOW solve calls;
- L1 head and diagnostic interface residual;
- strong-coupling convergence/failure;
- strong outer iterations;
- strong accepted/candidate head;
- strong interface residual;
- head correction relative to L0 and L1;
- exchange correction relative to L0 and L1;
- SWAP corrector evaluations;
- any SWAP initialization/trial failure classification.

## Work accounting

Operational full-window SWAP evaluations are counted separately from publication-only diagnostic evaluations.

```text
L0 operational SWAP work:
    1 predictor evaluation

L1 operational SWAP work:
    1 predictor evaluation

S operational SWAP work:
    1 predictor evaluation + one corrector per coupled outer iteration
```

The one SWAP corrector used to measure L0/L1 residual is evidence overhead, not algorithmic work.

MODFLOW nonlinear solve calls are reported separately.

## Predeclared anchor requirement

The case:

```text
DeltaT = 1.0e-4 day
Sy     = 0.15
```

must reproduce the bounded F-GC44 strong-coupling behaviour within representation/numerical tolerance:

- convergence must occur;
- final flux residual must satisfy `1.0e-15 m/s`;
- final head must remain consistent with the admitted near-equilibrium result.

If the anchor does not reproduce, the matrix is invalid and must not be interpreted.

## Interpretation rules

### Iteration necessity

A one-pass method is not declared inadequate merely because its diagnostic residual is non-zero.

Instead report the residual relative to the strong-coupling acceptance tolerance and the resulting difference in head/exchange.

A material need for iteration is supported only where one-pass mismatch produces a non-negligible solution correction or violates the intended coupled tolerance by a substantial margin.

### Window-duration interpretation

This experiment may show that coupling convergence or one-pass mismatch changes with window duration from the **same initial state**.

It does not by itself establish temporal-discretization accuracy across different windows, because the physical end times differ.

A same-horizon short-window reference requires sequential accepted windows and is a separate E3 extension if needed.

### Failure interpretation

A case may legitimately fail because:

- SWAP initialization cannot qualify the requested window;
- a SWAP corrector exhausts transaction/retry bounds;
- MODFLOW fails to converge;
- conjunctive coupling fails within the iteration budget.

Such failures are scientific/numerical boundary observations and must be recorded, not converted into a workflow failure, except for the anchor case or an unclassified harness error.

## Predeclared summary questions

The matrix is interpreted through four questions:

1. Does constant-flux loose coupling ever already satisfy the coupled tolerance?
2. How much mismatch is removed by the initial affine SWAP response before any corrector iteration?
3. Does strong coupling converge across the matrix, and how many real SWAP correctors are required?
4. Do longer windows and lower groundwater storage systematically increase one-pass mismatch or strong-coupling work?

No monotonic trend is assumed in advance.
