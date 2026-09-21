# RIBASIM-DUMMY-19C blocked concept: full allocation, reduced physical supply

> Status: IMPLEMENTED after formal qualification of DUMMY-19B.
>
> This concept and all numerical expectations were fixed before implementation.
> The implementation baseline was rebound to the post-DUMMY-19B closeout before
> any DUMMY-19C executable model or verifier was created.

## Question

Can pinned real Ribasim fully allocate two managed demands while its physical
UserDemand layer later supplies substantially less water because the source
Basin is close to each UserDemand's `min_level`?

This is the real-model version of the analytical DUMMY-15B distinction:

```text
demand -> allocated -> supplied.
```

## Why this conflict is legitimate

Pinned Ribasim allocation and physical layers do not use exactly the same
UserDemand constraint.

The allocation objective/bounds constrain allocation by demand and network
water availability.

The physical UserDemand solver then multiplies the allocated inflow-link target
by:

```text
low_storage_factor
*
reduction_factor(source_level-min_level, 0.02 m).
```

The allocation code does not directly use `UserDemand.min_level` in the
UserDemand demand objective or link-demand upper bound.

Therefore a fully allocated demand can later be physically reduced.

## Controlled model

Use one Basin with constant area

```text
A = 1,000,000 m2.
```

Initial level:

```text
h_0 = 1.00 m.
```

A priority-1 LevelDemand asks allocation to hold the Basin at 1.00 m.

Fixed external supply:

```text
60 m3/day.
```

Managed demands:

```text
root proxy = 40 m3/day
external demand = 20 m3/day.
```

Both UserDemand nodes have

```text
min_level = 0.99 m.
```

Thus initially

```text
x = h-min_level = 0.01 m
threshold = 0.02 m
x/threshold = 0.5.
```

Pinned Ribasim's smooth factor gives exactly

```text
phi(0.01) = 0.5.
```

## Allocation expectation

Because the allocator sees:

- 60 m3/day fixed inflow;
- 60 m3/day total demand;
- a priority-1 zero-storage-change objective;

the preregistered allocation is:

```text
allocated_root = 40
allocated_external = 20
allocated_total = 60 m3/day.
```

Both priority orders should reach the same allocation because all demand can be
allocated.

## Physical realization

The physical UserDemand layer sees the common 0.5 source-state reduction factor.

Both claims use the same Basin and the same min_level.

Therefore at every instant:

```text
q_root / q_external = 40 / 20 = 2.
```

The factor increases only slightly because unsupplied inflow raises the
1 km2 Basin level by only about 3e-5 m over the day.

An independent continuous integration of the pinned reduction law gives:

```text
final Basin level
  ~= 1.0000299326012367 m

total physical supplied
  ~= 30.0673987633 m3

root physical supplied
  ~= 20.0449325088 m3

external physical supplied
  ~= 10.0224662544 m3

Basin storage gain
  ~= 29.9326012367 m3.
```

The water ledger is

```text
60 m3 inflow
=
30.0673987633 supplied
+
29.9326012367 stored.
```

A 0.05 m3 predeclared tolerance is allowed for integrated solver/output
comparison.

## Why this tests the DUMMY-15B realization policies

DUMMY-15B compared two analytical policies.

### Priority-preserving

Physical scarcity would first curtail the lower-priority recipient.

### Common-factor proportional reduction

Every allocated inflow is multiplied by the same physical factor.

For this controlled real Ribasim case, the pinned source formula predicts the
second structure:

```text
supplied_root : supplied_external
=
allocated_root : allocated_external
=
2 : 1.
```

Priority should therefore not reappear during physical realization once both
claims were fully allocated.

This conclusion is deliberately restricted to the common-source/common-min-level
case.

## Boundary

DUMMY-19C will not establish:

- proportional reduction for different source Basins;
- proportional reduction for unequal min_level values;
- behavior when only one claim was allocated;
- network-level reallocation after physical shortfall;
- any SWAP or MODFLOW behavior.

It is a precise one-Basin real-Ribasim realization bridge only.
