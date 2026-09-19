# NUM-UNC P0C amendment P0C-R02: spatial-control interpretation

Date: 2026-09-19
Timing: before any spatial-control execution and before any N1 execution

## Reason

The original P0 protocol stated that a primary inference changing under grid refinement blocks the experiment. For Experiment C, however, C0 is intentionally located immediately beside the flux-to-ponding transition. Requiring the transition-centre case itself to retain the same binary class after changing the vertical discretisation would test whether an artificially threshold-near point remains threshold-near, not whether the physical transition family is spatially credible.

No refined-grid result has been generated at the time of this amendment.

## Frozen spatial-control gate

Use one twofold refinement of the cell-centred vertical grid:

- primary grid: 16 cells x 10 cm, total depth 160 cm;
- control grid: 32 cells x 5 cm, total depth 160 cm;
- first surface distance: half a cell;
- all internal node distances: one cell.

Everything else remains fixed, including B01, Se=0.85, N0 dt=0.0064 day and the exact C0 forcing schedule.

Only the already frozen outer cases are used as the gate:

- C- multiplier = 1.0006347656250001;
- C+ multiplier = 1.2229980468750001.

The gate passes only if:

1. C- remains study-admissible and remains NO_PONDING;
2. C+ remains study-admissible and remains PONDING;
3. no runoff occurs;
4. the hard typed integrated-mass criterion is satisfied;
5. no timestep retry or alternative linear solver is used.

C0 itself is not used as a pass/fail condition for spatial control.

If either outer class changes, C1 is blocked. The outer offsets will not be widened after observing that result.

## Interpretation

Passing this gate does not prove grid convergence of the transition multiplier. It establishes only that the preregistered neighbourhood still brackets the same qualitative surface-regime transition after one twofold vertical refinement.

A later paper-level experiment would require a fuller spatial-discretisation analysis if this mechanism survives P0.
