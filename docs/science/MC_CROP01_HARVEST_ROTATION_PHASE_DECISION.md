# MC-CROP01 harvest/rotation phase decision boundary

Status: bounded explicit crop/soil-N harvest candidate implemented and tested;
NOT canonically admitted and NOT full crop rotation. Canonical remains
`451e35ccd1797aa96fb4354dabc465cceff18635`; PR1247 holds the candidate. The latest
shared-owner resolution and execution closeout below supersede historical
missing-interface and generic-kernel proposal statements. The initial
investigation used baseline `7315be4f532c791fe008f76d0d4fc9855705a87e`.

## Authenticated source and retained invariants

Reuse `SWAP431_B111_AUTHORITY.tar.gz.b64` and exact source identities in
`MC_CROP01_ROOTED_WEATHER_PRODUCTION_STATUS.json:next_lifecycle_dependencies`.
Historical swap.f90 lines491/511/514/521/535 order growth3, harvest4,
integral/output, reset; the next morning orders TimeControl2, Meteo2,
croprotation2. Wofost task4 checks abs(t1900-cropend-1.d0)<0.1d0 and, for
annual sw_harv>0, DVS>=dvsend. Reset occurs after end-status output, not
before that observation. No source archive recovery is required.

The existing inactive WOFOST owner forbids allocated biomass/evolution
continuation. Preserve it by retaining immutable harvest end-status inside
the existing transactional crop owner while resetting its active owner.
Do not create an output/crop-state shadow owner or weaken validation.

## Actual shared phase gap

PR1209 commits current growth over positive [day,day+1]. At the following
morning, crop and accepted hydrology already have time day+1. A new season
must initialize after its authentic morning weather and before its own
hydrology, independently of acceptance of that day's end. Current kernel
advance_interval rejects t1<=t0 (mod_kernel_transactions.f90 line700).
Its candidate origin and committed revisions are opaque physical authority.
Reinitializing/wrapping the carrier to reset its time/revision, replaying an
already consumed weather window, or using a fabricated zero-duration interval
does not resolve this gap. Deferring initialization until that same day's
hydrological acceptance violates the historical daystart requirement.

The bootstrap additionally refuses lifecycle%harvested at daystart and when
binding rooted weather forcing. Calendar receipt binding only publishes
derived calendar/window retirement after a matching physical crop receipt.
The physical-calendar restart validator intentionally refuses fallow and
direct switches. Calendar select_at or caller crop numbers cannot authorize
the missing physical reset/start transition.

## Routed decision and dependent implementation

Owner: existing central RT/HY/F-KT admission with MC-CROP01/F-WOF38 and
calendar/restart owners. Route under workstream-execution-protocol shared
contract boundary; no independent alteration of kernel semantics.

Decide the source-bound morning initialization publication contract on an
already accepted previous-day carrier: either an existing admissible
boundary transaction/receipt composition, or an explicitly qualified phase
schedule retaining a real positive accepted window for morning publication.
It must cover adjacent crops as well as intervening fallow; no synthetic
crop-growth events or caller-only weather provenance. Define how biological
events, physical receipts, crop identity/parameters and independent soil
time remain distinguishable and exactly-once across both phases.

Then implement one coherent block: source harvest candidate/end-status,
owned reset, zero canopy/extraction in actual fallow hydrology, new-season
task2/task3/emergence through existing owners, derived calendar binding and
joint partial/pending/harvested/fallow/start restart. Qualify two authentic
crop periods plus adjacent switch, calendar and maturity harvest, final-day
flush, output-before-reset, positive/zero/positive actual extraction,
rejected transitions/rollback/retry/duplicates, mass, O0/O2, owner/full F-CI
and complete affected highest frost closure. No fullcap/count promotion
until that physical trajectory and remaining historical profiles pass.


## Current readiness after PR1241 and PR1246

Revalidated at canonical `47b652248420ba7c49df7e063c64ff749ce6253f`.
Both PR1241 (bounded daily SWRD3) and PR1246 (accepted thermal crop/soil N)
are merged. Their former concurrent-work overlap is no longer a blocker.
The phase gap above remains present in the current production interfaces;
neither admission adds physical harvest/fallow/new-season publication.

