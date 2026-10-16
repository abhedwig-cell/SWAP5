# F-PE-BOFEK00F — adaptive-timestep interaction preregistration

Date: 2026-09-28

Status: **PREREGISTERED_BEFORE_ADAPTIVE_TRAJECTORY**

Canonical preimage:
`integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`.

## Purpose

Characterize only the interaction between the already-confirmed wet-regime correctness defect/correction and the existing SWAP 4.3.1 `TimeControl` decision rule.

This phase does not tune or admit a new timestep policy.

The solver baseline and correction candidate must receive exactly the same forcing, initial state, timestep-policy constants and event horizon. The only production-source difference is the BOFEK00 correctness candidate.

## Policy authority

Current canonical source:

- `src/legacy/b1_10_fci11_port/timecontrol_part04.inc`
- `src/legacy/b1_10_fci11_port/timecontrol_part05.inc`

Accepted-step decision core:

```fortran
if (numbit <= numbit_crit) dt = min(dt*fact_dt_increase,dtMax)
if (numbit >= MaxIt)       dt = max(dt*fact_dt_decrease,dtMin)
```

Non-convergence decision core:

```fortran
if (dt > fact_dt_fldect*dtmin) then
   dt = dt / fact_dt_fldect
else
   dt = dtmin
end if
```

The test runner must source-guard these exact decision statements against current canonical.

Calendar, print, meteo, irrigation, macropore and runon event clamps are inactive in the bounded fixture. The only event clamp is the frozen experiment endpoint. Therefore a small replay of the decision core is mathematically equivalent to the active `TimeControl` policy surface for this fixture without constructing unrelated calendar/I/O state.

## Frozen adaptive fixture

Hydrology and solver settings are inherited from the successful BOFEK00 frozen-timestep fixture unless listed below.

Policy configuration, fixed before exposure:

- experiment horizon: `0.12 day`
- `dtmin = 0.001 day`
- `dtmax = 0.02 day`
- initial `dt = sqrt(dtmin*dtmax)`
- `numbit_crit = 4`
- `MaxIt = 8`
- `fact_dt_increase = 2.0`
- `fact_dt_decrease = 0.5`
- `fact_dt_fldect = 2.0`

These are **controlled qualification-fixture inputs**, not recommended BOFEK defaults and not an admission of new production constants.

The purpose is to exercise both the growth decision and, if naturally encountered, the reject/decrease decision. No constant may be changed after baseline/corrected trajectory exposure.

## Recorded evidence

For every attempted step retain:

- attempt origin and requested `dt`;
- solver status;
- nonlinear iterations;
- backtracks;
- accepted/rejected classification.

For every accepted step retain:

- accepted `dt`;
- top pressure head;
- ponding;
- runoff and cumulative runoff;
- top and bottom flux;
- combined water ledger;
- active top-boundary route.

Aggregate:

- accepted-dt sequence/distribution;
- solver rejected attempts;
- timestep reductions;
- timestep growth events;
- nonlinear iterations and backtracks per accepted step and totals;
- cumulative runoff;
- terminal state;
- maximum absolute water-ledger residual.

## Acceptance and interpretation

1. Both baseline and corrected runs must complete the same `0.12 day` physical horizon.
2. Both must satisfy the existing controlled-fixture water-ledger gate.
3. No timestep-policy constant may differ between baseline and corrected runs.
4. Any accepted-dt difference is classified as **ADAPTIVE-TIMESTEP INTERACTION CAUSED BY SOLVER CORRECTNESS**, not as a policy improvement.
5. A lower iteration count or runtime is PERFORMANCE evidence only after correctness and mass checks pass.
6. Hydrological differences under adaptive stepping are reported, not forced to zero. The frozen-timestep result remains the authority for direct solver-formulation equivalence.
7. No claim is made that these controlled policy constants are optimal for BOFEK or suitable as production defaults.

A separate timestep-policy optimization remains gated to F-PE-BOFEK01/02.
