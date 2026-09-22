# RIBASIM-DUMMY-20H2: where does active-River forcing become visible?

> Status: PREREGISTERED after the scientific falsification of DUMMY-20H.

DUMMY-20H established a real discrepancy:

```text
active River is physically ~8 m3/day from the first 6-hour segment
but
t=0 UserDemand allocation remains 32/0 m3/day
```

This work unit does not repair that result. It localizes the seam.

Three routes use the same bundled Ribasim v2026.1.1 binary:

1. direct BMI control with zero infiltration;
2. direct BMI injection of exactly the qualified first River rate before the
   first `update_until`;
3. the actual RibaMod active-River route, with a read-only wrapper around
   `RibasimWrapper.update_until` that records the infiltration pointer just
   before product advancement and then delegates unchanged.

The direct-injection allocation outcome is deliberately not assumed. A
preregistered decision table distinguishes:

- a Ribasim-release current-boundary visibility limitation;
- an additional RibaMod composition/timing seam;
- or a pre-update pointer-timing seam.

The diagnostic qualifies a classification, not the failed 20H claim.
