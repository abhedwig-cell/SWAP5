# RIBASIM-DUMMY-20H4: physical versus LP low-storage factor

> Status: PREREGISTERED while DUMMY-20H3 is active.

DUMMY-20H2 proved that current-boundary BMI infiltration is physically active
but does not reduce the fixed-grid t=0 UserDemand allocation.

DUMMY-20H3 tests the proposed LP mechanism: the allocation model can reduce its
own `low_storage_factor` decision variable to preserve higher-priority demand
objectives.

DUMMY-20H4 freezes the direct state-space comparison before DUMMY-20H3 is
observed.

For one identical accepted t=0 Basin state and one identical ~8 m3/day
infiltration it compares:

```text
physical factor
  = reduction_factor(actual Basin storage, physical low-storage threshold)

allocation factor
  = optimized LP low_storage_factor
```

At 1 m level in the 1,000,000 m2 Basin the physical state is far from dry, so
the preregistered physical factor is approximately 1 and the physical layer
formulates essentially the full infiltration.

Conditional on DUMMY-20H3 qualification, the LP factor is expected to be
approximately 0 while allocation remains 32/0 m3/day.

A pass would establish a direct forecast-realization state mismatch. It would
not by itself decide how production coupling should resolve that mismatch.
