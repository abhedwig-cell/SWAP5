# RIBASIM-DUMMY-20H: active exchange at the current management boundary

> Status: PREREGISTERED after DUMMY-20G qualification.

This is the causal time-direction complement to DUMMY-20E3.

DUMMY-20E3 established:

```text
SOLVE at t=0
then groundwater arrives
=> physical state changes
=> current allocation does not change retroactively
```

DUMMY-20H reverses only that ordering by using the active-River product path:

```text
accepted Ribasim stage
-> MF6 active-River solve
-> Ribasim infiltration is published
-> Ribasim fixed-grid allocation SOLVE at t=0
-> physical realization
```

The no-exchange control has 32 m3/day available and therefore allocates 32/0
to root/external demand.

DUMMY-20G qualified the first active-River infiltration as
7.999914667576883 m3/day. Because the product-release allocator treats Basin
infiltration as a negative forcing and the priority-1 LevelDemand holds the
Basin at 1.0 m, the frozen active-case prediction is:

```text
root allocation     = 32 - 7.999914667576883
                    = 24.000085332423117 m3/day
external allocation = 0 m3/day
```

The allocation is read from the real Ribasim allocation output. Physical supply
is checked separately.

A pass establishes an explicit time-direction rule:

```text
forcing before SOLVE  -> visible to current management decision
forcing after SOLVE   -> physical memory only until next management boundary
```
