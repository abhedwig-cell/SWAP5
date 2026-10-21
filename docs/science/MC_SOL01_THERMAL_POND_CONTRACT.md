# MC-SOL01 dynamic thermal pond and file application

Proposed successor, baseline fda2a6de35ab60e8c836a6687482efa3774d95dc.
This implements the requested composition of the existing numeric heat and
nonlinear soil Freundlich 0.5..2 routes with the accepted persistent dissolved
pond. It reuses production water, heat, surface mixing, transport and decay.
There is no sorbed pond pool and no new process equation.

Within each explicit reporting/coupling interval the detached Reference
water/heat endpoint supplies a node temperature vector to all that interval's
accepted chemical water receipts. This is the already admitted endpoint split,
not historical substep-temperature identity. Coupling interval refinement is
required; a long run alone does not establish seasonal accuracy. Original
chemical configuration remains immutable. Original external water/heat and
chemical owners publish together only after whole water/solute balance and
endpoint alignment pass. Heat-off retains the historical zero decay factor.

A separate S5PT0001 same-platform POSIX generation carries the physical
water/heat state, chemical configuration, dissolved/sorbed inventories and pond
mass. It uses the existing CRC, staged file, fsync, rename and directory fsync
publication pattern. All identities and owner matching precede either assignment.
This route uses no numerical history, matching the existing evolving pond
forcing contract. S5MT0001 and incumbent joint codecs remain unchanged.

The opt-in file application gains explicit nonlinear/decay/thermal inputs;
legacy inputs retain disabled heat, linear sorption and zero decay. Numeric heat
uses explicit surface temperatures and a zero bottom heat flux; no pond heat
capacity or heat exchange law is invented. Surface temperature is a prescribed
soil heat boundary. Seasonal meteorological derivation remains outside scope.

Affected invariants: 2, 3, 7, 9, 13, 21, 23, 25, 27, 29. No solver, tolerance,
retry or physical acceptance change. Select focused O0/O2 actual production
composition, independent literal/quad oracle, gross sources/losses, heat-off,
chemical/hydraulic rollback and retry, refinement, native restart and semantic
CRC negatives; fresh original file-application preservation. Estimated compile
180 seconds and native assessment under 180 seconds initially. Reuse only exact
same-session provider artifacts; physics-only timing UNKNOWN. Full moving F-CI
NOT_SELECTED_IMPACT pending evidence; highest low-air NOT_SELECTED_POLICY.
RossFast frozen, aquifer excluded. Full historical .swp/default, snow/exfiltration,
analytic heat and age/N companions require separate authority.
