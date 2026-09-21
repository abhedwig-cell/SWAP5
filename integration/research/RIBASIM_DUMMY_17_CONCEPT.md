# RIBASIM-DUMMY-17 blocked concept: two Basins with shared groundwater

> Status: BLOCKED pending qualification of DUMMY-16.
>
> No DUMMY-17 implementation or tests are authorized yet.

## Why this is the next spatial step

The one-Basin experiments can establish:

- state ownership;
- reciprocal surface-groundwater exchange;
- management complementarity;
- allocation versus supply;
- clock semantics.

They cannot show how the same water can move between spatially distinct surface
locations through two different physical pathways.

DUMMY-17 introduces the smallest topology that can:

```text
Basin 1 ----surface routing----> Basin 2
   \                             /
    \                           /
     ---- shared groundwater ----
```

The first stage has no management.

That is deliberate.

Before a routed network is allowed to compete for managed water, the physical
path ledger itself must be exact.

## State

Use three dynamic heads:

```text
h_1  upstream Basin
h_2  downstream Basin
h_g  shared groundwater.
```

Surface Basin storages are

```text
S_1 = A h_1
S_2 = A h_2
```

and groundwater storage is

```text
S_g = A_g h_g.
```

## Surface route

Define

```text
Q_r = K_r (h_1-h_2).
```

Positive means Basin 1 to Basin 2.

This is an analytical linear routing surrogate.

It is not claimed to reproduce a Ribasim routing element.

## Surface-groundwater exchanges

For Basin 1:

```text
Q_1g = C(h_1-h_g).
```

For Basin 2:

```text
Q_2g = C(h_2-h_g).
```

Positive means Basin to groundwater.

Negative therefore means groundwater drainage into the Basin.

## Component equations

```text
A dh_1/dt
  = -Q_r-Q_1g

A dh_2/dt
  = +Q_r-Q_2g

A_g dh_g/dt
  = +Q_1g+Q_2g.
```

Adding them gives

```text
d(S_1+S_2+S_g)/dt = 0.
```

Both routing and both groundwater exchanges are internal.

## Why total conservation is not enough

Imagine an implementation that accidentally sends too much water through the
surface route and too little through groundwater, while compensating the two
errors so total storage still closes.

A total balance would pass.

The physical pathway decomposition would be wrong.

DUMMY-17 therefore requires both:

1. total-system conservation;
2. transfer-by-transfer/pathway agreement.

This is directly relevant to a future Ribasim-MODFLOW network coupling.

## Exact mode decomposition

Define the surface head difference

```text
d = h_1-h_2
```

and surface mean

```text
m = (h_1+h_2)/2.
```

The difference mode obeys

```text
d'
  = -[(2K_r+C)/A] d.
```

Thus

```text
d(t)
  = d_0 exp[-(2K_r+C)t/A].
```

Now define the common surface-groundwater contrast

```text
x = m-h_g.
```

Then

```text
x'
  = -C(1/A+2/A_g)x.
```

The routing term disappears from this common mode.

This separation is useful because it identifies two physically distinct
relaxation mechanisms:

- redistribution between surface Basins;
- redistribution between mean surface water and groundwater.

## Canonical case

Use

```text
A = 100
A_g = 100
C = 50
K_r = 20

h_1(0) = 1
h_2(0) = 0
h_g(0) = 0.4.
```

Initial total storage:

```text
100*1 + 100*0 + 100*0.4
= 140.
```

### Initial direct surface route

```text
Q_r
  = 20(1-0)
  = 20.
```

### Initial Basin-1 groundwater exchange

```text
Q_1g
  = 50(1-0.4)
  = 30.
```

Basin 1 loses 30 to groundwater.

### Initial Basin-2 groundwater exchange

```text
Q_2g
  = 50(0-0.4)
  = -20.
```

Groundwater supplies Basin 2 at 20.

Hence Basin 2 initially receives:

```text
20 by direct surface routing
20 by groundwater drainage.
```

The two pathways are equal at t=0.

Basin 1 storage rate:

```text
-20-30 = -50.
```

Basin 2 storage rate:

```text
+20-(-20) = +40.
```

Groundwater storage rate:

```text
+30-20 = +10.
```

Combined:

```text
-50+40+10 = 0.
```

## Exact modes for the canonical case

Surface difference:

```text
d_0 = 1
```

and

```text
(2K_r+C)/A
  = (40+50)/100
  = 0.9.
```

Therefore

```text
d(t)=exp(-0.9t).
```

Initial surface mean:

```text
m_0=0.5
```

so

```text
x_0 = m_0-h_g0
    = 0.1.
```

Common-mode decay rate:

```text
C(1/A+2/A_g)
  = 50(0.01+0.02)
  = 1.5.
```

Hence

```text
x(t)
  = 0.1 exp(-1.5t).
```

Conserved weighted storage gives

```text
2m+h_g = 1.4.
```

Therefore

```text
m(t)
  = 1.4/3
    + (0.1/3) exp(-1.5t)

h_g(t)
  = 1.4/3
    - (0.2/3) exp(-1.5t).
```

Finally

```text
h_1(t)=m(t)+0.5exp(-0.9t)

h_2(t)=m(t)-0.5exp(-0.9t).
```

At t=1:

```text
h_1 = 0.6773891685419139
h_2 = 0.2708195088013148
h_g = 0.45179132265677135.
```

Total storage remains exactly 140.

## Scientific use

This system can falsify at least four coupling errors independently:

1. wrong surface-route sign or ownership;
2. wrong Basin-1 groundwater transfer;
3. wrong Basin-2 groundwater transfer;
4. correct total balance obtained through compensating pathway errors.

The exact modal solution also gives a continuous reference for later
partitioned numerical coupling.

## Why management is deferred

Adding UserDemand now would make a downstream water-delivery result depend on:

- physical routing;
- groundwater redistribution;
- allocation;
- realization policy;
- clock semantics.

That would be too many degrees of freedom at once.

The first DUMMY-17 stage therefore closes the physical network alone.

Only then should a downstream root demand be added.

## Later real-model bridge

A controlled substitution can then proceed:

1. analytical two-Basin + analytical groundwater;
2. real Ribasim two-Basin routing + analytical groundwater;
3. real Ribasim + controlled MODFLOW;
4. finally add analytical root demand;
5. only later replace the root proxy with real SWAP authority.

At each substitution, transfer-by-transfer agreement should be checked before
network-level management is introduced.

## Boundary

DUMMY-17 does not establish:

- Ribasim routing equivalence;
- MODFLOW storage/package equivalence;
- production network allocation;
- production SWAP demand;
- production coupling timing.

It is an exact network-physics oracle only.