| Inspected production interface | Exact Git blob |
| --- | --- |
| `src/kernel/mod_kernel_transactions.f90` | `da7a00b6aec996cff504d8d30a90e51a8cce2162` |
| `src/runtime/mod_fmr_production_application_bootstrap.f90` | `e7f39d70b3554de6db5731b699b8068419ac9062` |
| `src/runtime/mod_fmr_wofost_crop_event_lifecycle.f90` | `a3ae3d607a1b82e5beeffac01d4b84ff4d63a384` |
| `src/process/mod_crop_senescence_residue.f90` | `fc6dc2f32c0b16c988857552737f9413b99b33d2` |

`kernel_executor_t` exposes positive-interval trial/commit and reference-floor
trial/commit. `kernel_advance_interval` rejects `t1 <= t0`. Its candidate's
physical state, origin revision and lineage remain private. `initialize`
refuses an initialized carrier and starts at revision zero. The trusted
reconstruction constructor explicitly serves persistence, refuses a live
target, and is not runtime publication authority. Reconstructing into a fresh
variable and assigning over the live carrier would bypass that contract.

`production_application_initialize_weather_crop_daystart` requires an absent
crop carrier, no active crop daystart, and water revision zero. It cannot start
a second crop after an accepted season. `run_weather_crop_daystart` rejects a
harvested lifecycle. `reconcile_committed_crop_event_receipt` takes the crop
carrier as `intent(in)` and retires only an already published delivery token;
it cannot publish harvest, reset or a new season. Thus neither constructor,
checkpoint nor derived calendar/window bookkeeping supplies the missing seam.

This is a source/interface finding, not a fresh numerical test or proof of a
general impossibility. No compiler/model execution is selected for rechecking
these unchanged interface exclusions. The current source identities above
allow the next owner to inspect only intersecting live deltas.

### Proposed next shared contract

Resolve the boundary with an explicit biological-event transaction at the
accepted physical clock, rather than passing a zero-duration interval to the
hydraulic solver. This remains a proposal for the RT/HY/F-KT and crop/calendar/
restart owners. It does not add or admit an API. Decide whether the operation
belongs in the generic executor or a distinct existing crop transaction owner
before implementing dependent NUT functionality.

The required semantics are concrete:

1. Bind a boundary candidate to the exact current crop lineage, revision,
   accepted time, crop identity and event phase. Derive weather and crop
   selection from their real owning records. A caller-provided date or crop
   number alone never authorizes publication.
2. Advance the biological revision on publication while preserving physical
   time. Leave water lineage/revision, head, water/heat/solute inventories,
   grid certificate and numerical history unchanged. Existing positive-interval
   transactions and receipts retain their current meaning.
3. Keep harvest end-status inside the crop owner for the required observation
   before resetting its active state. Retain exactly the necessary undelivered
   observation/phase state across restart; do not add a second live crop owner.
4. Debit harvested live biomass/N once. Separate exported harvest from material
   retained as pending residue, including storage organs. Existing pending
   root/leaf/stem material must survive the boundary. The current three-organ
   daily-senescence payload cannot be relabelled complete harvest storage.
   Preserve WOFOST81 N/fixation and derive organ return/export rules from their
   authenticated sources; do not assume all harvested N returns to soil.
5. Publish crop/reset, exported-N accounting, pending residues and the matching
   physical event receipt atomically on local copies. Retire derived calendar/
   window delivery only after that receipt. Invalid, stale, rejected and replayed
   requests must not change any committed owner or consume material twice.
6. Preserve the historical next-morning ordering: acquire authentic morning
   weather, select and initialize the next crop, then run its hydrology. During
   intervening fallow, zero crop extraction while continuing actual water,
   heat and soil-N execution. Adjacent crops require the same ordering without
   inserting a fictitious fallow day or delaying initialization to day end.
7. Keep one accepted physical clock. Persist enough event phase and origin to
   distinguish pre-harvest, observed/unreset, reset/fallow and initialized-next-
   crop states. Check continuous, opaque and fresh-process native continuation,
   including rejected and exactly repeated transitions.

