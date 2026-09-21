# RIBASIM-DUMMY-19D blocked concept: heterogeneous real Ribasim realization

> Status: BLOCKED pending DUMMY-19C qualification.
>
> No DUMMY-19D executable model or verifier exists yet.

## Question

DUMMY-19C tests a deliberately common-factor case:

- both UserDemand nodes use the same source Basin;
- both use the same min_level;
- both are fully allocated.

That makes their physical reduction factors identical, so supplied flow remains
proportional to allocation.

DUMMY-19D asks the immediate falsification question:

> Does that proportionality disappear when the two fully allocated UserDemand
> nodes share the same source Basin but have different min_level values?

The pinned Ribasim physical equations predict that it should.

## Controlled change from DUMMY-19C

Keep unchanged:

- one 1 km2 Basin;
- initial level 1.0 m;
- fixed 60 m3/day inflow;
- allocation LevelDemand holding forecast level at 1.0 m;
- root demand 40 m3/day;
- external demand 20 m3/day;
- both claims fully allocated;
- one-day horizon;
- pinned Ribasim commit.

Change only:

```text
root min_level     = 0.990 m
external min_level = 0.995 m.
```

## Initial physical reduction

Pinned smooth threshold:

```text
t = 0.02 m.
```

Root:

```text
x_root = 1.000-0.990 = 0.010
phi_root = 0.5.
```

External:

```text
x_ext = 1.000-0.995 = 0.005
z = 0.005/0.02 = 0.25

phi_ext = (-2z+3)z^2
        = 0.15625.
```

Initial physical supplied rates are therefore

```text
root     = 40 * 0.5
         = 20 m3/day

external = 20 * 0.15625
         = 3.125 m3/day.
```

Already at the first instant:

```text
supplied_root : supplied_external
!=
allocated_root : allocated_external.
```

The DUMMY-19C common-factor proportional structure is therefore not expected to
generalize.

## Independent continuous reference

The Basin water balance is

```text
A dh/dtau
=
60
-
40 phi(h-0.990)
-
20 phi(h-0.995)
```

with tau in days and

```text
A = 1,000,000 m2.
```

Independent integration gives:

```text
final level
= 1.0000367990161128 m

root supplied
= 20.055236373645673 m3

external supplied
= 3.145747513661483 m3

total supplied
= 23.200983887307157 m3

storage gain
= 36.799016112754046 m3.
```

Ledger:

```text
23.2009838873
+
36.7990161128
=
60 m3.
```

Final reduction factors are approximately

```text
root     = 0.5027599137504485
external = 0.1583250103267847.
```

## Priority reversal

Both demands remain fully allocated in both priority orders.

Therefore demand_priority is not expected to change:

- allocated root;
- allocated external;
- physical root supply;
- physical external supply;
- Basin trajectory.

This isolates physical source-state reduction from management priority.

## Scientific interpretation

If DUMMY-19D matches the pinned equations:

- DUMMY-19C proportionality is confirmed as a special common-factor case;
- real Ribasim realization is link/source-state specific;
- one scalar post-allocation reduction factor is not a general representation
  of physical realization;
- future SWAP-Ribasim coupling must use actual supplied transfer per managed
  path rather than reconstructing it from allocation totals.

## Boundary

This still does not test:

- different source Basins;
- partial allocation;
- network reallocation after physical shortfall;
- SWAP irrigation realization;
- MODFLOW coupling.

Those remain later controlled substitutions.
