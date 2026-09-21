# RIBASIM-DUMMY-19H: saveat negative control

> Status: PREREGISTERED before DUMMY-19G execution.

DUMMY-19G tests whether changing only `solver.saveat` changes management and
physical realization when supply is scarce.

DUMMY-19H freezes the causal negative control in advance. The same physical
UserDemand reduction is retained, but fixed source supply is raised to exactly
the total requested demand:

```text
source = 60 m3/day
root demand = 40 m3/day
external demand = 20 m3/day
```

The allocator therefore has no management shortage to resolve. Every allocation
solve must remain at 40/20 m3/day, irrespective of how often saveat causes the
LP to be rebuilt.

The saveat sweep is unchanged:

```text
1 h, 6 h, 12 h, 24 h
```

with `allocation.dt = 24 h`.

The independent continuous reference is the single ODE with total allocated
target 60 m3/day. It predicts 30.0673987632 m3 physical supply and
29.9326012365 m3 retained Basin storage after one day.

A pass means saveat itself is not changing the physical solution when the
allocation map cannot change. Combined with a DUMMY-19G pass, that would isolate
the observed clock sensitivity to repeated state-dependent management
reoptimization.
