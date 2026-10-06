# PPA-MICRO06 changing forcing and committed restart

Status: proposed stacked qualification on MICRO05. This work unit changes no
production physics. It exercises the opt-in normal de Willigen route over a
committed interval, followed by changed potential transpiration and root
length density in a second interval. The source `rootextraction.f90` calls
MICRO per rate evaluation and passes the current `ptra` and `Lrv_node`; the
runtime must likewise re-evaluate one sink from the accepted hydraulic state
and the new forcing, rather than retaining the previous trial's sink.

Export the committed first interval through the owning Restart bundle and
restore it to a fresh backend. The uninterrupted and restored second trials
must produce identical accepted substep root sinks, mass receipts and end
time at O0 and O2. Both must close the hard water balance. A changed
transpiration demand must alter the total sink. No MICRO scratch, MvG tables,
forcing or horizon map are added to committed state.

This qualification covers bounded two-interval normal uptake with a declared
two-horizon first-node map. It makes no claim for crop ET generation, oxygen,
salinity, frost, hydraulic lift, de Jong van Lier or full-model equivalence.
It does not admit the draft stack canonically.

Affected invariants: 3, 5, 7, 13, 21, 22, 23, 25.
