# GC root-zone-memory linear two-state analytical oracle

Date: 2026-09-22  
Work unit: GC-RZM01  
Status: MATHEMATICS FROZEN BEFORE IMPLEMENTATION  
Scope: research-only, unit horizontal area

## 1. Purpose

GC-RZM01 is the first analytical step between the existing fixed-interface
dummy and a SWAP-like column with explicit root-zone memory.

It introduces exactly two internal SWAP states:

- root-zone water storage `W_r`;
- a lower-SWAP hydraulic/storage state `h_l`.

The fixed-interface hydraulic head `H_c` remains the sole physical
SWAP-MODFLOW interface head.

No Richards discretization or production SWAP process is introduced.

## 2. Linear root storage coordinate

The physical root-zone storage is primary:

```text
0 <= W_r <= W_capacity.
```

For the linear oracle only, define an invertible hydraulic coordinate

```text
h_r = h_r,ref + (W_r - W_r,ref) / S_r
W_r = W_r,ref + S_r (h_r - h_r,ref)
```

with `S_r > 0`.

The coordinate `h_r` is an analytical storage potential, not a claim that a
real root zone is hydrostatic or has one physical pressure head.

GC-RZM01 parameters are chosen so the capacity bounds remain inactive. Crossing
a bound invalidates the Phase-A oracle rather than silently clipping it.

## 3. Lower-SWAP state

The lower state is represented by interior hydraulic head `h_l` with physical
inventory change

```text
Delta W_l = S_l (h_l1-h_l0),   S_l > 0.
```

The state is inside the SWAP control volume, above the fixed coupling plane.

## 4. Signed internal fluxes

Positive is downward.

Root to lower SWAP:

```text
q_v = C_v (h_r-h_l),   C_v > 0.
```

Lower SWAP to MODFLOW through the fixed plane:

```text
q_c = C_c (h_l-H_c),   C_c > 0.
```

A negative value is the same physical law in the reverse direction. No second
sign convention is introduced for capillary supply.

`C_c` is an internal SWAP vertical conductance from the lumped lower state to
the fixed boundary plane. At the plane itself there is one head `H_c`, shared
by SWAP and MODFLOW.

## 5. Continuous balances

Let `f_r` and `f_l` be external rates [m/day] into root and lower SWAP.
The first canonical model uses constant `f_r` and `f_l=0`.

```text
dW_r/dt      = f_r - q_v
S_l dh_l/dt = f_l + q_v - q_c.
```

Using the linear root coordinate:

```text
S_r dh_r/dt = f_r - C_v(h_r-h_l)
S_l dh_l/dt = f_l + C_v(h_r-h_l) - C_c(h_l-H_c).
```

The integrated component ledger over `Delta t` is

```text
Delta W_r = F_r - E_v
Delta W_l = F_l + E_v - E_c
Delta W_SW = F_r + F_l - E_c
```

with

```text
E_v = integral(q_v dt)
E_c = integral(q_c dt).
```

Thus `E_v` cancels exactly from the SWAP-total ledger.

If MODFLOW owns storage `W_M` and external integrated input `F_M`,

```text
Delta W_M = F_M + E_c
```

and therefore

```text
Delta(W_SW+W_M) = F_r + F_l + F_M.
```

## 6. Matrix form for a prescribed constant interface head

For one coupling window hold a trial interface head `H_c` constant and define

```text
y = [h_r-H_c, h_l-H_c]^T.
```

For constant forcing `f=[f_r,f_l]^T`,

```text
dy/dt = A y + b
```

with

```text
A = [ -C_v/S_r          C_v/S_r
       C_v/S_l  -(C_v+C_c)/S_l ]

b = [f_r/S_r, f_l/S_l]^T.
```

For positive storages and conductances, `A` is stable.

The exact steady state is

```text
y_* = -A^{-1} b.
```

For the common first-stage case `f_l=0`,

```text
q_v,* = q_c,* = f_r
h_l,* = H_c + f_r/C_c
h_r,* = H_c + f_r(1/C_c + 1/C_v).
```

## 7. Exact transient solution

For `T=Delta t`,

```text
y(T) = y_* + exp(A T) [y(0)-y_*].
```

The two decay eigenvalues are

```text
lambda_± =
-0.5 * [C_v/S_r + (C_v+C_c)/S_l]
±0.5 * sqrt(
 [C_v/S_r + (C_v+C_c)/S_l]^2
 - 4 C_v C_c/(S_r S_l)
).
```

Both are negative. Define

```text
tau_slow = -1/lambda_+
tau_fast = -1/lambda_-,
```

where `lambda_+` is the less-negative root.

This gives the exact two-timescale hydrological memory of the first model.

## 8. Exact integrated interface exchange

Define

```text
M(T) = integral_0^T exp(A t) dt
     = A^{-1}[exp(A T)-I].
```

Then

```text
integral_0^T y(t) dt
= y_* T + M(T)[y(0)-y_*].
```

