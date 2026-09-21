# RIBASIM-DUMMY-19J: coupler clock versus output clock

> Status: PREREGISTERED before DUMMY-19H and DUMMY-19I closeout.
>
> This is the conflict experiment paired with DUMMY-19I.

The coupler advances Ribasim in 6-hour windows:

```text
BMI.update_until(6 h)
BMI.update_until(12 h)
BMI.update_until(18 h)
BMI.update_until(24 h)
```

but the model is configured with:

```text
allocation.dt = 24 h
solver.saveat = 1 h
```

Pinned source inspection says that `BMI.update_until` adds coupling endpoints to
the allocation tstop set. It does not remove the already present saveat-derived
tstops.

Therefore the preregistered expectation is not a 6-hour management clock. The
effective allocation solve grid remains hourly.

The physical prediction is consequently the independently frozen 1-hour
DUMMY-19G hybrid reference, approximately 29.09149 m3 total demand delivery,
rather than the 6-hour reference of approximately 24.51282 m3.

This experiment is important for the coupling contract. A coupler can add
management boundaries, but in the pinned implementation it cannot make a
coarser management clock exclusive while a finer output saveat grid continues
to create allocation boundaries.
