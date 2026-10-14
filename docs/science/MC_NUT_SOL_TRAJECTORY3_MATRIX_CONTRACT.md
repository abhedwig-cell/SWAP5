# MC-SOL01 trajectory 3: accepted matrix transport with sorption and decay

Status: joint physical matrix route qualified and preserved; central regie ADMIT authorized, safe merge pending.
Original baseline: `82209d0df68d14c5ebe707e9b6303f9b150488ca`.
Current reconciled canonical: `34ee4fdac815788620f8779f4340b8edeef3c8ae`.
Donor: PR #1117, `b6b894513fcdcf66e94824742c129616ddd7aed1`.
Recovery: `integration/audits/MC_NUT_SOL_TRAJECTORY3_STATUS.json`.

## Actual change and authority

The existing donor owner qualified its component and transaction postimage in
run37778763469. That is not qualification of integration with today's canonical.
This successor imports only five chemical process modules and their focused
scientific drivers. It excludes the donor's historical crop/root changes,
reactive global layout, shared restart/backend edits and Soil-N/crop-N owners.
No existing production source file is modified.

The new callable application route is
`src/runtime/mod_fmr_b111_matrix_joint_application.f90`. It uses the established
backend's successful water candidate and internally accepted substep traces,
advances the complete chemical candidate through
`src/runtime/mod_fmr_b111_matrix_solute_route.f90`, and commits both owners only
after all checks succeed. It is a one-way water-to-chemical physical composition:
it does not supply root salinity stress or feedback to the preceding water solve.
The native integration driver calls the actual joint application and Full
Richards. Original standalone carrier tests remain a narrower process boundary.
This is not default CLI/bootstrap enablement or a claim that all NUT/SOL donor
functionality is integrated.

Historical authority is the existing byte-pinned B1.11 bundle, member
`SWAP/solute.f90`, SHA256
`2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2`.
The independent oracle extracts the literal transport/reaction loop, linear
inverse and interface carry from lines361..432,442 and455. It does not call the
production process. The source contains the surface and aquifer branches too;
their presence does not qualify those branches here.

The original source keeps `cmsy` (total mass per soil volume) across the hydraulic
step. Its decomposition expression uses the new `theta` and the concentration
before the node update. The old donor validated beginning dissolved storage
against ending water content; its fixed-water carrier test did not expose this.
This successor supplies `theta_previous` separately, validates the initial mass
against it, keeps total chemical mass independent of water reweighting, evaluates
the literal ending-theta decay density, then repartitions against ending water.
The optional absent `theta_previous` retains the donor's fixed-water process
callers only. The accepted-carrier service always supplies both endpoints.

## Bounded physical and state contract

- Linear Freundlich (`frexp=1`) dissolved plus sorbed matrix storage is enabled.
  The imported partition operator supports nonlinear parameters, but this
  application route rejects them until their changing-water source trajectory
  has its own independent oracle and qualification.
- Temperature/moisture/depth modified decay is a booked external mass sink.
  Historical SWHEA=0 sets its temperature factor to zero; it does not mean one.
- Internal advection and dispersion cross the same reconstructed vertical faces.
  Sequential source node ordering and the `cfluxt=cfluxb` carry are preserved.
- Positive root extraction uses `TSCF`; signed drainage exports the local
  concentration or imports the supplied drain concentration. A downward lower
  face exports the local concentration; upward seepage imports `CSEEP`.
- The selected top flux is exactly zero. Rain, surface irrigation, SSDI chemical
  input, pond/runoff transport, aquifer mutation, macropores and age are excluded.
  Nonzero unsupported water/source routes fail closed.
- Trace net node sources must equal minus signed drainage and root extraction.
  Water/storage/face closure is checked before chemistry. The tolerance argument
  is **cm per interval**, converted to cm/day by dividing by substep duration.
  The receipt reports interval residual in cm. This avoids mistaking a tiny
  interval's roundoff-amplified rate residual for failed water conservation.
- Units are cm, day, volumetric water fraction, mg/cm3 dissolved concentration
  and mg/cm2 column-area chemical mass. In this linear route bulk density is
  g/cm3 and Kf is cm3/g, so their product is dimensionless. Sorbed density is multiplied by `dz`
  exactly once; decay density rate is multiplied by `dt*dz` exactly once.

