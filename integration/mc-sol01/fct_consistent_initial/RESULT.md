# Consistent native initialization observations

Six actual0.4day41/82/164cell O0/O2 runs pass. The initial water stock is
35.60032212169341cm; chemical stock71.69708429000082mg/cm2. Both spreads across
all grids are9.948e-14. Independent van Genuchten evaluation at uniform-100cm
and exact ramp integrals26cm/64cm in the two materials reconstruct these stocks
without normalization. Linear sorption is selected; no nonlinear quadrature
equivalence is claimed. Original imported hydraulic and sorption parameters stay
unchanged. Empty initial surface replaces the failed positive-pond pilot.

Conservative total-chemical L1 differences between common41cell bins decrease
from0.00819778563mg/cm2 (41/82) to0.00342687470mg/cm2 (82/164). O0/O2 agree
exactly. Maximum independent water/chemical balance residuals are1.685e-13cm
and1.488e-13mg/cm2. Real root uptake/drainage and gross source inputs remain.
This removes the previous initial-stock confound in this separate constructed
experiment. It is not an absolute-error oracle or general nonlinear accuracy
proof, and should not be compared numerically with the different PR1423 forcing.

The wet uniform-head pilot rejects in the hydraulic owner before chemistry,
at the first window. Its raw result and successful dry control are preserved.
No tolerance/solver/balance assertion was relaxed. Wet-to-empty PR1419/1423
evidence remains separate. All raw successful/failed files, source snapshots,
commands, hashes and four evidence controls are retained. Build metadata binds
exactly to PR1423's immutable compiler/source capsule; current native inputs
remain byte-identical after the new competing-N-sink canonical admission.
The current composed owner is checked separately in OWNER.json in this capsule.

No production kernel/default changes, historical-year claim or capability
promotion. Remaining work: independent reference/error oracle for a bounded
transport envelope, hydraulic uniform-head/positive-pond rejection diagnosis,
and upper-face chemical return before wider historical forcing.
