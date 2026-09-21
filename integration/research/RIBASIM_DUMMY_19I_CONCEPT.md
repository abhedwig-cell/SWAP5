# RIBASIM-DUMMY-19I: BMI-owned management clock

> Status: PREREGISTERED while DUMMY-19G is active.
>
> Execution is sequenced after DUMMY-19H. Numerical expectations are frozen now.

The source audit shows two independent ways an allocation tstop can enter the
pinned Ribasim integrator:

1. the internal `solver.saveat` grid;
2. an endpoint passed to `BMI.update_until`.

DUMMY-19I isolates the second route.

The model keeps:

```text
allocation.dt = 24 h
solver.saveat = 24 h
```

but the external coupler advances Ribasim through:

```text
6 h
12 h
18 h
24 h
```

using successive `BMI.update_until` calls.

The preregistered expectation is that these external endpoints become actual
allocation boundaries. Therefore the management trajectory must equal the
6-hour hybrid reference already frozen independently of real Ribasim output.

The key distinction is:

```text
output clock = 24 h
coupler / management clock = 6 h
```

If qualified, this establishes a viable mechanism for making the coupler own a
management clock without forcing equally frequent result output. It does not
remove the separate limitation that a finer `saveat` can itself introduce
additional allocation boundaries.