Persistent chemical state includes dissolved and sorbed masses, derived matching
concentration, consumed water endpoint, exact consumed clock, parameter identity
and revision. Immutable route parameters are supplied once and retained with
that companion. Other donor compartments remain zero, never hidden mobile mass.

Every carrier sequence advances a disposable copy. A failure in a later carrier
publishes no earlier successful prefix. Replaying an already consumed interval,
a gap, mismatched beginning water, an unbalanced carrier or a negative physical
candidate leaves committed masses, water endpoint, revision and clock unchanged.
A caller may retry a smaller accepted carrier or the original valid sequence.
Diagnostics of a failed attempt are not accepted external receipts.

The companion has a distinct private typed schema1 restart payload. Export and
restore preserve all physical and continuation fields and reject a different
parameter identity. Opaque in-process restart and subsequent consumption are
qualified here. The joint successor also qualifies an opaque joint FMR/chemical
bundle and `src/adapter/mod_matrix_joint_restart_file.f90`: a bounded same-platform
binary file with CRC32, exact immutable chemical configuration vector and schema,
shape, clock, identity and nonnegative/equilibrium validation. It retains the
actual Richards derivative history. A fresh process reruns both water and
chemistry and reaches a byte-identical endpoint. Wrong clocks, negative chemical
revision and invalid dimensions are rejected even with a recomputed valid CRC;
truncation and byte corruption are also rejected. The existing water-owner
restart contract and global mobile-only layouts are unchanged.

Affected invariants:3,4,7,9,13,21,22,23,30. The route consumes accepted fluxes and
has no solver-internal knowledge or new water owner. Canonical admission needs
central review of this bounded companion contract; source equality and local
O0/O2 alone do not authorize widening application or restart scope.

## Proportional qualification and reproduction

```bash
python tests/nut-sol/run_matrix_route.py
bash tests/physics/run_b111_reactive_solute_substep.sh
bash tests/physics/run_b111_sorption_mass_closure.sh
bash tests/physics/run_ppa_wu05e_mobile_salt.sh
```

Use `FC`/PATH for the compiler and `MATRIX_RESULT_DIR` for the raw result directory.
The matrix runner records input hashes, exact tested commit, independent source
pin, compiler, generated oracle/fixture hashes, complete per-command output and
compile/link/native costs. It compiles the real backend closure with the existing
consistent grid fixture and the real legacy HeadCalc; the grid fixture's filename
is not selection of a highest low-air computation. Failed attempts are retained
separately. No persistent cache or new general testing framework is introduced.

The smallest inherited production process closure is six modules. The actual
accepted backend driver necessarily has a larger closure because the established
trace type lives with the serialized backend. This is a dependency justification,
not permission to rerun unrelated frost or highest low-air qualification.
No shared water, solver, crop, root, layout or restart source changed. Full moving
F-CI and canonical admission remain separate owner decisions. Their PASS is not
inferred from these scoped tests.

## Remaining MC-NUT01 and MC-SOL01 routes

The exact master snapshot and14 relevant dispositions are reconciled in
`integration/audits/MC_NUT_SOL_TRAJECTORY3_COVERAGE.json`. No full capability row is promoted by
this bounded route. The master has a stale aquifer description in its
matrix decay row; matrix decay has no aquifer dependency. The donor's claim that
all implementation gaps are closed is limited to that branch, not today's
application reachability.

| Remaining block | Existing donor authority / first ready action |
| --- | --- |
| Matrix nonlinear sorption | Qualified partition operator exists; discriminate the corrected inverse and changing-water source semantics before extending this route. |
| Pond/rain/irrigation/runoff | Existing pond operator; bind accepted surface water and source receipts, reconstruct complete surface mass, then atomic continuation. |
| Water age | Qualified donor age operator; independent accepted-carrier age amount and age production, separate from chemical mass. |
| Mineral Soil-N and transport | Existing donor pool and aggregate transport owners; reconcile a bounded accepted daily NH4/NO3 route and whole-N restart before crop coupling. |
| Nitrification | Depends on admitted mineral inventory/transport; bind equal NH4 loss and NO3 gain, not independent unbooked rate formulas. |
| Organic turnover and denitrification | Donor reference-correction decision and Cdissi/rates need central acceptance; then coupled whole-N reaction route. |
| Amendments and residues | Pool/addition owners exist; amendment-calendar source-policy conflict remains open. Residue state requires the current accepted crop lifecycle owner. |
| Soil-N/crop-N and fixation | Donor coupled owner exists; reconcile current crop owner and explicit B1.11 policy. Preserve accepted WOFOST81 semantics. |
| Aquifer SWBR | Master REJECTED source-defect disposition. Any new route needs an explicit physical aquifer storage/density/coefficient decision and signed multi-substep oracle. |
| Default application and feedback | Joint clocks, atomic commit and bounded joint disk restart are qualified in this candidate. Default bootstrap/multicolumn application and optional salinity feedback remain separate. |

