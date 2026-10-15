# MC-SOL01 accepted matrix water age

Proposed bounded successor to canonical9ed5efc773b28f44b16b8922730b3fd9b8892b60.
PR1232 independently owns the reactive N day; this unit does not duplicate it.
Selective donor1117 is b6b894513fcdcf66e94824742c129616ddd7aed1.

The existing B1.11 age substep is the process authority. Independent tests extract
the unchanged age loop from SWAP/solute.f90 lines939..987, source SHA256
2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2.
The historical in-place node sweep and its numerical dispersion remain literal.
Age amount is water depth times days, cm day per node; concentration is days.
It is not chemical mass. Production is the trapezoidal accepted water volume
times elapsed days. Root extraction removes local age without a chemical TSCF.
Signed lateral drainage and lower inflow use the historical Agedrain boundary.
Internal transfers cancel; production plus external age input minus exports must
equal the change in total age amount. No correction/clipping can hide overdraw.

An additive private age owner consumes only the existing actual accepted water
trace. It verifies time, source attribution, every vertical interface and water
closure. The joint application keeps both candidate water and age tentative until
the whole interval succeeds. Rejection, retry and rollback retain committed state.
Opaque and bounded same-platform disk restart retain age amount, water endpoints,
clock, revision, immutable geometry/dispersion/boundary parameters and actual
Richards continuation. Kernel state and existing matrix/mineral layouts are unchanged.

Bounded profile: zero top exchange and pond, no rain/irrigation, macro/SSDI,
aquifer, snow, thermal coupling, chemical or crop N coupling. Prescribed age of
external inflow is not a new aquifer store. WOFOST81 is untouched. This implements
one age route, not all SW431-AGE-TRACER surface/output semantics.

Affected invariants3,4,7,9,13,21,22,23,27,29: explicit optional companion state,
read-only accepted water, atomic commit, generic intervals and hard age balance.

Test selection: first the three-provider real process closure with literal oracle,
then real Richards composition, complete balance, donor directions, invalid input,
multi-window, rejected-prefix atomicity, smaller retry and fresh-process restart.
O0/O2 run separately and retain raw costs. Composition is expected about two minutes
from the existing matrix qualification, full moving about30minutes. Broad preservation
is selected only if the stable admission source guard must change, under existing
F-CI owner authority. Highest low-air remains NOT_SELECTED_POLICY. No test PASS or
canonical admission is claimed at this initial contract checkpoint.
