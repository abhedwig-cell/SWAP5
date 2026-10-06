# PPA-MICRO01 matric flux table repair contract

Status: qualified corrected table component, canonical admission pending. Preregistered before implementation.

The unchanged exact B1.11 routine has an executable confirmed uninitialized
M/K dry bracket. Run 37416500205 at `9d9ac400fd5777d005d8ca993d4451c41c88ea1f`
passes the six-head, three-storage-realization O0/O2 component falsification.
The first run's false-green pipeline and incorrect normal control are retained
as negative evidence. A workflow conclusion alone is not qualification.

Owned new component: a typed immutable MICRO matric-flux/conductivity lookup
table. It accepts conductivity samples from a hydraulic owner at the existing
430 logarithmic grid points, the conductivity at the explicit -20000 cm dry
endpoint, and saturated conductivity. It does not own a soil model, solver,
accepted water/salt state, root sink or I/O. No module SAVE variables.

Corrected-reference policy: honor the executable explicit dry cutoff of
-20000 cm, with M=0 there. Integrate the short terminal interval to the first
logarithmic grid point using a linear conductivity profile and its exact
quadratic integral. Then retain the source trapezoidal grid integration and
log-pressure interpolation. Below the cutoff both M and K are zero; at the
cutoff K is the supplied endpoint value, consistent with the original strict
below-cutoff branch. Wet extension keeps the source -1.023293 cm boundary.
Every accessed cell is initialized. The former initialized M values acquire
the explicit missing terminal integral; this is a disclosed reference repair,
not bitwise preservation of the historical truncated integration origin.

Require a generated corrected literal reference routine with an explicit,
auditable patch of only initialization and the terminal lookup branch.
Its original immutable member/block remains pinned. Test both constant and
head-dependent synthetic hydraulic owners, endpoint/neighbour/normal/wet
values, every original grid node, invalid/nonfinite samples and rejected build
isolation, with O0/O2 equality and an independent terminal integral check.
Synthetic owners isolate table algebra; they do not qualify a real soil model
or complete MICRO root-uptake physics. Documentation and manifest hashes are
required before component admission. Default production uptake is unchanged.

Independent full MICRO nonlinear uptake, typed configuration, hydraulic
provider binding, single final root sink, signed hydraulic redistribution,
salt/osmotic composition, transaction and committed restart remain open.
This contract admits no frost capability and no external Jarvis/Walsum-after-
MICRO option. The frozen Status-A denominator remains unchanged.

Qualification also requires rejecting finite but overflowing table samples and
wet extrapolation requests before arithmetic traps, with previous-table isolation.
