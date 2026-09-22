# GC-RZM02 forcing-order and timescale derivation

Date: 2026-09-22  
Status: MATHEMATICS FROZEN BEFORE RZM02 IMPLEMENTATION  
Prerequisite: qualified GC-RZM01

## Question

GC-RZM01 proved that internal state can matter while a scalar affine interface
response remains exact for one linear window. GC-RZM02 asks when the history
inside and between windows becomes observable.

The two targeted mechanisms are:

1. ordering of equal integrated forcing or boundary-head perturbations;
2. location of the coupling-window duration relative to the two internal
   response timescales.

## Piecewise-constant forcing

For any subwindow of duration `d`,

```text
y_1 = exp(A d) y_0 + M(d)b
```

when the forcing vector is written directly in inhomogeneous form, with

```text
M(d) = integral_0^d exp(A t) dt.
```

Therefore two equal-duration blocks with forcing `b_wet` and `b_dry=0`
give different endpoints when their order is reversed:

```text
wet -> dry:
y_ED = exp(A d) M(d)b_wet

dry -> wet:
y_DE = M(d)b_wet.
```

The difference is

```text
y_ED-y_DE = [exp(A d)-I] M(d)b_wet.
```

It is nonzero for a finite-memory system except in special or limiting cases.

Equal integrated forcing is therefore not sufficient to determine the endpoint.

## Canonical forcing-order pair

Start from `h_r=h_l=H_c=8 m` and `W_r=0.100 m`.
Use two half-day blocks and the same total root input `0.010 m`.

Early forcing:

```text
0.0-0.5 d: f_r=0.020 m/day
0.5-1.0 d: f_r=0
```

Late forcing reverses those blocks.

For the canonical RZM01 parameters, the frozen expected endpoints are:

```text
EARLY:
h_r1-H_c = 0.023993153821211696 m
h_l1-H_c = 0.017491004024908014 m
W_r1     = 0.10479863076424234 m
E_c      = 0.003452268833266857 m

LATE:
h_r1-H_c = 0.03575296919951998 m
h_l1-H_c = 0.018400792708117814 m
W_r1     = 0.10715059383990400 m
E_c      = 0.0010093268892842205 m.
```

Both receive exactly `0.010 m` external water and both must close the same
total-system conservation equation. The difference is internal distribution and
how much water has already crossed the interface.

## Why order sensitivity disappears in two opposite limits

Scale both conductances by a positive factor `s`, leaving storage and forcing
unchanged.

As `s -> 0`, internal exchange becomes negligible during the one-day
experiment. Both forcing orders approach the same final root storage because
nearly all `0.010 m` remains where it entered, while `E_c -> 0`.

As `s -> infinity`, internal equilibration and fixed-plane transfer become
fast compared with each half-window. Both orders approach the same equilibrated
endpoint and nearly all supplied water reaches the fixed plane.

Thus forcing-order sensitivity is expected to be largest in an intermediate
regime rather than to increase monotonically with conductance.

Frozen diagnostic points for the early-minus-late interface transfer are:

```text
s=0.01:  0.0000015178280914223874 m
s=1:     0.0024429419439826365 m
s=100:   0.00031999999999999737 m.
```

These three points preregister the nonmonotonic qualitative signature only.
They do not claim that `s=1` is the global maximum.

## Finite-window condensed response versus window duration

Define the positive response magnitude

```text
u(T) = -dE_c/dH_c
     = C_c e_l^T M(T) [1,1]^T.
```

For the stable linear system,

```text
lim(T->0) u(T) = 0
lim(T->infinity) u(T) = S_r+S_l.
```

The long-window limit follows because a permanent shift in imposed `H_c`
eventually shifts both internal hydraulic storage coordinates by the same
amount. The complete internal SWAP storage sensitivity then becomes visible in
the integrated boundary exchange.

For the canonical system, `S_r+S_l=0.30`, and the frozen sweep is:

```text
T=0.01 d: u=0.0024695136748933825
T=0.10 d: u=0.022506009924084573
T=0.25 d: u=0.050498725157227996
T=0.50 d: u=0.089382422998800000
T=1.00 d: u=0.14936530755182925
T=2.00 d: u=0.22290940141598620
T=5.00 d: u=0.28966679608511900
T=10.0 d: u=0.29963723589847224.
```

This directly illustrates why a finite-window `u` cannot automatically be
named physical storage: it changes with the observation/coupling window while
the actual storages remain `S_r=0.20` and `S_l=0.10`.

## Boundary-trajectory memory

Substep equivalence requires preserving the same boundary trajectory, not only
its average.

Use zero external forcing and two half-day interface-head blocks with the same
time-average `8.0 m`.

Low then high:

```text
H_c = 7.95 m for 0.5 d
H_c = 8.05 m for 0.5 d
```

High then low reverses the order.

A single whole-window `H_c=8.0 m` is stationary and has `E_c=0`.

Frozen piecewise targets are:

```text
LOW -> HIGH:
h_r1 = 8.000568617927007 m
h_l1 = 8.013562533368873 m
E_c,total = -0.0014699769222886244 m

HIGH -> LOW:
h_r1 = 7.999431382072994 m
h_l1 = 7.986437466631127 m
E_c,total = +0.0014699769222885038 m.
```

Therefore equal mean `H_c` is not an exact replacement for a resolved
within-window head trajectory.

This does not invalidate a constant-head finite-window coupling contract.
It identifies the temporal approximation embedded in that contract and the
regime that later timestep qualification must bound.

## Relation to the one-state limit

If root-to-lower equilibration becomes infinitely fast while `C_c` remains
finite, the root and lower stores approach one combined internal hydraulic
storage `S=S_r+S_l` connected to `H_c`.

For the exact continuous-time oracle its response magnitude is

```text
u_cont(T)=S[1-exp(-C_c T/S)].
```

This is the continuous one-state physical limit.

The earlier NH01 finite-window formula

```text
u_IE(T)=S C_c T / (S+C_c T)
```

is the corresponding implicit-Euler one-step condensation, not the same time
integration rule. The distinction must be preserved. Agreement in physical
limiting structure does not make the two finite-window formulas identical.

## Falsification implications

RZM02 will fail scientifically if the frozen piecewise targets are not
reproduced, if either ordering violates mass conservation, if the response
coefficient does not approach the declared short/long-window limits, or if a
whole-window mean boundary head is falsely reported as exact for the
time-varying-head control.
