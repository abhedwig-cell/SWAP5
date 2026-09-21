# RIBASIM-DUMMY-19E2: clock-aligned priority allocation then physical realization

> Status: PREREGISTERED after DUMMY-19E clock-semantics falsification.
>
> This is a new work unit. It does not revise the failed DUMMY-19E evidence.

DUMMY-19E attempted to hold a one-day allocation while writing hourly output.
Pinned Ribasim instead re-solved allocation on those hourly `saveat` boundaries.

DUMMY-19E2 isolates the originally intended mechanism by aligning:

```text
allocation.dt = 86400 s
solver.saveat = 86400 s
physical horizon = 86400 s
```

All other model quantities and all independent numerical expectations remain
those frozen before the DUMMY-19E run.

The scientific question is now narrow:

> Given one actual management allocation at the start of the day, does pinned
> Ribasim preserve the priority-selected allocation map while source-state
> physics reduces the realized transfer?

The expected management allocations are:

```text
ROOT_FIRST      root 32, external 0 m3/day
EXTERNAL_FIRST  root 12, external 20 m3/day
```

Both active transfer maps have total allocation 32 m3/day and use the same
source Basin and `min_level = 0.99 m`.

The independent physical reference is:

```text
total supplied     = 16.019184640970934 m3
storage gain       = 15.980815359029066 m3
final Basin level  = 1.000015980815359 m
```

Recipient physical supply must follow the frozen allocation map:

```text
ROOT_FIRST:
  root     = 16.019184640970934 m3
  external = 0

EXTERNAL_FIRST:
  root     = 6.0071942403641 m3
  external = 10.011990400606834 m3
```

A pass qualifies only this clock-aligned realization contract. The separate
question of why output `saveat` changes allocation timing remains a dedicated
clock-semantics research question.
