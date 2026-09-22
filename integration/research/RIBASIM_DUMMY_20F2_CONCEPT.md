# RIBASIM-DUMMY-20F2: next-boundary admission after a realized two-cell groundwater transfer

> Status: PREREGISTERED while DUMMY-20E3 is active.

The original DUMMY-20F was tied explicitly to DUMMY-20E2. Because DUMMY-20E2
never realized a groundwater intervention, that work unit remains historical
and unexecuted.

DUMMY-20F2 carries the same time-direction hypothesis onto the corrected
two-cell MF6 intervention:

```text
t=0
  daily allocation -> root 32, external 0

6-24 h
  approximately 7.999872002047967 m3/day groundwater enters physically
  -> accepted Basin storage changes
  -> no retroactive allocation rewrite

t=24 h
  next allocation.dt boundary
  -> accepted physical memory becomes management-visible
  -> root 40, external 20

24-48 h
  physical realization follows the new full allocation
```

The day-2 numerical references remain frozen against the idealized 8 m3/day
continuous limit. The analytical two-cell transfer differs by less than
0.00013 m3/day, far below the preregistered transfer/volume tolerances.

A 20F2 run is forbidden unless 20E3 first proves that the nonzero MF6-to-Ribasim
transfer is actually realized.
