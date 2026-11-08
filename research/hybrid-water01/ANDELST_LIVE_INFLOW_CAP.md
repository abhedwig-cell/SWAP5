# Andelst closed-loop matrix-only inflow capacity experiment

Reference: [same-state inflow limit](ANDELST_DEEP_INFLOW_LIMIT.md).
Both variants ran GNU Fortran 13.3 O2 from the native Linux day-453
checkpoint and kept the normal V9 numerical controls. The cap based
on pore volume below the matrix groundwater level is separate from
the total storage, outflow and redistribution bounds. It is evaluated
in the same provider for the matrix solve and the converged rates.
The historical threshold and storage deadband are both 1e-7 in the
source units. The bounded limiter checks passed at O0 and O2 for
matrix-only inflow, independent surface inflow, perched interflow
and an absent optional cap.

## Measured response through common accepted time 453.592

| Quantity, mm | V9 control | All-domain cap | Main-domain-only cap |
|---|---:|---:|---:|
| Net bottom inflow | 1.80129 | 0.52816 | 0.52912 |
| Rapid outflow | 0.83718 | 0.59999 | 0.59955 |
| Net matrix to main macro domain | 0.81598 | -0.10459 | -0.10535 |

Main-domain balance residual over these accepted substeps was at
most 2.14e-16 cm per step in both variants. The all-domain variant
refused 453.592–453.594 after 70 solver rejections. The main-only
variant passed that interval and refused 453.596–453.598 after 67
solver rejections. Both fail closed with an interior diagnostic
checkpoint at the committed clock and no first-day output. There
is no successful four-day trajectory, exact day-boundary replay,
or production admission for either candidate.

A separate diagnostic attempt started from the all-domain refusal
checkpoint with the driver's day/source-event restriction bypassed
in a private build. It was stopped after repeated trial evaluations
without a completed interval. The trial-only diagnostic shows that
cap fractions can change, but does not isolate the nonlinear cause
or qualify interior restarts.

## Reproduction

Use the renderer alongside the existing V9 build infrastructure.
Set PYTHONPATH to the repository's tests/dataqual15 directory.
Pass the same --driver, --compiler, --optimization, --output and
optional --reuse arguments as for the V9 renderer. Execute with
the day-453 checkpoint and original dry-window inputs.

To reproduce the main-only diagnostic, change the renderer's
capacity loop from `do id=1,geometry_current%num_domains` to
`do id=1,1`, initialise `matrix_only_capacity_cm` to
`maximum_storage_cm`, and replace the first matrix-only gate
`request%potential_matrix_sat_cm(id)>0d0.and.` with `id==1.and.`.
This isolates the changed inflow bound to the domain with the
measured discrepancy.

The cap restores the desired exchange direction in the accepted
prefix, but this implementation cannot be used for historical
closure. The next numerical check is a bounded reproduction of
the first refusal with trial logging for the active cap and the
coupled exchange Jacobian. Keep the legacy physical cap distinct
from the numerical handling of its switches.
