# RIBASIM-DUMMY-14 blocked concept: three-store forcing and demand memory

> Status: BLOCKED pending formal qualification of RIBASIM-DUMMY-13.
>
> DUMMY-14 has no model or tests yet. This document fixes the intended physical
> and accounting interpretation before implementation authority exists.

## Why DUMMY-14 is needed

DUMMY-13 isolates the cleanest possible three-store ledger:

- root storage;
- surface-water storage;
- groundwater storage;
- irrigation transfer U;
- surface-groundwater exchange V.

With no external forcing, both U and V are internal and total three-store water
is invariant.

That case is essential, but it has one special property:

```text
next root deficit = current irrigation shortage
```

whenever the current root request is partially supplied.

That equality is not generally true.

It appears only because DUMMY-13 intentionally has no rainfall, root-zone loss
or drainage.

DUMMY-14 adds those external root-zone terms so current management shortage and
future physical demand can separate.

## Frozen decision order

For one coupling window:

1. start from committed root, surface and groundwater state;
2. derive the root request from committed root storage

```text
R = max(0, W_target-W_r0);
```

3. freeze R for the current window;
4. solve the surface/groundwater management problem for U and V;
5. apply U to the root zone together with external root forcing;
6. apply capacity drainage if needed;
7. accept all three endpoint states together;
8. derive the next request from accepted root storage.

Same-window rainfall or atmospheric loss does not retroactively rewrite the
already issued current request.

This is a deliberate decision-timing contract.

## Component balances

Let

```text
P = root-zone rainfall input
E = prescribed root-zone external loss
D = root-zone capacity drainage
```

with all three non-negative.

The root balance is

```text
Delta W_r = U + P - E - D.
```

Surface water remains

```text
Delta S_s = -U - V.
```

Groundwater remains

```text
Delta S_g = +V.
```

Adding the three:

```text
Delta(W_r+S_s+S_g)
  = P - E - D.
```

The internal transfers still cancel:

```text
+U - U = 0

-V + V = 0.
```

External root forcing remains visible in the system ledger.

## Canonical coupled supply remains unchanged

Start with the DUMMY-13 canonical state:

```text
W_r0 = 40
W_target = 80
W_capacity = 100

h_s0 = 1.0
h_g0 = 0.0

A_s = A_g = 100
C = 50
dt = 1
hmin = 0.4.
```

The start-of-window request is

```text
R = 40.
```

The already preregistered coupled surface/groundwater solution is

```text
U = 32
shortage = 8
V = 28
h_s1 = 0.4
h_g1 = 0.28.
```

DUMMY-14 does not change those values merely because root forcing exists later
in the same window. The root forcing changes the accepted root endpoint and
therefore the next request.

## Case 1: rain erases the next demand

Add

```text
P = 20
E = 0.
```

The root endpoint is

```text
W_r1 = 40 + 32 + 20 = 92.
```

There is current management shortage:

```text
shortage = 8.
```

But the next physical demand is

```text
R_next = max(0,80-92) = 0.
```

Therefore

```text
current shortage = 8
next request = 0.
```

An 8 m3 backlog state would be physically wrong for this analytical system.

### Combined ledger

Initial total:

```text
40 + 100 + 0 = 140.
```

Final total:

```text
92 + 40 + 28 = 160.
```

Hence

```text
Delta total = +20 = P.
```

Irrigation and groundwater exchange still cancel internally.

## Case 2: external loss amplifies the next deficit

Instead use

```text
P = 0
E = 10.
```

The same current management solution still has

```text
U = 32
shortage = 8.
```

But now

```text
W_r1 = 40 + 32 - 10 = 62
```

so

```text
R_next = 80 - 62 = 18.
```

Therefore

```text
current shortage = 8
next request = 18.
```

The next demand is larger than the current shortage because new physical water
loss occurred after the request was formed.

This is the opposite of the rainfall case.

Together the two cases demonstrate:

```text
shortage != physical demand memory.
```

## Case 3: root capacity drainage

Use

```text
W_r0 = 90
W_target = 90
W_capacity = 100
P = 25
E = 5.
```

There is no irrigation request:

```text
R = U = 0.
```

Before drainage:

```text
W_raw = 90 + 25 - 5 = 110.
```

Therefore

```text
D = 10
W_r1 = 100.
```

The combined system gains

```text
P-E-D = 25-5-10 = 10.
```

Capacity drainage remains in the combined ledger because it leaves the
represented three-store boundary.

## Why the timing choice matters

Another possible model could let expected rainfall reduce the irrigation
request before allocation.

DUMMY-14 does **not** do that.

Its current request is derived from committed start state and remains fixed
during the decision window.

That is not claimed to be the production SWAP/Ribasim timing rule.

It is a controlled hypothesis that lets us distinguish:

- demand-state semantics;
- coupling-window timing;
- external forcing;
- internal transfer accounting.

A later real-model binding must establish actual production timing.

## Relation to shortage

DUMMY-14 intentionally permits three outcomes from the same current shortage:

```text
shortage 8 + rain 20
  -> next request 0

shortage 8 + no forcing
  -> next request 8

shortage 8 + external loss 10
  -> next request 18.
```

The current shortage is identical.

Only physical state evolution differs.

This is a strong falsification case for any coupling design that carries
shortage as if it were equivalent to unsatisfied physical water demand.

## Multi-window implication

Across multiple accepted windows:

```text
W_N + S_s,N + S_g,N
-
(W_0 + S_s,0 + S_g,0)

=
sum(P) - sum(E) - sum(D).
```

Neither cumulative irrigation nor cumulative surface-groundwater exchange
appears in the combined ledger because both are internal transfers.

This will be the primary multi-window conservation gate.

## Production-authority boundary

DUMMY-14 keeps three important limits explicit.

### SWAP demand

The root bucket is not the production SWAP irrigation algorithm.

Actual SWAP demand ownership, units, state basis and timing remain to be bound.

### Storage partition

The dummy stores remain disjoint by construction.

The experiment cannot close real F-GC CSR-B1 storage partition.

### Drainage ownership

The capacity drainage D in DUMMY-14 is an explicitly owned analytical bucket
sink.

It is not mapped onto SWAP, MODFLOW or surface-water drainage and cannot close
CSR-B2.

## Implementation gate

No DUMMY-14 implementation may be created until DUMMY-13 qualifies.

After that closeout, the implementation baseline must be rebound before code
or tests are added.
