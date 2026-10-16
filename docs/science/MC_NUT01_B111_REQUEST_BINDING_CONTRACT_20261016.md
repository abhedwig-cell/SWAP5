# B1.11 request policy in the existing crop/Soil-N transaction

Status: affected local O0/O2 science and27 admission controls PASS; canonical admission pending.
Base: canonical 093bff909f38f8bfa3b1284b40a0c3736e864954.
Owner: MC-NUT01, existing crop_soil_state_t. Invariants: one persistent N owner,
accepted-only publication, independent whole-N balance, atomic rollback and restart.

The already-qualified B1.11 demand/fixation component is selectable only by an
explicit optional crop configuration. Absence preserves every existing WOFOST81
request, equation and restart byte. This is a request-policy composition with the
existing WOFOST81 growth, senescence and N-allocation owner, not full B1.11 crop-N
or translocation equivalence. WOFOST81 remains the default and is not rewritten.

The selected request uses pre-growth leaf/stem/root masses and committed organ N,
the existing maximum-leaf-N table at committed DVS, and explicit DVSNLT/NFIXF.
Stem/root maximum fractions use the existing configured concentration ratios.
No growth or storage-organ demand is added. The strict DVS/RELTR gates, literal
root+stem+leaf addition and independent NFIXF and (1-NFIXF) products are retained.
The existing prepared request is replaced completely, including zero translocation;
its WOFOST81 fixation cannot survive as a second input. Only the existing apply
operation books the one fixation input and actual soil supply.

Historical B1.11 suppresses allocation at total demand <=1e-5 kg/ha even while
booking nonzero supplied/fixed N. Active positive demand in that interval is
rejected before soil mutation; it is neither silently clipped nor admitted as a
mass-conserving source profile. Zero and gate-disabled demand remain valid.
Only the explicit vegetative uptake phase below the WOFOST81 translocation onset
is selected: a B1.11 request must not silently disable an active translocation
process. DVS at/after that onset is rejected. Full reproductive translocation,
B1.11 residual-concentration death and root-translocation rules remain open.

Immutable policy fields append a tagged configuration suffix only when selected.
Opaque restart copies the existing configuration and ledgers. Existing native
restart retains and compares the complete vector, rejecting missing, mismatched
or corrupt policy before publishing any owner. No new persistent mass store or
second codec is added. The consumed soil clock rejects duplicate day events.

Required evidence: literal request discrimination, nonzero fixation with zero
WOFOST81 fraction and vice versa, no growth/storage uptake, zero/full NFIXF,
DVS/RELTR boundaries, ample/limited/exhausted soil, whole-N balance, no replay
or rejected-trial leak, actual Richards composition, opaque and fresh-process
native continuation, policy identity negatives, and unchanged default drivers.
Use existing real production closures with measured compile/link/native costs.
Do not rerun RossFast, highest low-air or full F-CI merely for imports/source
pinning. Admission still requires current affected owner proof and preserved
unchanged defaults; no missing proof is relabelled PASS.

## Executed qualification

The cold shared build executed the original crop/soil, mineral and reactive
programs, all original native decoder negatives and the selected request route.
Seventy-two real soil/crop cases per optimization discriminate strict gates,
zero/full fixation, exhausted soil, one fixation ledger, whole-N and replay.
Actual accepted Richards composition retains reaction/carrier rejection, retry,
whole-N and opaque/native fresh-process identity. Missing and changed policy
identity reject before publication. Original default crop/mineral/reactive native
endpoints match the immutable original crop-supply capsule byte-for-byte.

The additional existing modular-runner leaf covers the next-representable RELTR
boundary, tiny active demand refusal, distinct three-organ deficits, discarded
growth/storage demand, reproductive refusal and invalid policy. O0/O2 PASS.
The literal593-case request component,39 invalid inputs,1806-case WOFOST81
arbitration and original WOFOST81 edge owners PASS. No WOFOST81 source changed.

The first complete cold route took385.297s:220.426s providers,26.085s drivers,
2.640s links and136.147s native execution, above its250s estimate. This includes
all original incumbent physical programs; the entire route was not repeated.
The additional boundary leaf took8.29s total. Its first harness attempt refused
a fixture include before compilation; explicit small parameter/table construction
resolved this without changing the dependency guard or a scientific assertion.
Raw failures, exact inputs, successful native records and default-body projections
are sealed in the existing MC_NUT_SOL_STATUS.json successor section.

The new choice changes the selected request, not the default equations, common
solver, persistent mass layout or codec. Exact inverse islands recover every
existing modified production/test/owner body, and the full admitted incumbent
proof executes at its immutable canonical baseline. Together with fresh affected
mass/rollback/restart science this selects no full numerical F-CI, RossFast or
highest low-air rerun under the binding change-impact policy. No full historical
SW431-NUT-NFIX admission or master-count promotion follows.
