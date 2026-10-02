# TOP03 unsaturated contact prerequisite: stationary-layer factorial

Date: 2026-10-02. Proposed test-only research; no production admission.
Workstream/work unit: SW-RIB / SW-RIB-TOP03. Baseline: dedicated branch
`89913ab29b8916249893289bd9bd4a265bb8d8b3`; inspected canonical
`800f6a9b429ed2a392e4c3778951bb92eca042aa`. PR #956 remains draft.

## Question and bounded choice

The preceding study falsified constant saturated R in 24 ready comparisons.
Before deriving a boundary-only nonlinear elimination, establish whether a
stationary nonlinear layer is an adequate reduction of the storage-bearing
layer. Retain its algebraic pressure unknowns in this experiment: this is an
independent discrete stationary closure oracle, not an implemented Schur
elimination or a production constitutive material. No inference of negligible
storage is permitted merely because the layer is geometrically thin.

Change only two layer factors, independently: K(h) versus fixed Ksat, and
physical retention versus identically zero storage change/capacity. Keep the
same explicit grid, surface pressure and underlying matrix face conductance.
The massless diagnostic fixes layer water content to its origin value while
computing K from the unmodified physical theta(h), never from that diagnostic
water content. Its algebraic rows enforce equal face fluxes and own no water
increment. Do not publish this diagnostic as a physical material. A stateful
reduction would separately own the actual layer storage and separate its top
and matrix-side transfers.

Modes: 1 full physical layer; 2 previous constant-R reduction; 3 nonlinear
K(h) algebraic layer; 4 Ksat algebraic layer; 5 Ksat with physical retention.
Mode4 versus mode2 diagnoses the previous matrix half-cell law without mixing
it with nonlinear K or storage. Mode3 versus mode4 isolates layer K. Mode1
versus mode3 isolates storage with matched geometry and face laws. Mode1 versus
mode5 provides the complementary conductivity test with storage retained.

## Fixed scope and gates before execution

Use L=0.20 cm, R=0.50/1.00 day, m=8/16/32, ns=128/256/512 per stage.
For explicit modes use both dry and prewetted layer origins, holding the matrix
at -123 cm. Mode2 has only the original dry matrix origin. This gives 162
six-event trajectories and 30 independent saturated Darcy controls per build.
All forcing, durations, bottom mode7, geometry, retention coefficients and
real Richards policy are exactly those in the persisted explicit-layer study.
Controls use the separately labeled steady saturated bottom mode5. Methods,
tolerances, mass hard gate and origin immutability remain fixed. O0/O2 use
GNU Fortran 13.3.0 with bounds and floating-point traps.

Retain and classify all numerical failures. Do not change the production
solver, constitutive cutoff, exact-state BASE controller, receipt/commit,
rollback/restart or mass ownership to help a diagnostic finish. R=0/R=0.05
and L=0.02 cm remain outside this new ready-reference envelope.

Before physical classification, apply the preceding extension's eventwise
space/time prerequisites independently to every compared mode: finest three
ns at m32, finest three m at ns512; shrinking top/bottom/water differences
unless <=1e-10 cm; finest-pair budgets 0.001 cm + 0.5% for top/bottom,
0.001 cm water L1 and 0.1 cm head infinity. Keep physical budgets unchanged:
0.005 cm + 2% reference transfer for top, bottom and matrix interface;
0.005 cm water L1 and 0.5 cm head infinity. Failed prerequisites yield null,
never a physical pass/fail. Independent mass <=1e-10 cm, saturated control
head <=1e-9 cm and flux <=1e-10 cm/day are hard gates.

Primary falsifiable claim: mode3 is physically equivalent to mode1 for every
ready event/origin in this bounded envelope. A failure retains independently
owned storage as a prerequisite for the nonlinear boundary reduction; it does
not falsify nonlinear conductivity as a mechanism. Report every event, not
only final heads. Mode1/mode2 trajectories must reproduce archived identical
cases exactly, and O0/O2 output must agree exactly. Report optimization
mismatches or inherited-trajectory mismatches before physical conclusions.

## Recovery and authority boundary

Persist this document, the provider, fixture, runner, analyzer and updated
status remotely before compilation. The single next incomplete gate is this
local O0/O2 matrix. A checkpoint is not a stopping instruction. Evidence will
include raw records, compiler/source identities, decision and replay checks.
Invariants 3/7/11/13/28 remain controlling; production and shared interfaces
are read-only. Qualification is bounded model-form verification, not measured
crust parameters, TOP03 temporal acceptance, transaction admission or canonical
reconciliation. Storage/external pond ownership and the real top-active
transaction path remain separate open contracts.