The authenticated original `swap.f90` remains SHA256
`39d1cbd93dbd0f99505e92ef94ac0d23bddb496529c280397d2d7c2b7eb9b58a`.
Its lines480-486 incorporate previous residues before current amendments;
491/494 perform crop growth and soil reactions; 511 performs harvest;
514/522-535 integrate/output before reset. SoilManagement task6 at day end is
output/accounting, not an extra residue incorporation. Storage-organ transfer
must therefore be traced through the actual harvest/reset source, not invented
from that task6 call or the daily senescence producer.

### First implementation and qualification boundary

After the shared API/phase decision, implement one complete harvest-to-next-crop
trajectory with the existing production owners. Start with small real event,
state/nonmutation and whole-N tests, then short actual Richards/crop/soil-N
composition for adjacent crops and intervening fallow at O0/O2. Include calendar
and maturity harvest, end-status before reset, final-day pending material,
rejection/retry/stale/duplicate events and native/opaque restart. Select broader
preservation from the actual shared dependency delta and owning admission
clauses, with a recorded cost decision. No blanket full-FCI or long highest
low-air execution is selected by this source-only readiness update. Reconcile
older highest-stress labels with the current execution protocol; never invent
an inherited PASS.

Current implementation, qualification and admission for this proposed boundary
remain absent. No master capability/count promotion. Pond/source stays open;
aquifer stays rejected. The distinct persistent daily SWRD2 route and surface-
input PR1234 retain their existing owners.

## Unqualified boundary-executor draft

Work branch `work/fkt-boundary-event-20261015`, remote baseline
`451e35ccd1797aa96fb4354dabc465cceff18635`. The selected concept introduces
a separate opt-in `kernel_boundary_executor_t` in the existing F-KT owner module.
It does not alter `kernel_model_t`, `kernel_executor_t`, ordinary interval code,
restart constructors or any existing production caller. Removing the two marked
addition blocks yields the entire original kernel file byte for byte. That is
source preservation only, not ABI, compilation or numerical qualification.

The event request binds lineage, revision, exact accepted time, event identity,
subject and phase. The executor stages against a clone, validates complete
nonnegative bounded conservation channels and requires a model-specific validator
against the actual read-only committed origin. At publication it again checks
origin, producer instance, admission, original parameter/grid identity and the
event's state/balance relationship. Only then does it replace the private physical
state and increment revision. Time, lineage and original certificate are retained.
No interval receipt, numerical substep or reference-floor result is fabricated.

The concrete model must implement admission, staging and validation; no existing
model gains event capability by inheritance. Its validator must prove event
identity/phase, complete conserved quantities, physical-field preservation and
persistent anti-replay semantics. F-KT validates the declared channel arithmetic
but cannot infer a model's omitted physical stock. Up to four explicitly identified
quantities are supported; a numerical mass tolerance is supplied separately from
physical forcing. This draft does not authorize any tolerance for crop/soil N.

Candidates are private temporary objects bound to their originating model
instance, which must remain alive through commit/discard. Failed commits retain
the candidate and committed owner for a controlled retry; discarded or consumed
candidates cannot publish. A sibling candidate from the previous revision becomes
stale. A fresh request with a previously consumed event ID must also be rejected
by the model's committed receipt/phase, not merely by F-KT's revision comparison.
The mandatory validator, not a global event log, owns that last condition.

The synthetic driver uses the real new executor and a deliberately simple
nonphysical owner to test these generic semantics. Its two-unit stock export is
not an authenticated harvest equation, WOFOST81 model, soil-N integration or
Richards simulation. The original FKT22 trajectory driver is selected unchanged
alongside it, at O0/O2, through seven production providers per driver. Production
ABI/old interval behavior still require actual compile/link/native execution.

Status and recovery:
`integration/audits/F_KT_BOUNDARY_EVENT_STATUS_20261015.json`.
At draft publication the compiler was unavailable, so compilation, native tests
and scientific qualification were NOT_RUN. The continuation below supersedes
that environment status. APT recovery failed on environment
permission errors; no privileged retry or alternative permission bypass is
authorized by this draft. No Actions run is selected. The existing runner records
compiler absence as BLOCKED with exit2, never PASS. After provisioning a permitted
toolchain, run the persisted small event/interval tests before modifying any crop,
soil-N, native codec or application interface. Then qualify actual owner state,
restart, stale interval-candidate rejection and shared preservation. This draft
must not merge or promote any capability on source-only checks.


