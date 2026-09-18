# PUB-GC E5 analytical local-linear control

## Status

**ANALYTICAL CONTROL RECORDED BEFORE EMPIRICAL E5 OUTPUT**

Date: 2026-09-18.

This document is not numerical evidence from the E5 workflow. It derives the expected algorithm behaviour if the real SWAP response is exactly linear around the E4 reference state.

The purpose is to separate:

- behaviour implied by the frozen algorithm definitions and E4 local derivatives;
- behaviour caused by finite-window nonlinearity or bounded SWAP response domains.

No E5 algorithm or tolerance is changed by this control.

## Linearized problem

Let:

```text
V(H) = V_ref + J_R (H - H_ref)
```

and:

```text
G(V) = H_ref + gamma (V - V_ref)
```

with:

```text
gamma = C / |J_R|.
```

Because the E4 B1-B4 responses have `J_R < 0`:

```text
Phi'(H_ref) = gamma J_R = -C.
```

The known coupled root is `H_ref`.

The common transfer residual is:

```text
F(H) =
    [J_R - 1/gamma] (H - H_ref).
```

## Plain fixed point

The head error evolves exactly as:

```text
e_(k+1) = -C e_k.
```

Therefore:

- `C < 1`: contractive oscillation;
- `C = 1`: neutral two-cycle in the exact linear model;
- `C > 1`: divergent oscillation.

With the preregistered `1e-6 m` initial displacement, integrated transfer tolerance and 20-evaluation cap, the linear control predicts approximately:

| C | B1 | B2 | B3 | B4 |
| ---: | ---: | ---: | ---: | ---: |
| 0.1 | 6 | 6 | 6 | 6 |
| 0.5 | 15 | 15 | 15 | 14 |
| 0.9 | >20 | >20 | >20 | >20 |
| 1.1 | divergent | divergent | divergent | divergent |
| 1.5 | divergent | divergent | divergent | divergent |
| 2.0 | divergent | divergent | divergent | divergent |

Thus a fixed-point failure at or above the near-critical cases is not itself evidence of hydrological nonlinearity.

## Cold scalar secant / IQN analogue

For an exactly linear scalar residual, two distinct black-box residual evaluations identify the residual slope. A third evaluation verifies the predicted root.

The preregistered cold secant path therefore predicts:

```text
3 SWAP evaluations
```

for all non-trivial B1-B4/C cases.

A different empirical count indicates either:

- early tolerance satisfaction;
- nonlinear response;
- response-domain failure;
- numerical secant degeneracy.

## Zero-cost J_R oracle

For an exactly linear response and the exact `J_R`:

```text
H_1 =
    H_0 - F(H_0) / F'(H)
    = H_ref.
```

One evaluation determines the residual at `H_0`; a second verifies the root.

Expected work:

```text
2 SWAP evaluations.
```

The ideal cold-information advantage over scalar secant is therefore only:

```text
DeltaW_oracle = 1 SWAP evaluation
```

in the exactly linear case.

This establishes an important upper-bound context before seeing the empirical result: even a perfect free local derivative is not expected to produce a large work advantage over a competent cold scalar secant method in a one-dimensional smooth interface.

## Supplied u_A response

E4 defines the response approximation used in E5 as:

```text
J_u = -u_A.
```

For B1, B2 and B4:

```text
J_u ~= J_R
```

to high accuracy, so the linear control predicts the same two-evaluation behaviour as the oracle.

B3 deliberately differs:

```text
|J_R| / u_A ~= 1.08119048.
```

For a fixed approximate Newton derivative:

```text
F'_u = J_u - 1/gamma
```

the linear error factor is:

```text
rho_u =
  1 - (J_R - 1/gamma) / (J_u - 1/gamma).
```

Using the E4 B3 values and the preregistered tolerance, the local-linear control predicts approximately four SWAP evaluations for the supplied-`u_A` method over the E5 `C` scan, versus two for the true `J_R` oracle and three for cold secant.

Thus B3 is a predeclared mechanism test: if the empirical real-SWAP map reproduces this ordering, the extra work follows directly from using the derivative of the wrong finite-window map rather than from a generic failure of response-informed coupling.

## Dynamic Aitken

For an exactly affine scalar fixed-point map, dynamic Aitken relaxation can reconstruct the fixed point after observing successive residuals. The expected behaviour is therefore similar in information content to scalar secant acceleration, subject to the exact update sequence and denominator conditioning.

E5 reports empirical work rather than assigning a fixed expected count because the preregistered Aitken update acts on the head fixed-point residual rather than directly on the transfer residual.

## Interpretation use

This analytical control is used only as follows:

- empirical agreement indicates locally linear behaviour;
- extra evaluations indicate nonlinearity, response mismatch or tolerance/domain effects;
- fewer evaluations can occur through early tolerance satisfaction;
- a domain failure is not overwritten by the linear prediction.

The control does not alter the E5 stop/go rule.
