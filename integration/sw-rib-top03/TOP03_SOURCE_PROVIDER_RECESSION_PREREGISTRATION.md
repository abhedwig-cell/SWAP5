# Source-provider inundation and recession probe

Date: 2026-10-03  
Status: PREREGISTERED_DIAGNOSTIC_ONLY  
Scope: actual SWAP5 MvG provider and `HeadCalc`, widths 0.2 and 2 cm, fixed-grid refinement 1–4096.

## Question

Does the implemented near-saturation `theta/C/K` transition with its analytic free-drainage Jacobian term complete and conserve an imposed external-head pulse through both inundation and recession on the real source path?

## Forcing and controls

Use the existing one-column geometry-2 BASE surface-transition probe, `SWBOTB=7`, `SWKIMPL=0`, initial pressure head `-123 cm`, initial GWL `-2.25 cm`, zero precipitation/evaporation/runoff forcing, external sill `0.01 cm`, peak head `0.02 cm`, horizon `0.25 day`, and uniform refinements 1 through 4096. The prescribed stage rises linearly from zero to `0.02 cm` over `0.001953125 day`, stays at peak until `0.125 day`, recedes linearly to zero over the same ramp duration, then remains zero. Only the stage history and transition width differ from the existing source-provider rise-to-plateau run.

Run the actual production provider and `HeadCalc` at O0 and O2 for widths 0.2 and 2 cm. Report every refinement, top and bottom integrated transfer, soil and combined mass residual, completion, nonlinear iterations, and successive refinement differences in pressure head, water content, and transfer. Require all tested paths to complete, existing `1e-10 cm` soil/ledger gates, derivative-oracle passage, and exact O0/O2 numerical identity. Do not alter forcing, tolerances, or refinement list after seeing a failure.

This is a direct solver diagnostic only. It does not exercise FMR accepted-step policy, transaction replay/restart, publication, or live Ribasim ownership. Passing is not production admission.
