# RIBASIM-DUMMY-15B blocked concept: forecast allocation versus physical realization

> Status: BLOCKED pending formal qualification of RIBASIM-DUMMY-15.
>
> No DUMMY-15B implementation or tests may be created before DUMMY-15 closes
> and the implementation baseline is rebound.

## Purpose

DUMMY-15 separates exact physical managed capacity from its priority split.

DUMMY-15B adds the information error that motivated the original coupling
question:

1. management predicts how much water can be allocated;
2. allocation distributes that predicted capacity;
3. shared-state hydrology is then realized;
4. actual supplied flow can be lower than allocated flow.

The distinction is

```text
demand
allocated
supplied.
```

Only supplied water changes physical state.

## Canonical forecast

Use the canonical DUMMY-15 state and demands:

```text
R_root = 40
R_ext = 20
R_total = 60.
```

For the forecast stage, deliberately ignore surface-groundwater exchange.

The surface-only volume above the management threshold is

```text
M_pred =
  A_s (h_s0-hmin)
  = 100 (1.0-0.4)
  = 60.
```

Thus the management forecast says all 60 m3 can be allocated.

This is an intentionally incomplete forecast, not a Ribasim production
prediction model.

## Allocation

Because predicted capacity equals total demand, both claims are fully
allocated:

```text
allocated_root = 40
allocated_ext  = 20.
```

The result is the same for either priority in this canonical forecast because
there is no forecast scarcity.

## Actual physical realization

The qualified shared-state hydrology includes surface-groundwater exchange.

For the allocated total 60 m3, the exact coupled physical solution can realize
only

```text
M_actual = 32
```

with

```text
V = 28
h_s1 = 0.4
h_g1 = 0.28.
```

Hydrology therefore removes 28 m3 of the capacity that the surface-only
forecast incorrectly treated as available to management.

The physical exchange is not clipped to preserve the earlier allocation.

## Priority-preserving realization oracle

DUMMY-15B first-stage realization uses the same priority order as allocation,
but supplied flow is capped by both allocation and actual physical capacity.

For each claim:

```text
0 <= supplied_i <= allocated_i <= demand_i.
```

### Root priority

Allocated:

```text
root = 40
external = 20.
```

Supplied:

```text
root = 32
external = 0.
```

Allocation-realization differences:

```text
root = 8
external = 20.
```

Root endpoint:

```text
W_root1 = 72
next root request = 8.
```

### External priority

Allocated:

```text
external = 20
root = 40.
```

Supplied:

```text
external = 20
root = 12.
```

Allocation-realization differences:

```text
external = 0
root = 28.
```

Root endpoint:

```text
W_root1 = 52
next root request = 28.
```

## Physical ledgers use supplied, not allocated

Root:

```text
Delta W_root = + supplied_root.
```

Surface:

```text
Delta S_surface =
  - supplied_root
  - supplied_external
  - V.
```

Groundwater:

```text
Delta S_groundwater = +V.
```

Combined:

```text
Delta total = - supplied_external.
```

The 28 m3 that was allocated but not supplied in the root-priority case does
not exist as a water transfer.

Allocation is a management decision.

Supply is the physical transfer.

## Under-allocation control

A different failure mode must also be controlled.

Suppose the forecast allocates only

```text
M_pred = 20
```

even though the actual physical system could accept more managed withdrawal.

Then realization must not create unallocated delivery.

Root-priority allocation:

```text
allocated_root = 20
allocated_ext = 0
```

must satisfy

```text
supplied_root = 20
supplied_ext = 0.
```

External-priority allocation has the analogous result.

This tests

```text
supplied <= allocated.
```

## Partial forecast scarcity control

With

```text
M_pred = 45
```

allocation itself already uses priority.

Root priority:

```text
allocated_root = 40
allocated_ext = 5.
```

External priority:

```text
allocated_ext = 20
allocated_root = 25.
```

The actual shared-state managed capacity remains 32.

Priority-preserving realization gives:

Root priority:

```text
supplied_root = 32
supplied_ext = 0.
```

External priority:

```text
supplied_ext = 20
supplied_root = 12.
```

This separates forecast scarcity from realization scarcity.

## What this experiment can establish

DUMMY-15B can establish that a proposed coupling contract consistently
distinguishes:

- requested demand;
- management allocation;
- physical supply;
- allocation-realization shortfall;
- physical shortage in the root state;
- internal hydrological exchange.

It can also establish that allocation does not acquire physical reality merely
because it was optimized earlier.

## What it cannot establish

Current public Ribasim documentation exposes distinct allocation and supplied
results, but DUMMY-15B does not yet establish how real Ribasim should curtail
multiple already-allocated demands when the later physical layer cannot realize
them all.

The priority-preserving realization rule is therefore a research oracle, not a
claim about current Ribasim implementation behavior.

Before production relevance is claimed, this exact experiment should be run
against a pinned real Ribasim model.

## Implementation gate

No DUMMY-15B code or tests may be created before DUMMY-15 qualification.

After DUMMY-15 closeout, the implementation baseline must be rebound.
