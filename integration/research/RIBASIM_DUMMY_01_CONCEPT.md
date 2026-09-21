# RIBASIM-DUMMY-01 coupling concept

## Purpose

This research harness isolates one question before real SWAP5, MODFLOW 6 and
Ribasim are composed:

> How should a surface-water allocation be revised when the physical
> groundwater exchange realized during the same coupling window differs from
> the exchange assumed during allocation?

The harness is deliberately smaller than Ribasim. It contains one linear Basin,
one UserDemand and one aggregate MODFLOW-style infiltration/drainage exchange.
It is an analytical oracle, not a replacement for Ribasim.

## Ribasim concept binding

The naming follows the current Ribasim coupling surface:

- Basin storage and level are the surface-water state;
- Basin infiltration is water leaving the Basin toward MODFLOW;
- Basin drainage is water entering the Basin from MODFLOW;
- UserDemand is the managed abstraction;
- UserDemand min_level defines the lower level at which managed abstraction
  must stop;
- allocation is a prediction, followed by attempted physical realization.

The real BMI works primarily with rates and cumulative integrated volumes. The
dummy works with integrated volumes over one coupling window so every case can
be checked with closed-form arithmetic. A later adapter can use
`V = Q * dt` where a constant window-mean rate is appropriate.

Reference concept pages checked on 2026-09-21:

- https://ribasim.org/reference/node/basin.html
- https://ribasim.org/reference/node/user-demand.html
- https://ribasim.org/concept/allocation.html
- https://ribasim.org/dev/bmi.html

## State and notation

For one coupling window, let:

- `S_n`: committed Basin storage at the start of the window [m3];
- `E^f, D^f, F^f`: forecast external inflow, drainage and infiltration [m3];
- `E^a, D^a, F^a`: actually realized external inflow, drainage and
  infiltration [m3];
- `R`: UserDemand request [m3];
- `h_min`: UserDemand minimum level [m];
- `A_B`: constant Basin area [m2];
- `z_0`: datum of the linear Basin profile [m].

For the linear profile, the protected storage associated with UserDemand
min_level is

```text
S_min = A_B * (h_min - z_0)
```

with `S_min = 0` when no UserDemand min_level is configured.

## Allocation prediction

The forecast post-hydrology storage is

```text
S_H^f = S_n + E^f + D^f - F^f
```

The amount allocated to UserDemand is

```text
U_alloc = min(R, max(0, S_H^f - S_min))
```

and the shortage already visible during allocation is

```text
shortage_alloc = R - U_alloc
```

## Physical realization

The actual hydrological state before managed abstraction is

```text
S_H^a = S_n + E^a + D^a - F^a
```

The realized UserDemand delivery is

```text
U_real = min(U_alloc, max(0, S_H^a - S_min))
```

The new shortage created by forecast error or changed physical exchange is

```text
shortage_realization = U_alloc - U_real
```

and the total shortage relative to the original SWAP/UserDemand request is

```text
shortage_total = R - U_real
```

The candidate end storage is

```text
S_(n+1) = S_H^a - U_real
```

so the realized water-balance residual is checked directly from

```text
epsilon =
  S_(n+1)
  - (S_n + E^a + D^a - F^a - U_real)
```

## Priority interpretation

"Hydrology before management" has a narrow meaning in this harness.

A mandatory physical infiltration is not reduced merely because a previously
allocated UserDemand would otherwise cause a shortage. The managed abstraction
is reduced first.

This does not mean an arbitrarily prescribed infiltration can always be
realized. If

```text
F^a > S_n + E^a + D^a
```

then the candidate physical flux set would require negative Basin storage. The
dummy fails closed. In a real coupled system this is a signal to re-evaluate
the coupled heads/fluxes, reduce the coupling step, or otherwise resolve the
physical inconsistency. It is not authority to clip the MODFLOW exchange
silently.

## Canonical conflict experiment

Start with `S_n = 100 m3`.

Allocation forecast:

```text
F^f = 0
R   = 50
S_min = 0

=> U_alloc = 50
```

Physical realization:

```text
F^a = 60

S_H^a = 100 - 60 = 40
U_real = min(50, 40) = 40
shortage_realization = 10
S_(n+1) = 0
```

At the allocation boundary the full irrigation request appears feasible. At
the end of the same window, the physically realized infiltration has first
claim on 60 m3 and irrigation is therefore reduced by 10 m3.

This is the first controlled case for the later dummy-SWAP / dummy-Ribasim /
dummy-MODFLOW triangle.
