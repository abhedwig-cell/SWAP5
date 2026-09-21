# PB01 residual derivation: condensed response versus physical interface flux

Date: 2026-09-21
Status: MATHEMATICAL RECONCILIATION, NO PRODUCTION CHANGE

## Purpose

PB01 resolves the apparent sign conflict between:

- the accepted physical interface amount E_c(H), whose NH01 derivative is negative; and
- production q_u(H), whose affine derivative is positive.

The resolution is that these are different algebraic objects.

## NH01 physical equations

Let x = z_p-z_p0 and y = H-H0, with z_p0=H0. Let q_b be the bottom flux positive INTO SWAP/top system.

The top-system equations are:

    S_S*x = W_S + q_b*dt
    q_b = C*(H-z_p)

Eliminating x gives:

    H-H0 = W_S/S_S + q_b*(dt/S_S + 1/C)

Define

    u = dt/(dH/dq_b)
      = C*dt*S_S/(S_S+C*dt).

Solving the predictor relation for q_b at arbitrary H gives:

    q_b(H) = (u/dt)*(H-H0) - (u/S_S)*(W_S/dt).

Production defines:

    q_u(H) = -q_b(H)

for this transparent exact linear oracle, hence:

    q_u(H) = beta*W_S/dt - (u/dt)*(H-H0),

where beta=u/S_S.

This is the physical groundwater-directed exchange rate and its derivative is negative.

## Why production code has a positive partial slope

The historical production response is not formed by re-solving q_b(H) from the physical top equation above. It stores:

    q_u,* = u*(H_pred-H_start)/dt - q_b,pred

and then reanchors with:

    q_u^aff(H) = q_u,* + (u/dt)*(H-H_pred).

For the exact NH01 predictor relation, q_u,* is beta*W_S/dt and independent of q_b,pred. Therefore the reanchored production law has positive slope.

This proves that production q_u^aff cannot simultaneously be the exact physical groundwater-directed exchange law of NH01 under the present sign definitions.

The earlier statement that the positive slope was merely a different residual-side representation is insufficient by itself: the live API package consumes q_u^aff as a positive groundwater infiltration flux. No later source-level sign inversion exists.

## Coupled groundwater storage equation

The independent physical groundwater equation is:

    S_M*(H-H0)/dt = q_phys(H)

with:

    q_phys(H) = beta*W_S/dt - (u/dt)*(H-H0).

Therefore:

    (S_M+u)*(H-H0)/dt = beta*W_S/dt

and NH01 gives H=8.04 m.

If instead the positive-slope production law is inserted as physical infiltration,

    q_prod(H) = beta*W_S/dt + (u/dt)*(H-H_pred),

then the root depends on the predictor reference H_pred and generally differs from the physical root. There is no algebraic cancellation unless another term or a different sign/origin convention is present in the actual groundwater residual.

## PB01 conclusion

For the transparent fixed-interface NH01 oracle, the currently documented/public positive-slope q_u affine law is not yet reconciled with the physical eliminated interface exchange law.

This is a genuine conceptual discrepancy candidate, not yet a production defect claim, because the real production predictor/corrector may define the response object against a different reference residual than the minimal NH01 abstraction.

The next proof must therefore use the exact production predictor origin and live MODFLOW storage equation, without changing signs, and compare its root against the NH01 physical root.

## Required falsification experiment

For multiple predictor q_b values:

1. construct the exact NH01 predictor H_pred and production u,q_u,*;
2. publish the unchanged production affine law with +u/dt slope;
3. solve a one-cell transient groundwater storage equation from H0;
4. compare the resulting head to 8.04 m;
5. evaluate the accepted physical q_b(H) and full component ledger at that head.

If the root varies with predictor q_b or differs from 8.04 m, the positive-slope affine law is not an exact condensation of this fixed-interface physical oracle.

No production code should be changed until this falsification result is explicit.