### Executed generic continuation, 15 October 2026

Canonical remains `451e35ccd1797aa96fb4354dabc465cceff18635`; draft PR1247
is not admitted. An existing user-space GNU Fortran 13.3 toolchain was located,
copied into this workstream workspace and smoke-tested by compiling and running
the selected drivers. No privileged package operation or Actions dispatch was
needed. The former missing-compiler blocker is resolved for this execution.

Review tightened the event seam to reject an absent original parameter
certificate. The synthetic model now uses monotonically increasing event IDs
with its committed high-water mark: replaying event 101 after event 102 fails,
including opaque copy and trusted reconstruction. This fixture policy is not a
new generic or production event-history contract.

At local persisted scientific head `32dde7ad`, 169 synthetic assertions pass
per optimization with GNU Fortran 13.3 at O0/O2 and bounds/FP traps. Original
FKT22 assertions also pass unchanged. Outputs are byte-identical between O0
and O2. The seven-provider closure per driver is unchanged. The final measured
compile/link/native sequence takes about 7.39 seconds; native execution totals
about 0.0095 seconds and includes driver assertions. This is one execution, not
a portable performance benchmark. Raw commands, compiler identity, input hashes,
source files, intermediate executions and results are retained in the status
record's evidence capsule.

New contracts tested: missing certificate, revoked admission at commit, stale
interval candidate/checkpoint after event publication, stale event candidate
after positive-interval publication, resumed physical clock, all four independent
conservation channels, nonfinite/overflow-risk balances and revision exhaustion.
Trusted reconstruction uses a synthetic owner snapshot plus its original
certificate. It is not a fresh-process native crop/soil-N codec qualification.

The source projection still reproduces the entire previous kernel outside the
two opt-in additions byte for byte. No production model has opted in. The current
F-CI guard still admits the old exact kernel blob (`da7a00b6`); it has not been
changed or reported PASS for this new shared API. Before promotion, reconcile
that owning admission boundary, the shared-contract decision and the complete
physical harvest/reset/fallow/new-season owner trajectory described above.
No mastercap promotion or physical preservation claim follows from these tests.

### Source-bound WOFOST81 owner harvest candidate

Next bounded implementation is in the existing WOFOST81 crop owner, not a new
physical carrier. The current crop/soil-N joint application owns chemistry as
`crop_soil_state_t` and water as an independent F-KT carrier. It must not publish
a biological event by replacing or revising that water carrier. The generic
boundary tests above do not resolve the eventual cross-owner publication route.

Authenticated `SWAP/wofostnut.f90` (SHA256
`071e65763be9e771b32b417252584d50874715d9ff11d3482c131826cc80bbb2`) reads three independent [0,1] harvest-loss
fractions for leaf/stem/storage (lines94-97). Lines278-311 return all living roots,
the configured fraction of living leaf/stem/storage, plus configured fractions
of retained dead leaf/stem. Residual living N stays for harvest export; biomass
reset follows output in swap.f90. `management_soil.f90` lines583-624 includes a
fourth storage-organ material, with its own application age.

Current WOFOST81 stores living cohorts/organs and a single cumulative N-loss
ledger; it has no retained dead leaf/stem inventory. Its explicitly admitted
daily-senescence profile already transfers all daily death to pending material.
The new owner candidate therefore covers only that explicit profile, with no
retained dead canopy. Never invent dead stocks from the cumulative N-loss ledger
or return previously pending death again. Full historical default dead-canopy
retention remains OPEN. WOFOST81 growth, fixation and nitrogen equations stay
unchanged.

The existing crop owner gains an optional private harvest observation/pending
record. Staging reads the valid emerged owner and literal calendar/maturity
selector, archives the pre-reset crop structure and post-residue-transfer N for
end-status observation, retains four-organ pending DM/N/ages and separates
exported DM/N. The candidate active crop is reset and its live N zeroed; the
existing N-loss ledger accounts for both residue and export, preserving the
original initial/uptake/fixation totals. Archived and active N each validate
against their own transfer boundary. The record is not a second live crop owner.
It exists only on harvested candidates; cloning must retain it. Current daily
and native serialization entrypoints must reject it rather than silently omit
it. No callable staging function supplies weather/calendar provenance or
publication authority from caller IDs/dates alone.

