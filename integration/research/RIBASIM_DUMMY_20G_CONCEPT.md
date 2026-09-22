# RIBASIM-DUMMY-20G: active-river reciprocal stage feedback

> Status: PREREGISTERED while DUMMY-20F2 is active.

DUMMY-20E3 qualifies a one-way physical transfer from MF6 into Ribasim through
a passive Drainage package.

DUMMY-20G tests the other product path: an *active* MF6 River package.

The intended product sequence is:

```text
accepted Ribasim Basin/subgrid level at t_n
  -> RibaMod writes that level as MF6 river stage
  -> MF6 solves the 6-hour groundwater step
  -> RibaMod reads the river exchange
  -> positive MF6 river inflow becomes Ribasim infiltration
  -> Ribasim advances to t_(n+1)
```

There is deliberately no UserDemand in this work unit. The experiment isolates
physical reciprocity and the staggered time direction before active exchange is
combined with management.

The two-cell groundwater fixture uses a CHD cell at 0.5 m and a hydraulically
connected active River cell. With K=1e6 m/day and river conductance 16 m2/day,
the effective river exchange conductance is 15.9997440041 m2/day.

Starting from a 1.0 m Ribasim level, the first river transfer is therefore about
7.999872 m3/day from Ribasim toward groundwater. The Basin level then declines
slightly, and each subsequent 6-hour interval uses the newly accepted level as
the next MF6 river stage.

A pass establishes reciprocal, conservative, sample-and-hold stage feedback in
the actual product driver. It does not yet establish implicit same-window
coupled convergence.
