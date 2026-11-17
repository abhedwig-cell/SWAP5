# Local short irrigation temporal policy

Baseline actual canonical67ddba2692cc13f89cfc29100836f2d6a4b80eec. User requests
implementation, bounded model costs, O0/O2 full water/chemical1096, exact native
restart and original431 comparison, delivered through a PR. Previous causal
proof b473d1523: improved pond derivative accepts underresolved0.04day irrigation
steps; first-order refinements reduce2.70681cm difference to0.00118cm.

Implement an explicitly selected experimental numerical policy over original
adaptive TimeControl, limiting only active short surface/sprinkling irrigation
to duration/2048 (respect existing dtmin). No equation, tolerance, forcing/table,
default project or Newton convergence rule changes. Cap both the initial case9
proposal and later get_dtevent; original event and day limits remain in force.
Derive cap from existing owned gird/dt_irr_event/clock; no saved field, implicit
history or snapshot conversion. Metadata binds selected generator and emitted
TimeControl. Reject unsupported frost/snow/macro and missing/foreign policy.

First real original TimeControl O0/O2 component and 5day water/chemical trials;
measure pulse accuracy vs preserved refined431, mass and model time. A cap is
not a general local-error estimator; qualify only observed selected scope.
If two approaches fail, reassess. Then complete4x1096, own2to4/4to6/199to201/
365to367/530to532 (plus terminal), origin integrity, independent-instance and
external rollback/recovery using existing APIs. Full model cap30s per trajectory,
reference20s; retain any failure/censor. Baseline4 full runs may be measured for
paired timings/unchanged off-pulse controls without a broad performance campaign.

All existing water/solute1e-10 guards and scientific criteria stay unchanged.
Original B0 comparisons remain separately classified from refined short-time
controls. Reuse literal archived inputs and fulls only at exact dependencies.
No named-release/default policy promotion or all-option claim. Publish actual
code, reproducible commands/source/build/input/raw and scope in a focused PR.