Tests select the actual owner and independent mechanically extracted original
harvest block with dead leaf/stem and death increments fixed explicitly to zero.
Cover distinct fractions, all-root return, storage return, zero/full return,
calendar and maturity boundaries, output-before-reset, unchanged input,
cloning, duplicate refusal, invalid/tiny/overflow-risk material, and per-organ
DM/N plus original WOFOST81 ledger closure at O0/O2. Compile closure is measured
before execution. Expected small-driver cost below30seconds; no broad F-CI or
long stress selected for this unadmitted staging-only step.

Physical water/crop/soil-N publication, incorporation of four-organ pending
material, observation acknowledgement, complete native continuation, fallow and
successor initialization remain admission conditions. This bounded candidate
must not enter canonical or be labelled complete harvest/rotation before those
conditions pass. Pond/source remains open; aquifer remains rejected.


### Harvest owner execution result

At local scientific head `e31c4b84`, the existing WOFOST81 owner stages the
four-organ harvest with private end-status/pending material and a reset active
crop. Its ordinary clone retains that private record. The unchanged active-only
packer refuses harvested owners; the ordinary one-day preparation now explicitly
refuses this unqualified phase. No current physical application opts in.

A separate stateless four-organ material converter uses the same original
management mapping and actual existing B1.11 residue chemistry. It does not
consume the private pending record or supply exactly-once incorporation.
The residue-transfer N inputs plus harvest export equal the original live N.
The existing daily-death pending batch is not accessed or debited by harvest.

3700 assertions pass per O0/O2, together with the unchanged actual repository
one-day integration driver. Changed PP02 providers compile with their existing
-Werror contract. Native outputs are byte-identical O0/O2. Actual closures are
43 production providers for harvest/serializer/residue and 24 for daily
integration, shared within each optimization. Total measured final run is
14.59 seconds; detailed compiler/link/native costs and all attempts are retained
in the existing status record. No physics-only cost or portable speed claim.

Two exploratory historical tests required canonical-shaped substitutes and do
not run with actual production providers: the wrapper expects test_marker;
the older ONE_DAY_CANDIDATE_QUALIFICATION explicitly excludes actual repository
integration and its fixture leaves production common parameters unconfigured.
Their compile/native failures are retained, not relabelled PASS. The unchanged
actual repository integration test is the incumbent preservation selection.
The initial trailing-import compile defect was repaired and its failure retained.

The source-bound harvest staging and conversion claims are now tested. Generic
boundary evidence remains independently verifiable because none of its seven
production providers or driver inputs changed in this harvest step. Shared event
publication, physical Richards/crop/soil-N integration, native persistence,
observation/consumption semantics, historical dead-canopy profiles and complete
rotation remain OPEN. The draft is not qualified for canonical admission.

### Shared-owner resolution for explicit crop/soil-N profile

The actual explicit NUT production composition has an independently owned
`crop_soil_state_t` beside an accepted F-KT water carrier. Its existing joint
application already publishes chemistry by atomic assignment after water
acceptance. There is no reason for a crop-only boundary to replace the F-KT
water state or advance its revision. Resolve this profile in the existing
crop/soil owner: bind immutable harvest identity/end date/mode/fractions/ages
inside the initialized crop configuration, derive the request from the actual
accepted soil clock (after a positive accepted day), and atomically publish the
harvested crop and complete pending/whole-N accounting. The joint boundary
requires the actual existing water/chemical coherence check and read-only water.
No caller-supplied event date, crop number or extra receipt authorizes harvest.
This is the explicit configured profile, not automatic SWAP input/calendar wiring.

Withdraw the unused generic kernel boundary experiment from the candidate source
and restore the exact admitted kernel blob. Its successful synthetic execution
remains historical evidence only. Do not keep a second unneeded event executor
or widen F-CI admission to accommodate it. The production semantic delta now
belongs to the existing crop/N owner and native adapter; existing generic
intervals, kernel revision semantics and hydraulic solvers remain unchanged.

