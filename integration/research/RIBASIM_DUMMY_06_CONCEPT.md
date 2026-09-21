# RIBASIM-DUMMY-06 active-set Picard iteration

## Purpose

DUMMY-05 provides an exact coupled oracle for three management regimes:

- FULL;
- CURTAILED;
- ZERO.

DUMMY-06 asks whether a simple coupling algorithm that applies the same
management clipping rule at every Picard iterate necessarily converges to that
oracle.

It does not.

The work unit separates two ideas that are easy to conflate:

1. every individual provisional state can obey the local management priority;
2. the sequence of provisional states can still fail to converge to the
   coupled solution.

## Naive active-set map

Let `V_n` be the current groundwater-exchange guess.

With Basin area `A`, start level `h0`, management minimum level `hmin`
and request `R`, the managed volume that would still fit above the minimum
level under the frozen exchange guess is

```text
U_cap = A*(h0-hmin) - V_n
```

The provisional management delivery is clipped locally:

```text
U_n = min(R, max(0, U_cap))
```

The provisional end level is

```text
h1_n = h0 - (U_n + V_n)/A
```

and the groundwater exchange is updated with the DUMMY-04 trapezoidal relation:

```text
V_(n+1) = C*dt*(((h0+h1_n)/2)-hgw)
```

The provisional active set is therefore:

```text
FULL       if U_cap >= R
CURTAILED  if 0 < U_cap < R
ZERO       if U_cap <= 0
```

## Exact fixed points

Every admissible DUMMY-05 oracle solution is a fixed point of this map.

In a FULL or ZERO region, management delivery is locally constant. The exchange
map therefore has the same derivative as DUMMY-04:

```text
dV_(n+1)/dV_n = -lambda
lambda = C*dt/(2A)
```

In the interior CURTAILED region, clipping enforces

```text
h1_n = hmin
```

for every exchange guess in that region. Therefore the next exchange is the
constant

```text
V_(n+1) = C*dt*(((h0+hmin)/2)-hgw)
```

which is exactly the curtailed exchange from DUMMY-05.

This local property does not guarantee that the next iterate remains in the
same active set.

## Preregistered stiff counterexample

Use:

```text
A     = 100 m2
C     = 300 m2/time
dt    = 1
h0    = 1.0 m
hgw   = 0.8 m
hmin  = 0.2 m
R     = 50 m3
lambda = 1.5
```

The exact DUMMY-05 solution is FULL:

```text
U*  = 50 m3
V*  = -6 m3
h1* = 0.56 m
```

The explicit start-level exchange is

```text
V0 = C*dt*(h0-hgw) = 60 m3
```

The active-set iteration then gives:

```text
V0 =  60  -> CURTAILED -> V1 = -60
V1 = -60  -> FULL      -> V2 =  75
V2 =  75  -> CURTAILED -> V3 = -60
```

and the sequence enters the two-cycle

```text
-60, 75, -60, 75, ...
```

The exact fixed point `V*=-6` is never reached.

Both cycle states obey their own local management clipping rule and Basin
balance. The failure is therefore not a local rule violation. It is failure of
the undamped coupled iteration.

## Timestep control case

Keep the same physical parameters but set

```text
dt = 0.2
```

so

```text
lambda = 0.3
```

The explicit initial exchange now lies in the FULL regime and the sequence
remains there. Its error follows

```text
e_(n+1) = -0.3 e_n
```

and converges to the exact DUMMY-05 FULL solution.

This demonstrates a numerical mechanism, not a universal production timestep
rule.

## Meaning for the coupling research

DUMMY-06 makes the management statement more precise.

A coupler can satisfy all of these at every provisional evaluation:

- physical exchange is not clipped for management;
- managed withdrawal remains between zero and request;
- provisional Basin balance closes;
- management minimum level is respected whenever management is active;

and still fail to find the coupled solution.

The next problem is therefore algorithmic: can damping, a direct active-set
solve, or a Newton/secant-like update recover the DUMMY-05 oracle robustly
across the stiff regime-switch cases?

## Bounded claim

DUMMY-06 concerns one deliberately naive, undamped active-set Picard map. It is
not evidence about the actual algorithms used by Ribasim, MODFLOW or iMOD
Coupler, and it changes no production code.
