# MC-SOL01 persistent surface-mass restart prerequisite

Status: bounded prerequisite qualified;26 admission controls and source/strict
documentation checks passed. Canonical admission remains separately recorded.
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

## Measured candidate and preservation boundary

The existing `tests/nut-sol/run_surface.py --surface-restart` compiles the real
private matrix/kernel/bootstrap closure once per optimization and separately
links/executes the unchanged zero-pond driver and the new surface-store driver.
The latter is generated from that same fixture plus
`tests/nut-sol/surface_restart_contract.inc`; it does not copy production physics.
The larger261-provider closure is caused by the real private accepted-state and
restart interfaces, not replaced with mock water trajectories. Provider artifacts
are shared only inside this live session with identical compiler/flags/source.

Execution `1e6f4a19452a2793b7d8ebe8bbba72ca4344879c` passed both O0/O2:
150 literal process cases per optimization, all existing zero-pond signed water
and chemical balances, rollback/retry, opaque/native/fresh-process restart and
ten original decoder negatives; additionally persistent0.375mg/cm2 surface mass
through two actual zero-top-flux Richards windows, chemical-overdraw rollback,
opaque/native/fresh-process continuation, explicit import/export policy, refusal
before overwrite, seven reconstruction-domain cases and seven CRC-correct V2
forgeries per optimization. The original V1 files and continued endpoint bytes
are identical to the immutable admitted surface-composition capsule, not merely
equal to a newly generated expectation. New complete endpoint SHA256 is
`dd8d90f6d08671b1b4f9a7dd5784dd6d254f8effc96d9be95363d6cb751ebf74`.

Measured cold compile186.1617s is recorded precisely by category in the existing
status/capsule: physical179.0730s, extra driver6.6706s, process0.4180s;
links0.7898s; native+assertions30.1534s. Separately measured physics-only time is
UNKNOWN. This is one scoped observation, not a performance guarantee.

Only native codec and trusted reconstruction production source change. Matrix
transport, surface exchange, water backend/solver, crop/N/age owners, bootstrap,
old drivers, references and all original owner-control bodies are retained.
The owning exact-source successor validates the full scientific delta, inverse
source-island reconstruction, source-bound raw science, and the original
qualified material/root incumbent at baseline87bc1b1b. Default V1 and zero-pond
behaviour are re-executed here because those interfaces actually change.
Unchanged unrelated components are NOT_SELECTED_IMPACT, not a new numerical PASS.
No full F-CI/highest low-air/RossFast is justified solely by codec source imports;
all affected water/mass/rollback/restart assertions remain binding.

Master dispositions remain unchanged. This is persistent dry-surface mass storage
and restart only. No positive pond-water budget, infiltration from a retained
pond, dry-deposition forcing, runoff, simultaneous N/age companions or application
activation is admitted by this evidence. Those remaining claims need actual
water-owner receipts and their own physical composition in this existing PR/workstream.