Stage harvest residue plus existing daily pending as one local seven-organ
batch, using original residue chemistry and the existing split parameters.
Publish soil pools, cleared daily pending and an owned consumed phase together
only after whole-N closure. A repeated consume must reject. Keep the immutable
harvest observation while its observation lifecycle is not yet completed.
Historical task ordering remains harvest at accepted day-end, then incorporation
before next day's reactions; same-clock incorporation is a separately explicit
next-morning preparation operation, never an extra reaction or physical timestep.

Native continuation uses separate harvest phase tags; original tags and default
configuration/owner vectors stay byte-identical. Persist the original archived
crop/N, four-organ material, configured policy and consumed flag, plus existing
daily pending. Decode locally with complete domain/balance/configuration/clock
checks before publishing either water or chemical owner. No initialized target
is overwritten. Rejected or corrupted phases cannot consume material.

Qualification: small actual chemical owner with existing eight-pool fixture,
source harvest/residue oracles, pending preservation, per-pool/N balances,
replay/failed-batch rollback and opaque copy. Then reuse the existing real
Richards/native driver closure with a short accepted day, harvest, pending native
write/read in a fresh process, one consumption, and duplicate refusal; compare
continuous/opaque/native endpoints and preserve the original day route. Measure
and persist source/commands/raw outcomes. Broad admission is selected only after
these changed owner/native surfaces and actual physical results are reconciled.
Fallow, successor initialization, output acknowledgement and retained historical
dead-canopy profiles remain explicit unfinished scope.


Native phase review found a real fail-open path: flipping consumed1 to0 and
recomputing the CRC allowed a previously incorporated harvest to masquerade as
pending. The independent compiled O0 decoder negative failed. That candidate is
FAILED, even though its ordinary O0 trajectories passed. The broad controller
also ended with a PermissionError launching its last O2 fresh-process executable;
that run has no terminal scientific PASS and is retained as incomplete.

Bind two compact continuation totals inside the existing optional harvest
record at atomic crop/soil publication: complete whole N and organic matter,
both kg/m2 after harvest export. At this same-clock boundary and incorporation,
there are no reactions or extra external fluxes. Both totals must match the
actual soil/live/pending phase on readiness/restart. This detects forged phase,
missing/doubled pending and N-free organic-matter reintroduction; CRC alone does
not establish phase semantics. Standalone crop-owner candidates retain an
explicit unbound sentinel and cannot become coupled authority until bound.
The two scalars are continuation state, not duplicate physical inventories.
Probe actual seven-organ incorporation on a copy before publishing harvest, so
an unincorporable batch rejects the entire event without losing daily pending.
A new O0/O2 execution with corrected phase negatives is required.


The native adapter also serves the previously admitted accepted-thermal route.
Select fresh original thermal manual/calendar native assertions and byte checks
against its immutable admitted capsule after the corrected physical build.
Reuse only that same live source/flags/compiler-bound provider set; compile
missing calendar providers and the exact archived original driver separately,
execute every profile freshly at O0/O2 and compare original native files.
Expected extra native cost2minutes, extra provider/driver compilation UNKNOWN.
This is existing heat-route preservation, not qualification of thermal harvest.


### Corrected physical/native closeout

Current production source is pinned by local commit `31334d1b`. Later controller,
documentation and evidence commits have identical production bytes. The actual
existing crop/soil owner is now the event publisher; the exact admitted kernel
is restored. No F-KT interface successor or changed water revision is needed.

Small O0/O2 execution: 3700 harvest-owner assertions, 40 chemical assertions and
the unchanged real daily integration. It includes configured event derivation,
positive-day prerequisite, retained daily pending, single seven-organ consumption,
complete continuation codec, forged-phase refusal and late chemical rollback.
Measured final small execution is recorded in the existing status/capsule.

Corrected actual Richards/native execution is PASS at O0/O2. Continuous, opaque
and fresh-process consumed endpoints are byte-identical; the complete water
record is unchanged across incorporation. All original material, prescribed-
environment and senescence drivers/negative controls execute, and the original
material/environment native endpoints match immutable authority. Six additional
native negatives per optimization alter phase in both directions or either
continuation total while recomputing CRC. All reject atomically. This is the
existing short four-node 30 cm default-MVG fixed-forcing/rooted NUT profile,
not all SWAP crop/root forcing routes or a two-season rotation.

