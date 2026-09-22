# RIBASIM-DUMMY-20H8

## Question

Does the allocation forecast treat equal-magnitude current groundwater inflow
and outflow symmetrically?

The source contract says no. In Ribasim v2026.1.1, Basin drainage is explicit
positive forcing on the allocation balance, while Basin infiltration is
implicit negative forcing multiplied by the LP `low_storage_factor`.

H8 tests that distinction on the same accepted t=24 state qualified by H6/H7.

## Frozen comparison

```text
accepted memory M = 7.9903723811 m3
fixed source       = 32 m3/day
forcing magnitude  = 8.0000425122 m3/day
```

No forcing:

```text
root = 39.9903723811
external = 0
```

Negative infiltration, free alpha:

```text
alpha = 0
root = 39.9903723811
external = 0
```

Positive drainage:

```text
root = 40
external = 7.9904148933
```

A PASS establishes a direction-sensitive forecast contract for this topology.
It does not imply that physical groundwater exchange itself is asymmetric or
non-conservative.
