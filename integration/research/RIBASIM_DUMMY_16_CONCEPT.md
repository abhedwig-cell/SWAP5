# RIBASIM-DUMMY-16 blocked concept: management-clock event semantics

> Status: BLOCKED pending DUMMY-15B qualification.
>
> This work unit has no implementation or tests. It exists to isolate one
> specific question before asynchronous production clocks are discussed.

## Question

Can two coupling schedules have:

- the same physical windows;
- the same total managed withdrawal in every physical window;
- the same surface-groundwater exchange;
- the same surface and groundwater endpoint;

yet produce different future hydrological demand solely because one management
clock observes a priority event and the other does not?

DUMMY-16 is designed so the answer is analytically testable.

## Why this is different from DUMMY-08

DUMMY-08 showed that changing physical window partition can change management
outcome even with exact mass conservation.

DUMMY-16 first stage holds physical partition fixed.

Both schedules use:

```text
dt_1 = 0.5
dt_2 = 0.5.
```

The only changed object is the sampled management priority.

Therefore any difference cannot be attributed to physical timestep size.

## Shared physical configuration

```text
A_s = 100
A_g = 100
C = 50

h_s0 = 1
h_g0 = 0

hmin = 0.2
datum = 0.
```

Root bucket:

```text
W_root0 = 40
W_target = 80
W_capacity = 100.
```

External managed demand is 20 m3 per half-window.

For this controlled clock experiment the submitted root claim is capped at
20 m3 per half-window.

That cap is an experiment input, not a production SWAP scheduling rule.

## Priority event

The intended priority schedule is:

```text
0 <= t < 0.5:
  ROOT_FIRST

0.5 <= t <= 1:
  EXTERNAL_FIRST.
```

Two management clocks are compared.

### Fast / event-synchronized

The management layer samples priority at:

```text
t=0
t=0.5.
```

It therefore observes the priority change.

### Stale

The management layer samples only at:

```text
t=0
```

and holds ROOT_FIRST through the complete horizon.

The physical layer still executes the same two half-windows.

## Window 1

Submitted demands:

```text
root = 20
external = 20
total = 40.
```

The exact two-store management solution is FULL:

```text
M_1 = 40
V_1 = 16

h_s1 = 0.44
h_g1 = 0.16.
```

Both claims are fully supplied, so priority is irrelevant in this first window.

Root storage becomes

```text
W_root1 = 60.
```

The physical remaining root deficit is therefore

```text
20.
```

Thus the second-window root request of 20 is consistent with accepted root
state.

## Window 2 shared physics

Again:

```text
R_root = 20
R_ext = 20
R_total = 40.
```

From

```text
h_s = 0.44
h_g = 0.16
```

the exact physical solution is CURTAILED:

```text
M_2 = 20.444444444444443
V_2 = 3.555555555555556

h_s2 = 0.2
h_g2 = 0.19555555555555557.
```

This exact total and physical endpoint are common to both clock schedules.

## Fast clock outcome

The t=0.5 priority event is observed.

Second-window split:

```text
external = 20
root = 0.44444444444444287.
```

Final root storage:

```text
60 + 0.44444444444444287
= 60.44444444444444.
```

Next root demand:

```text
80 - 60.44444444444444
= 19.555555555555557.
```

Cumulative external delivery:

```text
20 + 20 = 40.
```

## Stale clock outcome

ROOT_FIRST is incorrectly retained across the priority event.

Second-window split:

```text
root = 20
external = 0.44444444444444287.
```

Final root storage:

```text
60 + 20 = 80.
```

Next root demand:

```text
0.
```

Cumulative external delivery:

```text
20 + 0.44444444444444287
= 20.444444444444443.
```

## What remains identical

Both schedules have exactly the same:

- physical window boundaries;
- total managed request per physical window;
- total physically realized managed withdrawal;
- V in each window;
- surface head trajectory;
- groundwater head trajectory.

Final shared water state is therefore identical:

```text
h_s = 0.2
h_g = 0.19555555555555557.
```

## What changes

Only recipient identity changes in the second window.

That changes:

- root storage;
- future root irrigation demand;
- cumulative external system loss.

Hence a management-clock choice can change later hydrological demand even when
the shared surface/groundwater physical trajectory is identical.

## Conservation does not select a clock

Fast clock:

```text
Delta(total represented root+surface+groundwater)
= -40
```

because 40 m3 is supplied externally.

Stale clock:

```text
Delta(total represented root+surface+groundwater)
= -20.444444444444443.
```

Both are correct for their own supplied-flow histories.

Exact conservation therefore cannot tell us which management clock semantics
is intended.

That requires an explicit coupling contract.

## Later extensions

After this first stage qualifies, progressively add:

1. a priority event not aligned with a physical-window boundary;
2. explicit event subdivision;
3. a root-demand refresh clock separate from priority clock;
4. Ribasim allocation timestep separate from physical solver timestep;
5. SWAP state-update timestep;
6. MODFLOW timestep;
7. outer coupler commit window.

Do not introduce all clocks at once.

## Boundary

This experiment does not decide the production clock policy.

It provides an exact falsification case that any proposed SWAP-Ribasim-MODFLOW
clock contract must reproduce or explicitly reject.
