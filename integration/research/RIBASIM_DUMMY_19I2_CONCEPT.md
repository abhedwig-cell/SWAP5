# RIBASIM-DUMMY-19I2: shadow LP versus applied UserDemand allocation

> Status: PREREGISTERED after DUMMY-19I falsification.
>
> This is a new explanatory work unit. It does not revise DUMMY-19I.

DUMMY-19I showed that a 6-hour `BMI.update_until` boundary with daily
`solver.saveat` does not produce the expected applied UserDemand allocation.

Pinned source inspection reveals two distinct states:

1. the allocation LP solution;
2. the UserDemand allocation state consumed by physical realization.

At a sub-saveat BMI boundary the LP is solved with `record=false`. The
`parse_allocations!` path is then skipped. That path is where
`UserDemand.allocated` and `inflow_link_allocated` are updated.

DUMMY-19I2 observes both states after every 6-hour segment.

For the root-first case the preregistered contrast is:

```text
represented solve time   shadow LP       applied UserDemand
0 h                      32 / 0          32 / 0
6 h                      40 / 7.9952     32 / 0
12 h                     40 / 20         32 / 0
18 h                     40 / 20         32 / 0
```

The external-first case begins at 12/20, has a 27.9952/20 shadow solution at
6 h, and then reaches a 40/20 shadow solution while the applied state stays
12/20.

Because the physically applied total remains 32 m3/day, the one-day physical
endpoint must follow the daily clock-aligned DUMMY-19E2 reference, not the
6-hour DUMMY-19G reference.
