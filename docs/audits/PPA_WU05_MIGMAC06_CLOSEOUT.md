# PPA-WU05-MIGMAC06 hydrostatic rapid-drain reference construction

Date: 2026-10-05. Status: CANONICAL_PRODUCTION_ADMITTED_CLOSED.
Canonical base: 7a877af47144689bf8f9feb8c5485f6320dda137.

An explicit configuration preparation call derives the existing immutable
rapid-drain reference KD. The hydraulic owner supplies reference moisture at
head=drain_level-z, evaluated by its selected retention model. The macropore
owner does not acquire a second hydraulic provider, accepted storage or history.
Existing supplied coefficients remain supported without changed semantics.

The preparation preserves B1.11 section D's reference level, compartment mapping
with the 0.01 cm tolerance, inclusive rigid-barrier detection, drain-type rule,
conditional 0.99 saturation cap and per-node static/dynamic main-domain geometry.
The source computes reference dynamic volume as shrinkage minus vertical strain.
Current crack history, minimum subsidence, matrix-area scaling and contracted-cell
volume corrections are absent from this reference construction. They remain part
of the independently admitted current geometry route.

The adapter assigns KD only after successful validation. Invalid input leaves its
configuration unchanged. A valid zero reference KD disables the rapid route, so
an isolated tube or empty connectivity cannot create zero resistance at runtime.
The preparation is for contiguous surface-based centimetre grids, one drain type
1 or 2 and an enabled admitted mixed-law shrinkage carrier. Static-bottom and
drain levels must lie in the grid. It is called before the configuration becomes
immutable for trial execution, never from inside a Richards trial.

The independent 70-digit Decimal mixed reference coefficient is
0.2068154836193743352226502591721680100436897696791434941783071500365899.
The exact source section-D block is assembled unchanged against independently
computed shrink fractions and fixed moisture callbacks. This checks source mapping,
geometry and rigid disconnection; it does not claim a new whole-model watcon oracle.
Existing constitutive source authorities remain the law-equation evidence.

Initial verification failures are retained as findings. First, reusing the
MIGMAC05 current-capacity oracle produced 0.1624326584677300 instead of the reference
0.2068154836193743 because current geometry has contracted-cell corrections.
The incorrect test oracle was replaced by the independent reference equation;
production was not altered to match it. Second, the Reference fixture called its
hydraulic provider before binding its parameters. The fixture initialization order
was corrected. The supplied-coefficient comparison also initially used an incompletely
prepared shrinkage carrier without its mapped surface node. The fixture now completes
the same node mapping as the initializer before calling the pure preparer. These
failures required no tolerance change or production physics repair.

All 12 controlling final gates exit zero at O0/O2. Supplied and adapter-derived
Reference trials agree byte-for-byte for mixed laws in dry, wetting and two-domain
rapid-drain modes. Retry, A/B/A and accepted restart pass. A8/A10/MIGMAC01/PERCH20
and original MIGMAC02/03/04/05 geometry/runtime preservation pass. Exact source/test
postimages and completed gate receipts are recorded in
`integration/audits/PPA_WU05_MIGMAC06_QUALIFICATION.json`.
Scope excludes multiple or within-compartment drain runtime, covering-layer
composition, automatic retention selection, new surface owners and whole-model
equivalence. Broad migration remains incomplete and frozen Status A is unchanged.

The all-law independent Decimal KD 0.3008777038059482773004107783516246 also
agrees with the unchanged assembled source block at both optimization levels.

## Canonical admission

PR #1023 merged qualified tree `4f3cc35bfdd7400da1f97d4cdad69403a5622fcb`
at `6b7c13821d4c3dc94c504b1c0584f8203a9154f5`. Published qualified commit:
`c9e16b671eb587de1e449789afcf21c7d85d6cb1`. Merge comparison contains no changed
files. All 45 source/test postimages remain exact. Closeout changes documentation
and admission status only.
