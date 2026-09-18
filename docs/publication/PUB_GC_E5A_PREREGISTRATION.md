# PUB-GC E5a preregistration — zero-cost oracle versus black-box coupling

## Status

**FROZEN BEFORE FIRST E5 EXECUTION**

Date: 2026-09-18.

Dependency: PUB-GC E4 response identity.

## Purpose

E5a is the upper-bound falsification test for ACCELERATE.

It compares coupling methods on exactly the same real SWAP origin and live MODFLOW6 prepared solve.

Methods:

1. FP — black-box fixed-point flux iteration;
2. Aitken — scalar dynamic relaxation of the black-box flux residual;
3. SECANT — scalar multisecant/IQN-equivalent cold-start root solve;
4. uA — current supplied finite-window predictor response;
5. ORACLE — zero-cost direct head-driven J_R response.

The ORACLE response acquisition cost is deliberately set to zero. This gives supplied response information its strongest possible advantage.

## Cases

Three E4 baselines:

| ID | window d | q_bot cm/d | J_R |
| --- | ---: | ---: | ---: |
| B1 | 1e-4 | 1e-6 | -3.402833570476105e-5 |
| B3 | 1e-3 | 1e-4 | -2.8821767195098304e-4 |
| B4 | 1e-2 | 1e-6 | -1.190272325146675e-3 |

Each is run with zero lateral CHD gradient and:

```text
K = 0.01 and 0.1 m/day
Sy = 0.15
```

Total: 6 physical cases x 5 algorithms = 30 isolated processes.

B3 is the primary discrimination case because E4 showed:

```text
|J_R| / u_A = 1.08119048.
```

## Common coupling equation

For a boundary flux q presented to MODFLOW:

```text
H = G(q)

q_swap = R(H)

r = q_swap - q
```

Convergence requires:

```text
MODFLOW nonlinear convergence
AND
|r| <= 1e-15 m/s.
```

Maximum coupling iterations: 40.

Every SWAP corrector is replayed from one immutable accepted origin and discarded after measurement.

## Black-box updates

### FP

```text
q_{k+1} = q_swap,k
```

### Aitken

```text
q_{k+1} = q_k + omega_k r_k
```

with `omega_0 = 1`.

For k>0:

```text
omega_k = -omega_{k-1} r_{k-1} / (r_k-r_{k-1})
```

when the denominator is numerically usable.

For robustness only, `omega` is clipped to [-10,10]. A denominator failure falls back to the previous omega. These rules are fixed before execution.

### SECANT

Cold start uses one FP update.

Thereafter:

```text
q_{k+1}
 = q_k - r_k (q_k-q_{k-1})/(r_k-r_{k-1})
```

when the secant denominator is usable; otherwise one FP update is used.

This scalar method is the one-dimensional black-box multisecant/IQN comparator.

## Response-informed updates

Both response methods use a local affine boundary:

```text
q(H) = q_ref + s(H-H_ref)
```

and after each rejected corrector translate the same slope through the latest SWAP point.

### uA

Uses the current predictor HCOF/RHS produced by SWAP.

No extra response acquisition work is counted beyond the common predictor.

### ORACLE

Uses:

```text
s = J_R / DeltaT_seconds
```

converted to the MODFLOW HCOF units.

The line is initially anchored at the same predictor reference `(H_ref,q_ref)` as uA.

J_R is treated as known at zero acquisition cost.

## Work metric

All methods share one predictor evaluation.

Primary SWAP work:

```text
W = 1 predictor + number of SWAP correctors
```

MODFLOW solve iterations are reported separately.

No diagnostic evaluation is excluded from the algorithmic corrector count.

## Upper-bound decision rule

For each physical case define:

```text
DeltaW_oracle = W_SECANT - W_ORACLE.
```

Interpretation:

- ORACLE worse or equal to SECANT in every case -> RC-2 fails;
- ORACLE saves exactly one corrector in isolated cases -> weak information value only;
- ORACLE saves >=2 full SWAP correctors in a reproducible case, or converges where SECANT fails -> material upper-bound information value.

If ORACLE cannot beat **cold** SECANT, warm-history IQN cannot rescue an ACCELERATE novelty claim.

If ORACLE does beat cold SECANT, a warm-history test remains mandatory before RC-2 can pass.

## Solution equivalence

Converged algorithms in the same physical case must agree on final head and exchange within the numerical envelope.

A method that reaches the residual criterion at a materially different coupled solution is not counted as acceleration.

## No novelty assumption

E5a tests computational information value only.

It does not claim novelty for fixed point, Aitken, secant/IQN, Newton or supplied derivatives.
