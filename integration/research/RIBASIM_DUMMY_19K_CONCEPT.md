# RIBASIM-DUMMY-19K: explicit UserDemand apply seam

> Status: PREREGISTERED while DUMMY-19J is active.
>
> Test-only coupling-contract experiment. No pinned Ribasim source modification.

DUMMY-19I2 separates two states at a sub-saveat allocation boundary:

```text
shadow LP allocation
applied physical UserDemand allocation
```

The missing operation is an explicit apply/commit from the first to the second.

DUMMY-19K emulates only that operation in the test harness. At every accepted
6-hour boundary it solves the allocation problem from the current physical
state with output recording disabled, and then copies the optimized UserDemand
allocation and per-link inflow allocation into the physical UserDemand state
before the next physical segment.

It deliberately does not write an allocation output record or reset cumulative
output accounting.

If this recovers the independently frozen 6-hour trajectory, the coupling
contract becomes explicit:

```text
accepted physical state
→ allocation solve
→ allocation apply/commit
→ physical realization
→ next accepted boundary
```

Output recording is then a separate clock and not part of the physical
allocation commit.
