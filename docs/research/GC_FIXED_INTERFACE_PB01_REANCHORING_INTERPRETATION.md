# PB01 reanchoring interpretation

Date: 2026-09-21
Status: ANALYTICAL INTERPRETATION AFTER EXECUTED PB01; PRODUCTION INTENT NOT YET CLOSED

## Observation

Executed PB01 proves that the public/outward affine law with a positive +u/dt slope is not the exact physical fixed-interface flux condensation for NH01.

Existing F-GC44 qualification logic, however, has previously used a corrector/reanchoring pattern in which the affine boundary is forced through the newly evaluated SWAP exchange after an outer iteration.

This creates a materially different mathematical object from a frozen physical flux law.

## Fixed-point argument

Let the true SWAP-to-groundwater exchange be q(H). Let the groundwater equation be represented by G(H,q)=0.

At outer iteration k, define a surrogate

    q_k^sur(H) = q(H_k) + s_k (H-H_k)

where s_k is an iteration slope. It need not equal dq/dH.

If the outer algorithm solves

    G(H, q_k^sur(H)) = 0

and then reevaluates the true SWAP exchange q(H_{k+1}) and reanchors the next surrogate, any converged fixed point H* satisfies

    q_*^sur(H*) = q(H*)

because H_k -> H* and the anchor is exact at H_k.

Therefore the final coupled fixed point can satisfy the true physical exchange equation even when s_k has the wrong sign relative to dq/dH. The slope then controls convergence, not physical flux semantics.

## Consequence for u

PB01 plus MAP03 imply that, in the fixed-interface interpretation, +u/dt cannot simultaneously be claimed to be the derivative of the outward physical exchange.

Two interpretations remain:

1. production defect: the positive slope is used as a frozen physical response without sufficient reanchoring;
2. numerical quasi-Newton/preconditioning term: the positive slope is intentionally/non-intentionally used only to stabilize/accelerate an outer iteration whose accepted flux is supplied by a corrector.

The second interpretation explains why earlier slope-policy experiments could converge to the same accepted physics despite different nonzero slopes.

## Qualification requirement

Do not change production signs yet.

Close the following evidence chain first:

- prove from production orchestration, not only a test harness, whether every nonlinear coupling update reanchors the boundary through an actual SWAP corrector value;
- distinguish published predictor q_u from accepted interface exchange in the ledger;
- execute a live one-cell MODFLOW fixture with a known exact physical response;
- compare frozen-affine and reanchored iterations separately.

A frozen current-orientation affine law is expected to fail the NH01 physical root.
A reanchored outer iteration may still converge to H=8.04 m. If it does, u is qualified as an iteration slope for that algorithm, not as the outward physical flux derivative.
