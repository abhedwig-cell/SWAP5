# RIBASIM-DUMMY-11 blocked concept: shared-state temporal memory

> Status: IMPLEMENTED after formal qualification of RIBASIM-DUMMY-10.
> The independent temporal reference below was derived while implementation was
> blocked. The DUMMY-11 implementation baseline was rebound to the qualified
> DUMMY-10 closeout before any DUMMY-11 model or tests were created.

## Question

DUMMY-10 combines one managed surface-water demand with two finite dynamic
storages. DUMMY-11 will ask what happens when that accepted two-head state is
propagated through multiple coupling windows.

The central distinction is:

- an internal exchange changes the partition of water between surface and
  groundwater;
- management withdrawal changes the combined storage;
- groundwater head produced in one accepted window changes the exchange
  gradient in the next window.

That last term is the minimal groundwater-memory mechanism in this analytical
dummy.

## Continuous full-demand reference

Let

```text
A_s dh_s/dt = -r - C(h_s-h_g)
A_g dh_g/dt =      C(h_s-h_g)
```

while the management request rate `r` is active.

Define the storage-weighted mean head

```text
m =
  (A_s h_s + A_g h_g)
  / (A_s + A_g)
```

and head difference

```text
d = h_s - h_g
```.

### Mean mode

Adding both storage equations gives

```text
(A_s+A_g) dm/dt = -r
```

so

```text
m(t) =
  m0 - r t/(A_s+A_g)
```.

Only external management withdrawal changes this combined-storage mode.

### Difference mode

Subtracting the head equations gives

```text
dd/dt =
  -r/A_s
  - C(1/A_s+1/A_g)d
```.

Define

```text
kappa =
  C(1/A_s+1/A_g)
```

and

```text
d_eq =
  -r/(A_s kappa).
```

Then

```text
d(t) =
  d_eq + (d0-d_eq) exp(-kappa t).
```

Recover the component heads from

```text
h_s =
  m + A_g/(A_s+A_g) d

h_g =
  m - A_s/(A_s+A_g) d.
```

This full-demand solution is independent of the discrete DUMMY-10 active-set
implementation.

## Management event

For the preregistered event domain, management remains at the requested rate
until the first root of

```text
h_s(t) - hmin = 0
```

inside the horizon.

Because the surface head in the canonical domain is monotone decreasing, this
root can be found independently by a bracketed scalar solve of the analytical
function above.

No DUMMY-10 fixed-window solver is needed to determine this event.

At the event:

```text
U_rate -> 0
```

but the internal exchange continues.

## Post-event reference

With management off,

```text
d/dt(A_s h_s + A_g h_g) = 0
```

so the mean head remains at its event value.

The difference mode becomes

```text
dd/dt = -kappa d
```

and therefore

```text
d(t) =
  d_hit exp[-kappa(t-t_hit)].
```

The component heads follow from the same weighted reconstruction.

This directly encodes the distinction already exposed in DUMMY-08:
`hmin` is a management threshold, not a physical floor. After management
shuts off, physical exchange can move the surface-water head below `hmin`.

## Canonical case

Use

```text
A_s = 100 m2
A_g = 100 m2
C   = 50 m2/time
h_s0 = 1.0 m
h_g0 = 0.0 m
r = 40 m3/time
hmin = 0.4 m
T = 1 time
```

Then

```text
m0 = 0.5 m
kappa = 1 / time
d_eq = -0.4 m
```

during full management.

Hence

```text
m(t) = 0.5 - 0.2 t

d(t) = -0.4 + 1.4 exp(-t)
```

and, for equal storage coefficients,

```text
h_s(t) =
  0.3 - 0.2 t + 0.7 exp(-t).
```

The first management event solves

```text
0.3 - 0.2 t + 0.7 exp(-t) = 0.4
```

giving the preregistered value

```text
t_hit ~= 0.909516342472789.
```

Cumulative management delivery is therefore

```text
U ~= 36.38065369891156 m3.
```

At the end of the horizon,

```text
h_s ~= 0.3929144878349753 m
h_g ~= 0.2432789751759090 m.
```

The internal exchange follows from the surface ledger:

```text
V =
  A_s(h_s0-h_s(T)) - U
  ~= 24.32789751759091 m3.
```

The combined system ledger is

```text
Delta(S_s+S_g) = -U
```

because `V` is internal.

## Contrast with fixed groundwater head

DUMMY-08 used the same surface parameters with groundwater head fixed at zero.

Its continuous event occurs at

```text
t_hit = 2 ln(1.5)
      ~= 0.8109302162
```

and cumulative delivery is approximately

```text
32.4372 m3.
```

The finite groundwater store in DUMMY-11 raises groundwater head as
infiltration occurs. That reduces the later exchange gradient, delays the
management shutoff, and makes more managed water available before the
threshold event.

This is the minimal analytical form of cross-window groundwater memory.

## Prequalification discrete expectations

These values are analytical preparation only and do not constitute DUMMY-11
qualification.

Using the exact DUMMY-10 per-window equations on equal partitions over the
canonical horizon gives approximately:

```text
N=1:
  cumulative U = 32.0000 m3
  cumulative V = 28.0000 m3
  h_s(T) = 0.4000
  h_g(T) = 0.2800

N=2:
  cumulative U = 34.6667 m3
  cumulative V = 25.3333 m3
  h_s(T) = 0.4000
  h_g(T) = 0.253333

N=16:
  cumulative U ~= 36.1333 m3
  h_s(T) ~= 0.395111
  h_g(T) ~= 0.243556

N=8192:
  cumulative U ~= 36.38041 m3
  h_s(T) ~= 0.3929168
  h_g(T) ~= 0.2432791
```

The last partition is close to the independent continuous reference but is not
treated as that reference.

As in DUMMY-08, active-set event alignment can produce small non-monotone
refinement effects. Qualification must therefore test convergence toward the
independent continuous solution without requiring every refinement level to
improve monotonically.

## Intended DUMMY-11 acceptance structure

After DUMMY-10 closed, DUMMY-11 implemented tests for:

1. exact two-head accepted-state chaining;
2. combined and component water ledgers;
3. analytical FULL-regime mean/difference recurrence;
4. independent continuous event reference;
5. fine-partition approach to that reference;
6. explicit comparison with DUMMY-08 fixed-head behavior;
7. post-shutoff exchange below the management threshold;
8. no shortage backlog;
9. approach to the fixed-head family as `A_g` grows.

The implementation baseline was rebound after DUMMY-10 qualification before
any DUMMY-11 code or tests were created.
