# Nonlinear contact and accepted thermal receipt contract

Status: **Proposed implementation; not qualified or admitted.**

Baseline is canonical `538fb025e`. The preceding contact witness held its
Jacobian and absorption jump fixed. The next research step must reevaluate the
actual constitutive/storage and macropore callbacks. Any local fixed-neighbour
experiment remains explicitly separate from a full accepted native step. A
contact fraction must enter matrix and macro exchange with opposite signs;
neither mass tolerance nor the original sharp entry law may be relaxed.

The energy work adds observation data to the existing accepted water-substep
trace. Temperatures before/after the actual thermal trial, its actual averaged
capacity and face conductivities, hydraulic endpoints and conductive boundary
results belong to the same interval. They are copied only after a successful
thermal trial and attached only to its accepted-water trace element. Existing
transaction selection/discard determines which sibling is published. This is
scratch/result data, not persistent physical state or a restart layout change.

The observation distinguishes directly evaluated numeric conductive boundaries
from analytical or storage-derived flux correction. The latter must not become
an independent external heat receipt. Gas transport, external donor temperatures,
vapor, freezing and atmospheric radiation/latent owners are not invented by
this observation. Full physical-energy completeness remains false. Existing
thermal/water results must remain identical with observation off/on.

Selection and recovery are in
`integration/dataqual15/NONLINEAR_THERMAL_RECOVERY_20261103.json`. Local tests
start with the small observation contract, then checked O0/O2 real runtime
single/full-half/rejection coverage. A native contact replay is bounded to the
archived failure neighbourhood; it is not a new original481-day trajectory.
