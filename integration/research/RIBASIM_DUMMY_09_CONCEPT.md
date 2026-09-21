# RIBASIM-DUMMY-09 reciprocal two-store exchange

## Purpose

All earlier head-dependent experiments treated groundwater head as externally
given within a coupling window. DUMMY-09 removes that simplification.

The physical exchange now connects two finite linear storages:

- one surface-water storage, representing the dummy Ribasim Basin;
- one groundwater storage, representing a deliberately minimal dynamic
  groundwater state.

The same exchange volume must be a loss on one side and a gain on the other.

No management is present in DUMMY-09. This work unit qualifies the shared
physical state before management is reintroduced.

## Continuous physical system

Let

```text
S_s = A_s h_s
S_g = A_g h_g
```

where `A_s` and `A_g` are linear storage coefficients with units of area.

Define positive exchange from surface water to groundwater:

```text
q = C (h_s - h_g)
```

The coupled ODEs are

```text
A_s dh_s/dt = -q
A_g dh_g/dt = +q
```

Hence total water is invariant:

```text
A_s h_s + A_g h_g = constant
```

The storage-weighted equilibrium head is

```text
H =
  (A_s h_s0 + A_g h_g0)
  / (A_s + A_g)
```

and remains constant.

## Shared head-difference mode

Define

```text
d = h_s - h_g
```

Then

```text
dd/dt =
  -C(1/A_s + 1/A_g)d
```

or

```text
d(t) = d0 exp(-kappa t)
kappa = C(1/A_s + 1/A_g)
```

The exact continuous head difference therefore approaches zero without
changing sign.

The individual heads follow from the conserved weighted equilibrium:

```text
h_s =
  H + [A_g/(A_s+A_g)] d

h_g =
  H - [A_s/(A_s+A_g)] d
```

This is the first dummy work unit in which the exchange changes both sides of
the shared state.

## Trapezoidal discrete exchange

For one coupling window of duration `dt`, freeze the temporal closure as

```text
V =
  C dt
  [(h_s0-h_g0) + (h_s1-h_g1)]
  / 2
```

with reciprocal state updates

```text
h_s1 = h_s0 - V/A_s
h_g1 = h_g0 + V/A_g
```

Define

```text
mu =
  0.5 C dt (1/A_s + 1/A_g)
```

Then the closed exchange volume is

```text
V =
  C dt (h_s0-h_g0)
  / (1+mu)
```

and the discrete head-difference amplification is

```text
g =
  d1/d0
  =
  (1-mu)/(1+mu)
```

This `mu` is not the DUMMY-04 one-sided `lambda`. Both storage responses
now contribute to the exchange mode.

## Three discrete regimes

### mu < 1

```text
0 < g < 1
```

The head difference decays without changing sign.

### mu = 1

```text
g = 0
```

The trapezoidal discrete step lands at equal heads in one window.

That is not the same as the exact continuous solution, which still has a
positive residual head difference after any finite time when `d0>0`.

### mu > 1

```text
-1 < g < 0
```

The discrete head ordering reverses even though the exact continuous system
does not cross.

Repeated equal steps alternate the head ordering while the magnitude decays.

This is a temporal-discretization artifact, not a conservation defect.

## Canonical stiff case

Use

```text
A_s = 100 m2
A_g = 100 m2
C   = 150 m2/time
dt  = 1
h_s0 = 1 m
h_g0 = 0 m
```

Then

```text
mu = 1.5
g  = -0.2
```

The exact trapezoidal exchange is

```text
V = 60 m3
```

so

```text
h_s1 = 0.4 m
h_g1 = 0.6 m
```

The heads cross.

The exact continuous mode has

```text
kappa = 3 / time
d(1) = exp(-3) ~= 0.0498 m
```

and therefore retains

```text
h_s > h_g
```

throughout.

For equal storages, the equilibrium head is 0.5 m, so the continuous endpoint
is approximately

```text
h_s ~= 0.5249 m
h_g ~= 0.4751 m
```

## Repeated stiff trapezoid steps

For the canonical `mu=1.5` case,

```text
d_n = (-0.2)^n d0
```

so the sequence is

```text
1,
-0.2,
0.04,
-0.008,
0.0016,
-0.00032,
...
```

Total storage remains exactly constant at every accepted step.

This is a useful coupling diagnostic because it shows that two properties can
coexist:

- exact reciprocal mass conservation;
- temporally implausible head-order oscillation caused by a coarse stiff step.

## Partitioning

If the same one-time-unit horizon is divided into four equal windows,

```text
dt = 0.25
mu = 0.375
```

and each substep has positive amplification.

The head ordering no longer reverses.

Further refinement approaches the exact continuous endpoint. DUMMY-09 tests
both the state and the integrated reciprocal exchange.

## Meaning of the groundwater storage coefficient

`A_g` is an equivalent linear storage coefficient used to expose the shared
state analytically.

It is not asserted to be:

- a MODFLOW cell area;
- specific yield by itself;
- confined storativity by itself;
- a package-specific MODFLOW state definition.

Mapping a real MODFLOW configuration onto the appropriate effective storage
response is a later coupling-contract question.

## Bounded claim

DUMMY-09 establishes the exact behavior of the frozen two-linear-store
research system only.

It changes no production code and makes no claim about the temporal integrator
used by MODFLOW, Ribasim or iMOD Coupler.
