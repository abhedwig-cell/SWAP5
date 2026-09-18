# ROM-0V1 vertical-resolution Reference-floor authority

ROM-0V1 executes the final vertical-resolution comparison fixed in the original ROM-0 matrix.

## Pre-execution correction

The first V1 draft used 0.0008 day for both grids and imported the later representation-bounded total policy. Before any V1 execution, the original ROM-0 runner and analyzer were rechecked. They explicitly bind both vertical pairs to **0.0016 day on both grids**:

- B01 / E1_NOMINAL_FLUX: 16×10 cm at 0.0016 d versus 32×5 cm at 0.0016 d;
- B14 / E2_DRYING_FLUX: 16×10 cm at 0.0016 d versus 32×5 cm at 0.0016 d.

V1 retains that binding so it isolates vertical discretization rather than mixing vertical and temporal refinement.

## Frozen physical cases

- B01 / E1: q_top = 0.01 K0 and prescribed q_bottom = -0.004 K0.
- B14 / E2: q_top = -0.005 K0 and prescribed q_bottom = -0.019 K0.

Both use the original uniform Se=0.85 initial state, zero sources/sinks, zero ponding, and a 160 cm homogeneous profile. The horizon is 0.0512 day, giving 32 common endpoints. The later R1 gravity-steady seed is not substituted.

## Numerical authority

Execution uses the governed F-KT Reference-floor sample/candidate/commit seam. These are the original mode-2 fixed-flux cases, so the original strict controls remain in force: local and total balance criteria 1e-12 cm/day, head and ponding criteria 1e-12, 16 nonlinear iterations, 8 backtracking attempts, SWKIMPL=0, SWKMEAN=1, and an independent 1e-12 cm transaction mass gate.

The later prescribed-head representation policy is not imported into V1. If a frozen vertical trajectory cannot be sampled under these controls, V1 records a no-go rather than retuning the experiment.

## Cross-grid comparison

V1 is measure-only. No observed 16-vs-32 difference becomes an acceptance threshold.

For each common endpoint, two 5-cm fine cells map to each 10-cm coarse cell:
- water content is pairwise averaged, exactly conserving layer storage for equal fine-cell thickness;
- pressure head is pairwise averaged, equivalent to linear interpolation to the coarse-cell centre on the nested uniform grids.

V1 reports profile head/theta norms, total storage, fixed 0–40 and 40–160 cm storage, cumulative bottom-outward exchange, terminal bottom flux, mass residual and solver-work ranges. Top exchange is prescribed identically and is treated as an input identity.

A positive result means the required vertical Reference floor is measured. ROM-1A remains blocked until the complete Q0 close-gate reconciliation is updated.
