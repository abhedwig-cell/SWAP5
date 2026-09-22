# RIBASIM-DUMMY-20B: product-pinned Ribasim release clock contract

> Status: PREREGISTERED while DUMMY-20A is active.

The pinned iMOD Coupler product downloads Ribasim `v2026.1.1`. That release is
103 commits behind the DUMMY-19 research pin.

This matters because the allocation clock implementation changed.

In `v2026.1.1`, `BMI.update_until(t_target)` calls `step!(model, dt)`. With a
fixed `allocation.dt`, `step!` runs allocation only when the current time is on
the allocation grid before advancing the requested interval.

The preregistered product-release contract is therefore:

```text
fixed allocation.dt owns allocation cadence
MF6/RibaMod update_until endpoints own physical advancement cadence
solver.saveat does not create extra fixed-dt allocation decisions
```

This differs from the later Ribasim source qualified in DUMMY-19G through 19L,
where saveat-derived allocation tstops and record-gated application became
first-class clock semantics.

DUMMY-20B exists specifically to prevent version mixing. DUMMY-20C may only
form runtime expectations from the exact product-release contract qualified here.
