# DATAQUAL02 original positive surface demand

Baseline ad62053833bbd2a5f40a493db89ae4b02cd11a46. RT/VQ adapter owner.
Implemented candidate, not yet tested or admitted. Continues issue1458.

The original native application prepares positive soil/pond evaporation demands,
but feeds them only to the Rutter carrier. Boesten owns the actual empirical
reduction and needs those same existing potential fields. PR1457 at51439058
identifies this two-assignment omission; its continuous-wall, Jacobian, coupled
hydraulics and long-run evidence are NOT inherited or imported.

Explicit `--source-surface-demand` requires experimental mode in BOTH the Python
adapter and native executable. It maps the original demands into the existing
Boesten forcing at every original source event. Default is false. The corrected
source tag enters prepared input, configuration identity and file restart binding.
This is a physical-source mapping correction, not an admission-only bypass and
not a numerical policy. Existing processes, equations, tolerances and balances
are unchanged. Production/comparison defaults retain their exact old mapping.
Experimental execution may be compared with references without claiming parity.

Invariants3,7,13,21,23,26 remain controlling. No kernel state/schema or core
process implementation changes. Root oxygen remains independently selectable.
Reject unknown variant, nonexperimental activation, foreign restart and invalid
physical input. Retain independent supplied-source balances, rollback and exact
same-variant source-event/day restart. Availability exclusions remain intact.

Selected: rebuilt native adapter against hash-verified unchanged physical
providers, original day1/days1-2 O0/O2, matched demand-on/off first batch, positive
Boesten drying history, reference deltas, active-root composition, fresh same-
variant restart and foreign/mode controls. A single changed-forcing continuation
from its OWN day2 file may measure whether this omission explains the2.495 cost.
No unchanged long prefix replay, fresh481, broad F-CI, low-air or RossFast.
