# RIBASIM-DUMMY-10 management with dynamic groundwater storage

## Purpose

DUMMY-09 qualified reciprocal exchange between two finite linear storages.
DUMMY-10 reintroduces one managed surface-water demand.

This makes the original conflict problem fully shared-state within the dummy:

- management withdrawal changes surface-water head;
- surface-water head changes exchange;
- exchange changes groundwater head;
- groundwater-head response changes the same exchange.

The problem remains piecewise linear and can therefore be solved exactly.

## Frozen two-store equations

For one window:

```text
h_s1 = h_s0 - (U+V)/A_s
h_g1 = h_g0 + V/A_g
```

with positive `V` from surface water to groundwater.

The trapezoidal exchange is

```text
V =
  C dt
  [(h_s0-h_g0) + (h_s1-h_g1)]
  / 2
```

Management is constrained by

```text
0 <= U <= R
```

and the surface-water UserDemand threshold `hmin`.

The threshold constrains management withdrawal. It does not clip exchange.

## Fixed-delivery solution

Define

```text
mu =
  0.5 C dt (1/A_s + 1/A_g)
```

and

```text
B = C dt / (1+mu)
```

For any fixed delivery `U`,

```text
V(U) =
  B[(h_s0-h_g0) - U/(2A_s)]
```

Then

```text
h_s1(U) = h_s0 - [U+V(U)]/A_s
h_g1(U) = h_g0 + V(U)/A_g
```

The surface endpoint is affine and monotone in `U`. FULL, CURTAILED and ZERO
management regimes can therefore again be selected without numerical
iteration.

## CURTAILED solution

When

```text
h_s1(0) > hmin > h_s1(R)
```

activate

```text
h_s1 = hmin
```

Let

```text
alpha = B/(2A_s)
```

Then

```text
U =
  [A_s(h_s0-hmin) - B(h_s0-h_g0)]
  / (1-alpha)
```

and

```text
V =
  B[(h_s0-h_g0)-U/(2A_s)]
```

Because groundwater head is now dynamic, this solution generally differs from
the DUMMY-05 fixed-head case.

## Canonical finite-groundwater case

Use

```text
A_s = 100 m2
A_g = 100 m2
C   = 50 m2/time
dt  = 1
h_s0 = 1.0 m
h_g0 = 0.0 m
hmin = 0.4 m
R = 40 m3
```

Then

```text
mu = 0.5
B = 100/3 m2
```

and the exact constrained solution is

```text
regime = CURTAILED
U = 32 m3
V = 28 m3
h_s1 = 0.40 m
h_g1 = 0.28 m
shortage = 8 m3
```

The combined storage ledger is

```text
initial:
  100*1.0 + 100*0.0 = 100 m3

final:
  100*0.4 + 100*0.28 = 68 m3

loss:
  32 m3 = U
```

Internal exchange disappears from the combined ledger because the 28 m3 lost
by surface water is the same 28 m3 gained by groundwater.

## Comparison with DUMMY-05 fixed groundwater head

For the same surface-water parameters, but with groundwater head fixed at
zero, DUMMY-05 gives

```text
U = 25 m3
V = 35 m3
h_s1 = 0.40 m
```

The finite groundwater store therefore allows more management delivery in the
canonical case.

Why?

The 28 m3 of infiltration raises groundwater head to 0.28 m. That reduces the
surface-groundwater gradient during the coupling window and suppresses further
infiltration.

Holding groundwater head at zero removes that feedback and produces 35 m3
infiltration instead.

## Groundwater-storage family

The fixed-head problem is recovered as the groundwater storage coefficient
becomes very large.

For the canonical parameter family:

- small `A_g`: groundwater head responds strongly, suppressing infiltration;
- large `A_g`: groundwater head responds weakly;
- `A_g -> infinity`: groundwater head is effectively fixed and DUMMY-05 is
  recovered.

The preregistered storage family therefore links the earlier one-sided dummy
and the new two-sided shared-state dummy in one analytical continuum.

For example, the canonical family moves approximately as follows:

```text
A_g = 20      -> U = 40, V = 16
A_g = 50      -> U ~= 36.67, V ~= 23.33
A_g = 100     -> U = 32, V = 28
A_g = 200     -> U ~= 28.89, V ~= 31.11
A_g = 1000    -> U ~= 25.85, V ~= 34.15
A_g -> inf    -> U = 25, V = 35
```

The regime itself can change along this family: a sufficiently responsive
groundwater store can make the full management request feasible.

## Combined versus component balances

Three ledgers must be distinguished:

Surface water:

```text
Delta S_s = -U - V
```

Groundwater:

```text
Delta S_g = +V
```

Combined system:

```text
Delta(S_s+S_g) = -U
```

This is the shared-state accounting contract we eventually want a real
Ribasim-MODFLOW coupling to make auditable.

## Physical floor

If the zero-management coupled physical solution would put the surface store
below its datum, DUMMY-10 fails closed.

Management clipping cannot repair a physical exchange set that is already
infeasible without management.

No dry-surface or disconnected-exchange physics is invented here.

## Bound on the result

DUMMY-10 remains a two-linear-store analytical oracle. In particular:

- `A_g` is not yet mapped to a MODFLOW storage package;
- no Ribasim network allocation is represented;
- no SWAP root-zone demand feedback is added;
- no production coupling or timestep rule is changed.

Its purpose is to expose, exactly, how finite groundwater storage changes the
management-versus-exchange conflict through the shared heads.