A Python-only controller failure occurred after all corrected O0 native/assertion
checks and before any O2 compile. The corrected controller differs only by
renaming its temporary bytearray. `COMPLETED_O0_RECOVERY.json` binds all source,
input, artifacts and raw outputs; O2 executes freshly. Recovered O0 execution
is counted once. No repeated broad O0 numerical run or invented PASS was used.
Compiler/link/native timing sums are retained, with controller recovery overhead
and physics-only cost UNKNOWN where not instrumented.

Fresh original accepted-thermal manual/calendar native assertions also PASS on
the same live verified provider build at O0/O2, with the exact archived original
driver, separately compiled missing calendar providers and no inherited native
PASS. All original thermal restart and endpoint bytes match immutable evidence.
This preserves the existing thermal route; thermal HARVEST composition is not
qualified. No full F-CI, highest low-air stress or Actions dispatch was selected.

Remaining admission/programme boundaries: end-status observation acknowledgement
and compact retirement, actual fallow and successor initialization, complete
rotation, automatic legacy crop/calendar input activation and retained historical
dead-canopy profiles. The common native/owner preservation evidence is bounded
as above; reconcile the owning F-CI admission contracts before any promotion.
Keep PR1247 draft. No mastercap/count promotion. Pond/source stays open;
aquifer stays rejected.

### Observation retirement and explicit successor contract (implementation phase)

Continue in the existing crop/soil owner, not the kernel. A detached observation
receipt captures the archived final crop/N and exact event continuation. The
consumer explicitly acknowledges that receipt. Acknowledgement is atomic and
requires completed harvest incorporation, no daily pending, and exact identity,
clock, policy, archive and inventory binding. Observation may precede
incorporation; only the incorporated flag is normalized for receipt comparison.
A receipt is an application acknowledgement, not proof that external I/O ran.
Absent, stale and duplicate acknowledgements reject without state changes.

After acknowledgement, release the final biomass/cohorts, evolution history,
policy copy and organ material arrays. Persist only event identity, current
clock, the two inventory bindings and the existing closed crop N ledger. The
compact owner remains a harvested/retired phase, not a default active owner.
Use a distinct owner vector discriminator (-81002), bounded exact length and
roundtrip validation inside existing harvest native tags. Original active and
unacknowledged harvest vectors/tags stay byte-identical. Decoder publication
still requires actual coupled N/OM, configuration and water coherence.

An explicit fallow interval requires this retired phase and zero potential and
actual root extraction. Execute the existing accepted Richards trial and real
reactive N day with no crop demand, atomically publish both, and update compact
clock/N/OM bindings only after the real reactions and balance checks. This is
not a synthetic timestep or a crop day with uptake disabled after calculation.
Retain the completed crop ledger unchanged through fallow.

Explicit successor initialization accepts an independently initialized WOFOST81
owner and configuration at the actual accepted clock. Require a strictly newer
crop identity, a future/end-of-current-day harvest bound, no accumulated uptake,
fixation or loss, and a valid initial N balance. Record seed/initial biomass N
as external input; never silently remove it from soil. Keep all soil pools,
water clock/revision and numerical history unchanged. Calendar/weather parsing,
automatic emergence and retained historical dead canopy remain separate scope.
The explicit transition is allowed directly after retirement or after fallow.

Affected invariants: 3,4,7,9,13,21,27,29. Qualification selects the small real
owner/chemical closure first, then a short physical harvest -> observation ->
retirement -> fallow -> successor -> accepted crop-day continuation with opaque
and fresh-process native equality and malformed compact controls at O0/O2.
Preserve affected original native material/environment/thermal endpoints using
same-session provider reuse and fresh assertions. No full F-CI or long low-air
run is selected merely for a shared owner change. Expected physical/preservation
cost about ten minutes; exact compilation/link/native costs will be retained.

### Explicit retirement/fallow/successor execution result

