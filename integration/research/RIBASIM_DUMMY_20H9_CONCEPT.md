# RIBASIM-DUMMY-20H9

## Question

Does the actual pinned RibaMod product admit current positive groundwater
forcing at the next fixed allocation boundary in addition to accepted storage
memory?

H7 closed the negative active-River direction. H9 freezes the complementary
positive groundwater direction using the already qualified two-cell passive
Drainage topology from DUMMY-20F2.

## Discriminating t=24 alternatives

Accepted day-1 memory is:

```text
M = 21.97488887434318 m3
```

The current positive groundwater forcing is:

```text
G = 7.999872002047973 m3/day
```

If the t=24 forecast used accepted memory but omitted current positive forcing,
the priority allocation would be:

```text
root = 40
external = 13.97488887434318 m3/day
```

If current positive drainage is admitted as the v2026.1.1 source contract
indicates, the available budget exceeds total managed demand and the recorded
allocation is:

```text
root = 40
external = 20 m3/day
```

The allocation record, not physical supply alone, is the authority.

## Boundary

This is a product bridge for one passive-Drainage topology. It does not imply
that every positive forcing process or arbitrary network has identical
allocation semantics.