The next limited dependency-ready production block is matrix nonlinear sorption
qualification or an independent water-age carrier. For MC-NUT01, begin with the
existing mineral inventory plus aggregate transport transaction, preserving its
daily clock and whole-N accounting. Do not begin all organic, management, crop,
aquifer and age integration simultaneously.

## Qualified joint successor (2026-10-14)

The continuation work adds an application-level joint boundary, using only
existing backend trial/commit/discard and FMR restart interfaces. Its declared
owned surface is the new matrix companion and additive joint runner/codec.
Water, kernel, solver, crop/root, mobile-only layout and existing persistence
interfaces are read-only. No new physical scope or solver policy is introduced.

The joint runner stages a successful water candidate and consumes its internally
accepted substeps on a chemical copy. It commits the water candidate only after
the complete chemical sequence succeeds, then publishes the chemical endpoint.
Hydraulic rejection, chemical failure or water commit failure publishes neither
chemical mass nor a partial consumed clock. Worker scratch remains disposable.

The bounded disk adapter must preserve the existing FMR committed provenance,
base/temporal physical state and actual temporal derivative history, plus chemical
masses, concentration, carrier endpoint/time/revision and parameter identity.
It validates a complete decoded joint payload before restoring either owner.
Its schema is restricted to one ordinary base/temporal matrix column with inactive
other optional stores. Immutable parameter identity and exact parameter vector
must match the externally reconstructed configuration. Native binary bytes are
same-platform restart support, not a portable cross-compiler file specification.

Completed successor evidence: standalone parameter/state reconstruction negatives;
actual joint water/chemical rejection and retry with unchanged owners; joint
in-process restore followed by independently rerun water/chemical continuation;
fresh-process disk restore and byte-identical resulting endpoints at O0/O2;
truncated/corrupt/wrong-identity/wrong-clock payload rejection without target
mutation; source and existing process preservation. The stable combined run
compiles237 sources per optimization once for both actual physical drivers.
Both optimizations: compile123.430s, link0.393s, native9.542s. Native time includes
normal physics, rejected/retried physics, fresh-process replay and corruption
checks. Per-codec cost is UNKNOWN, not inferred from that total.
The stable admission decision remains routed to central SWAP5 regie under the
canonical workstream registry. No new mandatory long stress gate is selected.


## Stable admission evidence (2026-10-14)

Central regie selected complete moving preservation at the mandatory stable
admission boundary. The exact additive matrix source and two existing source
guards were reconciled without authorizing any existing production mutation.
The original CO2 evidence controls (23) and six additive delta/postimage negatives
pass. All238 targeted science and all6211 tracked moving-execution inputs were
verified unchanged before closeout.

Complete local moving preservation passes in1825.021552 seconds (OFF mode).
The first25.351-second B19 source-whitelist failure remains retained separately.
Compile/link/native breakdown within this broad shell is UNKNOWN. Automatic
canonical F-CI run38631988831 also passes all15 jobs, including14 frozen
authorities and current moving preservation. The existing short bounded
heat/frost runtime assertions executed inside that mandatory gate; the retired
highest low-air qualification was not selected. Raw logs, inputs, controller
results and historical red-check attribution are in the admission capsule linked
from the existing work-unit status.

The regie decision admits only this matrix joint route after safe expected-head
merge and source verification. All14 NUT/SOL dispositions and243-capability counts
remain unchanged; the separate existing master authority receives a bounded
receipt and correction of its copied decay/aquifer claim. Its untouched baseline
checker already fails with stale inheritance baseline, which remains an explicit
master blocker. Thirteen unrelated historical/research Action workflows retain
their inspected failures; no whole-repository green-check claim is made.