The accepted fixed-plane transfer is

```text
E_c(H_c) =
C_c * e_l^T {
  y_* T + M(T)[y(0)-y_*]
}
```

with `e_l=[0,1]^T`.

The same transfer must independently satisfy

```text
E_c = F_r + F_l - Delta W_r - Delta W_l.
```

Those two calculations are separate mass-oracle routes and must agree.

## 9. Exact finite-window condensed response

The committed absolute states `h_r0,h_l0`, forcing, parameters and window
duration are immutable while a coupler probes trial `H_c`.

Because

```text
y(0) = [h_r0,h_l0]^T - H_c [1,1]^T
```

and the linear dynamics are time invariant, the exact integrated response is
affine:

```text
E_c(H_c) = R_* + J_* (H_c-H_*).
```

Its exact tangent is

```text
J_* = dE_c/dH_c
    = -C_c e_l^T M(T) [1,1]^T.
```

For fixed parameters and `T`, `J_*` is independent of internal state and
forcing in GC-RZM01. The intercept is not: it carries the committed internal
state and forcing history.

Therefore Phase A prospectively predicts:

- `H_c` alone is not a full-state descriptor;
- one scalar tangent plus one intercept is nevertheless exactly sufficient for
  the current finite window of this linear model, provided both are tied to the
  immutable committed origin state and window;
- the accepted `E_c` remains a physical ledger quantity distinct from the
  predictor coefficients.

## 10. Scalar MODFLOW storage coupling

A one-cell finite-window MODFLOW balance may be written

```text
S_M (H_c-H_c0) = F_M + E_c(H_c).
```

For GC-RZM01, `E_c(H_c)` is affine, so this residual has one exact scalar root
unless the combined coefficient is singular.

This finite-window coupled solve is deliberately distinguished from a fully
continuous three-state ODE in which MODFLOW head evolves inside the window.
The latter may be introduced later as an independent temporal-resolution
reference. It must not be silently substituted for the declared window
contract.

## 11. Canonical parameter set and frozen targets

Use

```text
S_r = 0.20
S_l = 0.10
C_v = 0.50 /day
C_c = 0.25 /day
H_c = 8.00 m
h_r0 = 8.00 m
h_l0 = 8.00 m
f_r = 0.010 m/day
f_l = 0
T = 1 day

W_r,ref = 0.100 m
h_r,ref = 8.00 m
W_capacity = 0.200 m.
```

The exact characteristic values are

```text
lambda_slow = -0.6698729810778064 /day
lambda_fast = -9.330127018922193 /day
tau_slow   =  1.492820323027551 day
tau_fast   =  0.1071796769724491 day.
```

The exact steady offsets are

```text
h_r,* - H_c = 0.060 m
h_l,* - H_c = 0.040 m.
```

For the one-day canonical transient the frozen numerical targets are

```text
h_r1 = 8.029873061510365...
h_l1 = 8.017945898366513...
E_c  = 0.002230797861275541 m
J_*  = -0.14936530755182922
```

with exact values generated from the closed-form matrix equations above rather
than these rounded display values.

The root endpoint remains strictly between zero and capacity.

## 12. Phase-A limiting cases

The implementation must preserve these analytical limits.

### Zero upper/lower gradient

If `h_r=h_l=H_c` and external forcing is zero, both internal fluxes are zero
and the state is stationary.

### Fast internal equilibration

For conductances large relative to storage/window timescales, internal head gaps
shrink rapidly. This is a dynamical limit, not a redefinition of the interface
state.

### Slow internal equilibration

For conductances small relative to the window, only a small fraction of root
forcing reaches the fixed interface. Root storage retains most of the signal.

### Signed reverse response

If the lower state is below the fixed-interface head strongly enough,
`q_c<0`; MODFLOW supplies water upward into SWAP through the same signed law.

## 13. Transaction semantics

Every trial solve starts from one immutable committed pair
`(W_r^n,h_l^n)`.

Trial endpoint states and `E_c` are disposable until the coupling residual is
accepted. Repeated trial evaluation at different `H_c` values must not mutate
the committed origin.

On acceptance, root state, lower state and the physical interface ledger are
committed together.

Restart from the exact accepted state must reproduce uninterrupted execution.

## 14. Falsification boundaries

GC-RZM01 is scientifically falsified for its declared equations if any of the
following persists after excluding implementation defects:

- the two independent `E_c` calculations disagree above tolerance;
- root/lower component ledgers do not close;
- the internal `E_v` fails to cancel from total SWAP storage;
- the exact exponential solution is not invariant to exact subpartitioning
  under identical piecewise-constant `H_c` and forcing;
- repeated trial calls mutate the committed origin;
- numerical evaluation of `E_c(H_c)` is not affine to tolerance;
- the preregistered steady state, eigenvalues or canonical transient are not
  reproduced;
- a deliberately double-booked storage or reversed-flux negative control passes
  the physical mass gate.

No gate may be relaxed after execution to turn a scientific failure into a pass.
