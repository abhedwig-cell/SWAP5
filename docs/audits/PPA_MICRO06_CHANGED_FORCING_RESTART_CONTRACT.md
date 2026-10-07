# PPA-MICRO06 changing forcing and committed restart

Status: local O0/O2 qualified, stacked draft, canonical admission pending. This work unit changes no
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

The local result records a first-interval uptake of `1.0e-4 cm/d` and a
second-interval uptake of `2.0e-4 cm/d`. Changed root density also changes
the nodewise distribution. Uninterrupted and restored workers have identical
sink vectors at every accepted substep and identical mass receipts and end
time; hard mass accounting and the ROOT-HYD01 preservation runner pass in
both optimization modes. The source and output manifest is
`docs/audits/evidence/PPA_MICRO06_CHANGED_FORCING_RESTART_LOCAL.json`.

The full stacked source and runtime gate also passed on the PR merge
postimage in run 37428720498. The five manifests and O0/O2 logs are retained
in `docs/audits/evidence/PPA_MICRO06_STACK_PERSISTED_REPLAY.zip` and indexed
in `integration/audits/PPA_MICRO06_STACK_QUALIFICATION.json`. This is a
qualification of the declared normal-uptake envelope, not a decision to
admit the stack to canonical Status A.

Affected invariants: 3, 5, 7, 13, 21, 22, 23, 25.
