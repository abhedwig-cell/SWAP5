# RIBASIM-DUMMY-19B: pinned real Ribasim priority conflict

## Status

Implementation follows qualified DUMMY-19A observability authority.

This work unit replaces the analytical DUMMY-15 allocation oracle with a
pinned real Ribasim allocation solve while deliberately keeping physical
UserDemand reduction inactive.

## Scientific question

Can pinned real Ribasim reproduce the central DUMMY-15 invariant:

> changing only managed-demand priority changes the recipient split, while
> total managed supply and the shared surface-water trajectory remain the same?

This is not yet the allocation-versus-realization conflict. That comes later.

## Why DUMMY-19A had to come first

DUMMY-19A established executable observability for:

- `demand`;
- `allocated`;
- physical UserDemand inflow;
- lagged `supplied` output;
- route-priority flow.

DUMMY-19B can therefore compare management allocation with physical flow
without treating allocation as water merely because it is an optimizer result.

## Controlled scarce source

One Basin starts at:

```text
level = 1 m
area = 1000 m2
storage = 1000 m3.
```

A FlowBoundary supplies exactly:

```text
32 m3/day.
```

It would be invalid to let the allocator also spend the 1000 m3 initial Basin
storage, because then the test would not represent the DUMMY-15 capacity of
32 m3/day.

Therefore a LevelDemand with the highest demand priority fixes:

```text
h_min = h_max = 1 m.
```

Its lexicographically earlier objective requires zero Basin storage change.

The two UserDemands can therefore divide only the fixed 32 m3/day inflow.

## Managed claims

Root proxy:

```text
demand = 40 m3/day.
```

External demand:

```text
demand = 20 m3/day.
```

Both have:

```text
return_factor = 0
min_level = 0 m.
```

The Basin stays at 1 m and has storage far above the low-storage threshold.

Thus the physical UserDemand factors are intentionally inactive:

```text
low_storage_factor = 1
min_level_reduction = 1
```

within numerical tolerance.

This makes physical supplied flow equal the allocator target if the
allocation is physically realizable.

## Priority direction

Pinned Ribasim collects demand priorities and sorts them ascending.

The allocation objectives are then solved lexicographically in that order.
After each retained objective is solved, its optimum is constrained before the
next objective is optimized.

Therefore lower integer means earlier/higher priority in this controlled
bridge.

Priority 1 is reserved for the Basin level hold.

## ROOT_FIRST case

```text
LevelDemand priority = 1
root priority        = 2
external priority    = 3.
```

Expected:

```text
allocated root     = 32 m3/day
allocated external = 0

supplied root      = 32 m3/day
supplied external  = 0

Basin level        = 1 m.
```

## EXTERNAL_FIRST case

```text
LevelDemand priority = 1
external priority    = 2
root priority        = 3.
```

Expected:

```text
allocated external = 20 m3/day
allocated root     = 12 m3/day

supplied external  = 20 m3/day
supplied root      = 12 m3/day

Basin level        = 1 m.
```

## Independent measurements

The bridge reads allocation and physical supply independently.

### Allocation

The Julia bridge reads the pinned Ribasim internal
`user_demand.allocated` state at the correct demand-priority index.

It separately checks:

```text
allocated_i <= demand_i.
```

### Physical supply

Physical supply is measured from the real Basin-to-UserDemand link flows:

```text
Basin 2 -> root UserDemand 3
Basin 2 -> external UserDemand 4.
```

The test does not define supplied flow by copying `allocated`.

### Physical state

The real Basin result must remain at 1 m through the horizon.

This demonstrates that the two priority cases have the same physical
surface-water trajectory and that the scarce resource is the fixed source
flow, not initial storage depletion.

## Exact DUMMY-15 correspondence

Analytical DUMMY-15:

```text
total managed capacity = 32

ROOT_FIRST:
  root = 32
  external = 0

EXTERNAL_FIRST:
  external = 20
  root = 12.
```

DUMMY-19B uses the same demand and capacity values, but the split is now
computed by pinned real Ribasim rather than the analytical priority splitter.

## What a PASS establishes

A PASS establishes a restricted real-model bridge for:

- same-source two-recipient demand priority;
- lexicographic scarce allocation;
- independent physical supply observation;
- priority-invariant total managed flow;
- priority-invariant Basin trajectory.

## What it does not establish

DUMMY-19B does not test:

- Ribasim physical min-level curtailment;
- forecast allocation versus later physical realization;
- SWAP irrigation demand;
- groundwater exchange;
- route competition;
- MODFLOW;
- production coupler transactions.

Those remain separate stages.

## Next step after qualification

Only after DUMMY-19B closes should a real-Ribasim model intentionally separate
allocated from physically supplied water by activating the source-state
reduction surface. That later bridge can then be compared with the already
qualified DUMMY-15B realization-policy contrast.
