# RIBASIM-DUMMY-20A: actual RibaMod product clock contract

> Status: PREREGISTERED against the pinned iMOD Coupler product source.

DUMMY-19I through DUMMY-19L established that Ribasim distinguishes allocation
solve, UserDemand application, physical realization and output recording.

DUMMY-20A moves one layer outward and inspects the actual upstream iMOD Coupler
`RibaMod` driver rather than a locally reconstructed coupling loop.

The key product sequence to qualify is:

```text
MODFLOW timestep
  -> finalize MODFLOW time
  -> publish MODFLOW drainage/infiltration to Ribasim
  -> Ribasim.update_until(MODFLOW current time)
```

The preregistered question is whether the driver contains an additional
UserDemand allocation-application seam. The frozen hypothesis is that it does
not. If qualified, this means a MODFLOW timestep endpoint is a Ribasim BMI
advance target, but is not automatically an applied UserDemand management
boundary when it falls between Ribasim saveat boundaries.

This work unit is source-contract evidence for the real product driver. A
separate runtime work unit must test the resulting clock behavior dynamically.
