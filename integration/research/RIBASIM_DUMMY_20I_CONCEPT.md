# RIBASIM-DUMMY-20I: active-River management memory across two days

> Status: PREREGISTERED while DUMMY-20H v2 is active.

This work unit combines both time directions already isolated in the programme.

At t=0 the active River forcing is present before the fixed-grid allocation
solve, so it reduces the current root allocation.

During day 1 the admitted allocation remains fixed while physical realization,
River exchange and Basin storage evolve.

At t=24 h the next allocation solve sees the accepted physical state and the
current active-River forcing. The preregistered prediction is therefore:

```text
t=0:
  root allocation     ~24.0000853 m3/day
  external allocation  0

accepted t=24 h:
  excess Basin storage ~11.9891771 m3
  active River forcing ~8.0001065 m3/day

new t=24 h allocation:
  root allocation     ~35.9890707 m3/day
  external allocation  0
```

The day-2 management decision is thus neither a retroactive repair nor a full
reset to 40/20. It is a prospective response to accepted physical memory under
continued active groundwater loss.

The complete eight-boundary Basin, root-delivery and River-transfer trajectory
is frozen from the qualified DUMMY-20G stage-feedback law and the v2026.1.1
UserDemand reduction function before DUMMY-20H v2 output is observed.
