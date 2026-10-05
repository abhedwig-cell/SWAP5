# FrozenBounds low-air drainage source finding

Status: reproduced source inconsistency, not a production admission or a corrected
reference. The added B1.11 drainage, redistribution and integral source members
match the exact expanded F-PE19 B1.11 source manifest byte for byte.

The unchanged B1.11 `FrozenBounds` is executed at O0/O2 with minimal module globals,
`SWDRA=1`, `SWDIVD=0`, no air, deepest frost node 2, frost bottom -2 cm, drain
level -3 cm, an unmodified bottom flux of -0.01 cm/day, and a nodal drain sink
of 0.1 cm/day. It scales the level total to 0.09 cm/day while leaving the nodal
sink at 0.1 cm/day and bottom flux at -0.01 cm/day.

The source `headcalc.f90` sums `qdra` into the Richards sink. The source
`integral.f90` separately computes `qdrtot * dt` and `qbot * dt` for reporting.
The reproduced outputs imply a solver outflow of 0.11 cm/day and a reported
outflow of 0.10 cm/day, a discrepancy of 0.01 cm/day. This is a node-versus-level
ownership inconsistency. It is not evidence that every legacy drainage case fails.

The probe executes the actual unchanged FrozenBounds routine. It does not run a
full legacy simulation, Integral or DIVDRA. The mapping to solver/reporting is
established by the pinned actual source. DIVDRA is unreachable in the tested
SWDIVD=0 branch; the harness stops if it is unexpectedly called. Both optimization
levels reproduce the same outputs with bounds and floating-point traps enabled.

For SWDIVD=1 the actual DIVDRA routine rebuilds nodal drainage from level totals;
that branch must be qualified separately. A blanket double-counting claim is not
justified by this SWDIVD=0 probe. The intended redistribution and sign policy,
geometry interpolation and zero deepest-level index require explicit decisions.

The reference policy in `docs/verification/principles.md` requires demonstrated
legacy defects to be corrected and qualified through B1 before SWAP5 is required
to reproduce the correction. The safe next step is a preregistered corrected
node/level accounting contract and actual B1 qualification, followed by typed
single-owner drainage composition. The no-drain FrozenBounds successor does not
depend on that redistribution and can be qualified separately.

The B1.11 temperature source also shows sensible heat only: DeVries averages
constituent heat capacities using water and air volumes. There is no ice state or
latent heat term in this source authority. Migrating this frost source therefore
does not itself require inventing an ice/latent-heat model.

Reproduce with `bash tests/frost/run_ppa_wu05b_frozen_drain_source.sh`.