The successor production source is local `69abee65` (source tree
`aeb3fbf37edd7d7f9eb0348b2b6e858427d8a045`). Later changes concern verification,
documentation and evidence. The small real closure passes at O0/O2: 3700 owner
assertions, 74 chemical assertions and unchanged actual PP02 daily integration.
The chemical tests include missing/premature/duplicate observation refusal,
archive release with a detached consumer copy, exact nine-scalar codec, invalid
compact state refusal, zero-extraction reactive fallow, unchanged completed N
ledger and explicit external initial N for a successor.

All ten selected physical drivers and their original assertions execute freshly
at O0/O2. The added chain uses three actual accepted positive water/chemical
days: original crop0->1, retired zero-extraction fallow1->2, independently
initialized rooted successor2->3. Harvest, incorporation, acknowledgement and
successor initialization do not fabricate a water clock, revision or lineage.
Continuous/opaque/native-pending continuation and fresh-process continuation
from retired, fallow and successor states produce identical endpoint bytes.
Twelve compact marker/clock/identity/N/OM/ledger negatives per optimization
recompute CRC and reject atomically, alongside the previous six harvest-phase
controls. This is a short explicit transition proof, not two full growing
seasons, automatic calendar activation or thermal-harvest qualification.

Measured physical work: 176.35s provider compilation, 59.38s driver compilation,
2.91s linking, 309.64s native execution (548.28s sum). Small work adds 25.33s.
The first strict owner compile and one physical provider compile failed; raw
outputs and original source history remain evidence. The physical failure was
a scalar IF on the root-sink vector, corrected to a complete zero-vector test.
Before native execution, 262 successful compiler events were bound to exact
commands, source pin/current bytes and live artifacts and reused once. No native
result was inherited. The failed compile remains separate, never counted PASS.
The original compiler binary hash was not separately recorded; compiler command
and current identification are retained. Controller/recovery overhead and isolated
physics-only timing are UNKNOWN where not instrumented.

The current owning source-only admission route has been executed and rejects
with `ValueError: foreign SWRD3 delta`. It delegates through the admitted thermal
owner to the source-exact SWRD3 successor. Numerical PASS does not supersede
that guard. Keep PR1247 draft until its default-path compatibility and affected
owner controls are explicitly reconciled. Do not introduce a blanket source/hash
exception, claim a full F-CI PASS or promote mastercap counts. Automatic legacy
input/calendar/output activation, retained historical dead canopy and complete
seasonal rotation remain separate programme scope.

A further explicit CRC-valid NaN control exposed a decoder defect at both O0/O2:
the discriminator/combined finite-and-bound predicate could compare NaN before
rejecting it and raise SIGFPE. That candidate is not final qualification. Hoist
the whole-vector finite check ahead of every discriminator/comparison and remove
the two redundant inner finite checks. Keep FP traps and all assertions enabled.
Select exact source transformation proof, unchanged module-interface bytes,
source/command/artifact-bound live provider reuse, fresh small drivers, all actual
harvest/rotation native assertions, fresh original thermal manual/calendar runs,
original endpoint byte checks and non-finite fields throughout both owner codecs.
Do not repeat unaffected material/senescence physics or relabel their old source
as the repaired postimage. Record both failed NaN controls and repair costs.

Final finite repair PASS at O0/O2, source commit `a0f7c393f5e2520d12a229e01a26515cc9bdd6b9`. Both owner codecs reject 51 CRC-valid quiet-NaN/+Inf/-Inf field controls per optimization without SIGFPE. All actual harvest/rotation native assertions, original thermal manual/calendar profiles and small real drivers execute freshly after relinking the recompiled owner; their endpoint/output bytes equal the pre-repair evidence. The emitted module interface equals the original bytes. Exact transformation proof bounds inheritance of the unaffected earlier material/environment/senescence physics; this is not a new full-suite execution.

Repair costs: changed_provider_compile 13.59s, link 2.04s, native 220.35s. Original thermal preservation also completed before repair: native 118.81s, driver_compile 14.87s, extra_provider_compile 2.44s, link 0.30s. Both executions and the failed NaN controls are retained separately; costs are not merged into a fictitious single run. No tolerances, assertions, FP traps or admission guards were weakened. The owning source-only guard still rejects the repaired source; canonical admission remains open.
