# MC-SOL01 persistent surface-mass restart prerequisite

Status: implemented candidate; not qualified or canonically admitted.
Baseline: `87bc1b1bc0e33d5df9cc460c56f7773209d40931`.
Owner: existing `matrix_solute_state_t` compartment `pond_mass`, existing
atomic matrix/water restart. No second physical pool, new reaction law or
new water owner is introduced.

The existing B1.11 reactive substep already carries surface `csurf` in the
compartment owner. Literal `solute.f90` lines346..355 retain that amount when
infiltration is absent. The admitted zero-pond supply route explicitly rejects
nonzero residue because native `S5MJ0001` stores only mobile/sorbed amounts.

This prerequisite adds explicit trusted reconstruction of the existing surface
mass (mg/cm2, finite0..1e12), and an opt-in `S5MJ0002` native record containing
that exact binary64 amount before the existing CRC. Default calls retain the
V1 layout and bytes. V1 export must refuse nonzero unsupported surface mass
before opening/replacing a file. Aquifer and age stores remain unsupported.
V2 import requires explicit `allow_surface_mass`; all decoding stays tentative,
and both accepted water and chemical owners publish together only after full
CRC/schema/identity/parameter/clock/state/storage validation. Existing opaque
restart already copies the whole compartment and must retain the same bits.

Invariants3/4/7/13/22/23/27 remain binding. No default activation, tolerance,
transport, root, drain or solver change. A static nonzero surface mass plus
zero accepted top flux is a persistence witness, not a pond hydrology model.

Selected qualification: local real O0/O2 native/opaque/fresh-process restart,
V1 compatibility and default refusal, no overwrite on unsupported export,
negative/nonfinite mass and CRC-correct decoder forgeries, actual accepted
matrix-water continuation and whole matrix-plus-surface mass. Expected300s
for one cold existing matrix/adapter closure; record compile/link/native costs.
No full moving F-CI, highest low-air or RossFast selected by this serialization
change. Owning source/evidence admission checks remain separate.

Full pond/source integration remains open: the current accepted per-substep
water trace does not carry pond begin/end, gross rain/irrigation, evaporation
and runoff separately. Do not infer these from net matrix top flux. Introduce
and qualify those actual water-owner receipts before nonzero pond-water
transport, runoff export or a dry-deposition forcing law is admitted.
