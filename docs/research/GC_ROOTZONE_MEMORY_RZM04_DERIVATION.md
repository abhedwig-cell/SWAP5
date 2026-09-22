# GC-RZM04 minimal nonlinear conductance derivation

Date: 2026-09-22  
Status: PREREGISTERED DESIGN  
Prerequisite: GC-RZM03 qualified

## Question

Which linear result fails first when the analytical SWAP surrogate acquires one
minimal internal state dependence, while storage ownership, the fixed coupling
plane and the mass ledger remain unchanged?

RZM04 changes exactly one constitutive element. The root-to-lower conductance
becomes a smooth positive function of the mean internal head:

```text
C_v(h_r,h_l) = C_v0 exp[ beta ((h_r+h_l)/2 - h_ref) ]
q_v = C_v(h_r,h_l) (h_r-h_l).
```

The lower-to-interface law remains `q_c=C_c(h_l-H_c)`. Storage relations
remain linear. `beta=0` exactly recovers RZM01-RZM03.

This choice is deliberately minimal. It adds no threshold, hysteresis,
direction switch, new storage or drainage process. It is not proposed as a
production unsaturated-conductivity law.

## Oracle and numerical qualification

There is no longer a constant 2x2 matrix exponential. The independent oracle
is a deterministic high-accuracy RK4 integration of the two continuous
balances and the two cumulative transfer ledgers:

```text
dW_r/dt = f_r - q_v
S_l dh_l/dt = f_l + q_v - q_c
dE_v/dt = q_v
dE_c/dt = q_c.
```

The qualification runner must demonstrate convergence under step halving
against a finer preregistered reference. Accepted mass is checked from both
integrated flux and storage-ledger routes.

## Falsification targets

1. **Linear recovery**: beta=0 agrees with the exact linear oracle.
2. **Mass**: root, lower and total-SWAP ledgers close under nonlinearity.
3. **Bidirectionality**: the smooth positive conductance preserves signed
   upward/downward q_v.
4. **Non-affinity**: for one committed origin and window, evaluate E_c at
   H_* - dH, H_*, H_* + dH. The second finite difference must be nonzero above
   numerical error for the selected nonlinear probe.
5. **Tangent locality**: a tangent estimated at H_* may predict locally, but
   must not be represented as an exact state-independent whole-window
   coefficient.
6. **Committed-origin dependence**: repeat the tangent probe from two different
   root/lower states. The tangents must differ for beta != 0.
7. **Transactional repeatability**: repeated trials from the same immutable
   committed state are identical and trial order cannot change the accepted
   result.

## Decision logic

If these gates pass, the first scalar-condensation result is refined:

- H_c may still be the sole physical interface head.
- One scalar tangent can still be useful local response information.
- But an exact affine response over a finite head range is no longer generally
  available, and the response derivative becomes state/origin dependent.

That would separate *interface-state sufficiency* from *linear response
sufficiency* without introducing real SWAP yet.
