# RIBASIM-DUMMY-05 exact management complementarity

## Why DUMMY-05 exists

DUMMY-02 established that physical exchange is not silently curtailed to protect
managed demand. DUMMY-03 then made exchange Basin-level dependent. DUMMY-04
showed that the resulting linear temporal problem can have a nontrivial
iteration stiffness.

Those results make a purely sequential phrase such as "first hydrology, then
management" incomplete. Management withdrawal changes Basin level, and Basin
level changes groundwater exchange.

DUMMY-05 therefore solves the management priority rule and the head-dependent
exchange simultaneously, in closed form, before any numerical active-set or
fixed-point algorithm is tested.

## Frozen equations

The DUMMY-04 physical equations remain:

```text
V = C*dt*(((h0+h1)/2)-hgw)
h1 = h0 - (U+V)/A
```

where positive `V` is Basin-to-groundwater infiltration.

Management adds:

```text
0 <= U <= R
```

with request `R` and UserDemand minimum level `hmin`.

The management rule is:

- deliver the full request when the coupled full-demand solution remains at or
  above `hmin`;
- if the full request would cross `hmin`, reduce management delivery;
- if the coupled zero-withdrawal hydrology already reaches or crosses
  `hmin`, set management delivery to zero;
- do not use `hmin` to clip the physical exchange.

A separate physical datum `z0` remains a hard admissibility boundary for this
surrogate. If even the zero-withdrawal coupled solution lies below `z0`, the
problem fails closed because no dry-boundary physics has been defined.

## Fixed-delivery solution

From DUMMY-04,

```text
lambda = C*dt/(2A)
```

and, for any fixed delivery `U`,

```text
h1(U) =
  [(1-lambda)h0 + 2*lambda*hgw - U/A]
  / (1+lambda)
```

This function is monotone decreasing in `U`. Therefore the management active
set can be selected exactly without iteration.

## Exact regimes

### FULL

If

```text
h1(R) >= hmin
```

then

```text
U = R
```

and DUMMY-04 gives the exchange and end level.

### ZERO

Let `h1(0)` be the coupled physical solution without management withdrawal.
If

```text
h1(0) <= hmin
```

while remaining above the physical datum, then

```text
U = 0
```

The groundwater exchange is retained. The management minimum level is not a
physical boundary condition.

### CURTAILED

If

```text
h1(0) > hmin > h1(R)
```

then the active management constraint is

```text
h1 = hmin
```

so the physical exchange is

```text
V = C*dt*(((h0+hmin)/2)-hgw)
```

and the deliverable management volume is

```text
U = A*(h0-hmin) - V
```

By the regime conditions, this lies strictly between zero and the request.

## Why curtailment changes hydrology

Consider

```text
A       = 100 m2
C*dt    = 50 m2
h0      = 1.0 m
hgw     = 0.0 m
hmin    = 0.4 m
R       = 40 m3
```

The unconstrained full-demand coupled solution is:

```text
U = 40 m3
V = 32 m3
h1 = 0.28 m
```

It violates the management minimum level.

The constrained exact solution is:

```text
U = 25 m3
V = 35 m3
h1 = 0.40 m
```

Curtailment saves 15 m3 of managed withdrawal, but 3 m3 of that saving is
offset by additional infiltration because the Basin stays at a higher level.
Only 12 m3 appears as additional end storage:

```text
15 = 3 + 12
```

This is the sharper meaning of hydrology-before-management for a
state-dependent exchange: management is the adjustable quantity, but changing
management can alter the physical flux through the shared state.

## Continuity

At the FULL/CURTAILED boundary, `h1(R)=hmin`. The curtailed formula returns
exactly `U=R`, so delivery, exchange and level are continuous.

At the CURTAILED/ZERO boundary, `h1(0)=hmin`. The curtailed formula returns
exactly `U=0`, again giving continuous delivery, exchange and level.

The regime labels may change at the boundary, but the coupled physical solution
does not jump.

## Bound on the claim

DUMMY-05 is an exact active-set oracle for the frozen linear surrogate. It is
not:

- Ribasim's allocation optimizer;
- a production dry-boundary formulation;
- a MODFLOW package;
- an iterative coupling method;
- a production SWAP5 or iMOD Coupler change.

The next numerical question is whether an iterative coupling/active-set
algorithm finds this exact piecewise solution robustly, especially near regime
boundaries and for the stiff `lambda` cases identified in DUMMY-04.
