# MC-SOL01 final closure

Status: bounded canonical implementation is admitted; the four full historical capability envelopes below remain explicitly parked. This is not a claim of complete SWAP 4.3.1/default equivalence.

Review baseline: `integration/f-ci-canonical` at `e122ff8f682584620717e97ab24ce07933dd0923`; production source tree `282e4504c8d1d31e9cdfa37041b6b06a48a90588`. Review date: 2026-10-19. The final admission receipt is in the existing `integration/audits/MC_NUT_SOL_TRAJECTORY3_STATUS.json` record. The existing master is on `work/swap431-master-coverage-20261006`, PR #1072. It is not a canonical full-coverage admission.

## Source authority and capability balance

The immutable B1.11 archive is `integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64`. Its `SWAP/solute.f90` SHA256 is `2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2`. Literal historical transport and age loops remain the source oracle. Two accepted differences must not be called historical identity: the mass-consistent nonlinear inverse under PR #1230, and positive runon/runoff pond chemistry under PR #1304.

The eight rows below are the existing master entries for subsystem `solute`, including the historically impossible macropore combination. No second census is created. ADMITTED means the bounded registered claim, not unrestricted historical selector compatibility. None of these eight rows is QUALIFICATION_ONLY.

| Existing capability | Master disposition | Actual production and admission | Final disposition of remaining envelope |
| --- | --- | --- | --- |
| SW431-MACRO-SOLUTE | NOT_APPLICABLE | Historical input reader rejects SWSOLU > 0 with macropores. | Excluded historical combination; SWAP5 prototypes do not change that finding. |
| SW431-SALT-TRANSPORT | ADMITTED | Mobile dissolved advection/diffusion/dispersion, signed faces, root TSCF, drain and bottom receipts. PPA-WU05E admission; reactive matrix successor PR #1228. | Closed within registered matrix domain. |
| SW431-SALT-SORPTION | ACTIVE_MIGRATION, explicitly parked remainder | Real matrix application, linear and nonlinear Freundlich exponent 0.5..2, PR #1228/#1230. | Wider reader exponent 0..10, nonlinear pond composition, dynamic accepted thermal coupling and complete default-file activation are not admitted. Production constructor rejects 0.49999 and 2.00001 in the real driver. Preserve the existing bounded route. |
| SW431-SALT-DECAY | ACTIVE_MIGRATION, explicitly parked remainder | Source-order temperature/moisture/depth decay including nonlinear inventory, PR #1228/#1230. `temperature_active=false` retains historical zero temperature factor. | Dynamic accepted temperature ownership across water/solute restart and full historical/default activation require a separate composition contract and physical qualification. No aquifer dependency. |
| SW431-SALT-AQUIFER | REJECTED | No admitted evolving aquifer owner. Exact SWBR source has the documented numnod+1 bounds defect and lacks an aquifer bulk-density input defining rho*KFSAT+POROS. | Deliberately excluded; no invented bottom-soil density or reservoir law. |
| SW431-SALT-POND | ACTIVE_MIGRATION, explicitly parked remainder | One matrix pond-mass owner, rain/irrigation/deposition, evolving pond, runon/runoff, infiltration, non-exporting evaporation, atomic retry and V2 restart. PR #1234/#1256/#1257/#1258/#1304. | Nonlinear pond sorption is rejected by the actual route's `frexp /= 1` guard. Snowmelt/exfiltration and complete default/bootstrap/multicolumn activation remain outside the admitted application. Simultaneous age/reactive/N companions are not inferred. |
| SW431-AGE-TRACER | ACTIVE_MIGRATION, explicitly parked remainder | Soil age and positive pond age on actual accepted Reference traces, aged external input, exactly-once handoff, joint transaction and fresh-process restart. PR #1233/#1309, supplemental #1315 and CI repair #1317/#1321. | Complete evaporative drying is scientifically blocked under the retained no-evaporative-age-export convention. Snow/exfiltration age, general outputs/default/multicolumn and simultaneous companions are not admitted. |
| SW431-SALT-BOTTOM-C | SUPERSEDED | Typed immutable interval bottom concentration supplies shared-drain, independent constant or externally resolved time-varying concentration. | Closed by admitted external forcing replacement; no dynamic SWBR reservoir implied. |

ACTIVE_MIGRATION remains the truthful master classification of the four *full* historical envelopes. Their former generic missing-implementation descriptions are replaced by exact bounded admissions and parked remainders. This closure does not silently change the capability denominator or promote an incomplete historical claim. There is no remaining unassigned implementation step in the bounded Reference closure.

## Physical and state contracts

Only converged, hydraulically accepted substeps may advance chemical/age state. Net qtop cannot reconstruct simultaneous gross rainfall, irrigation, evaporation and runoff. Reference-private accepted receipts carry gross-source provenance; shared solver and optional RossFast contracts are preserved.

The water owner owns pond depth. Matrix `pond_mass` is the sole committed surface chemical store. Surface scratch receipts are not a second persistent pool. For infiltrating water, the admitted B1.11 cutoff is qtop < -1e-6 cm/day. The SWAP5 positive-runoff extension mixes available mass against ending pond volume plus infiltration and runoff volumes, then books exactly one soil transfer and one runoff export. Evaporation removes water but no solute. Noninfiltrating runoff uses ending pond plus runoff volume. Dry deposition and retained solute survive the admitted dry/rewet route.

For a whole water/solute interval, internal faces and pond-to-soil transfer cancel. Change in soil plus pond mass equals external rain/irrigation/runon/deposition and bottom/drain inflow minus runoff, root, drain, bottom and transformation sinks under the admitted signs. Water storage independently closes against all accepted water receipts. Rejected numerical or chemical trials, including rejected accepted-prefix carriers, publish neither water nor constituent state. Smaller retry starts from the same committed owners.

Surface age is an amount in cm day; mean age is amount divided by water depth. Age production is the accepted timestep times mean starting/ending pond volume. Explicit external water age enters with its actual volume. The exported infiltration-age amount is passed once to the native soil-age top boundary. The joint pond/soil balance cancels that internal transfer; it must not be added through both a source receipt and the boundary again.

The retained surface-age convention exports no age through evaporation. Therefore positive age stock cannot survive at zero water with a finite mean age. Complete evaporative dry-down is rejected, not clipped or converted into an invented dry store. See `docs/science/MC_SOL01_SURFACE_AGE02_QUALIFICATION.md` and its exact dry-limit executable. This is a limitation of the accepted convention, not a RossFast obstacle.

## Qualification and restart evidence

PR #1309 qualifies all twelve requested positive-pond criteria: positive pond/runon/runoff/infiltration, stored and external nonzero age, accepted ageing, exact soil handoff, closed combined balance, rejected trial with no committed mutation, smaller retry, multiple accepted substeps and independent-process continuation. Its actual two 86.4-second windows report combined age residual about -3.25605e-15 cm day. The O0/O2 fresh and uninterrupted endpoint SHA256 is `7afefa2a28a99e5b7ca05bf92e5402005329ce419b41ce8e07548aedc0955831`.

The supplemental two-day four-pulse study in PR #1315 includes 259424 accepted steps on its finest case, 12 fresh-process continuations across meshes/optimizations and observed decreasing endpoint changes when the *actual* accepted maximum timestep halves. Finest combined age residual is about 3.98792e-13 cm day. These are controlled four-node-column results, not field or seasonal validation or a formal order proof.

Restart contracts are deliberately distinct. Matrix chemical restart V2 preserves the sole pond mass and configuration identity while V1 remains compatible. `S5AJ0001` continues to encode the water/soil-age payload. Surface-age `S5PA0001` and that payload are bound together by one CRC-protected `S5AT0001` snapshot. A temporary file is flushed/fsynced, one POSIX rename publishes the complete generation, then directory durability is synced. The three logical owners are decoded and validated before commit. Independent loose files must not be recombined as if they were one generation. Existing SIGKILL before/after rename and corrupt/truncated/overlong/identity/overwrite controls demonstrate complete-generation recovery. Scope is same-platform POSIX, serialized ownership; no portable binary ABI or concurrent writers are admitted.

| Existing admission evidence | Result and exact scope |
| --- | --- |
| PR #1304 final head 0cc3fe1f; runs 39115709736, 39115709442, 39115709818 | SUCCESS: F-CI96, preserved old F-ROSS12 wiring, actual O0/O2 positive-gross Reference chemistry/rollback/V2 continuation. |
| PR #1309, run 39153649970 | All three jobs SUCCESS; source-bound positive-pond/soil age, snapshot and incumbent preservation. |
| Surface-age full moving local execution 27d0cfa2 | PASS, 459.151946 s, resume OFF, 6912 inputs unchanged; separately qualified atmospheric-N coexistence. |
| CI repair full moving execution 9de996d4 | PASS, 781.268452 s, resume OFF; exact later parser/guard coexistence retained. |
| PR #1321 actual merge 6153b540; runs 39168835955, 39168835957, 39168836087, 39168835956, 39168835969 | All five automatic workflows SUCCESS. Canonical selection/feedback success does not mean skipped broad jobs reran. |

No new RossFast development, aquifer implementation, highest low-air stress or unrelated solver qualification is selected. Full F-CI is inherited only through the current source/evidence validators and unchanged relevant scientific dependency surfaces. This closure changes documentation/registration, not production science or tests.

## Current-session execution

All selected current physical runs completed locally with GNU Fortran 13.3.0. Runtime bounds checks and invalid/zero/overflow traps remained enabled. The concurrent NUT closure at `db85508c431b5c926bf25a4201d0d25c12c72d92` changes only documentation/evidence/status; its source tree is exactly the reviewed `282e4504c8d1d31e9cdfa37041b6b06a48a90588`. Every one of the 276 age and 273 matrix recorded execution inputs still matches its SHA256 after reconciliation.

| Current local gate | Terminal result |
| --- | --- |
| `tests/nut-sol/run_age.py` | O0/O2 PASS: 150-step literal process, real signed-flow soil age, positive pond/aged external water, numerical and chemical rejection, smaller retry, exact fresh-process endpoint and snapshot corruptions. Compile/link/native total 259.444210 s. |
| `tests/publication/run_pub_p1e02_postsolver_rollback.sh` | O0/O2 PASS: actual Reference pond runon/runoff, evaporation/source mixing balance/restart/rejection, accepted-state identity and post-solver rollback. Optimization output SHA256 `ba5d3b995d855c271bc6b8d6f7b5b2f142870fcecc17961414be6cb5d3730626`. |
| `MATRIX_NONLINEAR=1 tests/nut-sol/run_matrix_route.py` | O0/O2 PASS: 7218 independent inverse cases per optimization; actual accepted-water transport/decay and joint continuation for exponents 1, 0.5, 0.8, 1.0005, 1.5 and 2. Compile 241.967850 s, link 1.079937 s, native 86.163515 s. |
| `tests/nut-sol/run_surface_age_budget.sh` | O0/O2 PASS: analytic first-order control, budget, persistent owner, disk/fresh process, exactly-once soil handoff and native soil-age top boundary. |
| Existing archived rename interposer, current freshly compiled positive-pond executable | PASS: fresh SIGKILL immediately before/after rename, old-or-complete snapshot readable and exact fresh-process endpoint. Only scratch paths in the archived experiment controller are relocated. |
| Current `verify_surface_age_successor.py` | Source, executed evidence, inherited CI science and incumbent age PASS after actual NUT metadata coexistence. Nine deliberate current-validator evidence corruptions reject at the relevant assertions. |
| `surface_age_longrun/verify.py --self-test` | PASS: original source-bound two-day evidence plus all eight negative controls; no duplicate long physical run. |
| Documentation | Source checks PASS and strict `python -m mkdocs` build PASS (22.45 s) after concurrent documentation was retained. |
| Existing master ledger | Scoped four-row/queue/ancestry/locator proof PASS, all other 239 rows and all 243 dispositions exact. Master branch receipt `abb0045e5a8c7e72ca99f813d6e1e0e175d33e6f`; no whole-master admission. |

Reproduction uses the existing commands above with `FC` pointing at GNU Fortran and result directories in writable scratch. The final matrix compiler command adds **only** `-Wno-error=compare-reals`: exact physical zero/identity comparisons in the later admitted restart adapter remain unchanged; the historical harness's `-Werror` otherwise stops compilation on that diagnostic. All runtime checks, FPE traps and assertions remain active. The initial compiler-policy failure and its raw commands are retained and never count as PASS.

The initial direct `check_age_evidence_controls.py` invocation fails its positive historical capsule comparison at `tests/nut-sol/run_age.py`, which was intentionally superseded by admitted surface age. Its 28 nominal negatives are not credited as current evidence. The current successor positive validation, nine discriminating corruption controls and fresh native runs above are the current authority; the old failure remains in the capsule. No old assertion or eligibility pin was weakened.

Full master integrity is not claimed: both baseline and final structural inspection identify the same nine unrelated NUT ACTIVE rows without the `bounded_receipt` shape required by the global checker; the final full checker stops with `active route lacks bounded authority`. The four SOL rows satisfy that original checker contract and have fresh scoped PASS. The master denominator remains incomplete. That global NUT bookkeeping issue neither proves missing SOL physics nor authorizes changing other capability rows.

The immutable current-session capsule is `integration/audits/evidence/MC_SOL01_FINAL_CLOSURE_20261019.tar.xz.b64`. It includes raw successful and failed commands/results, exact source-input reconciliation, native restart endpoints, the crash controller/interposer, existing-validator corruption tests, documentation logs and the scoped master validation. The small local checkpoint Git bundle preserves the matrix run's local metadata-only baseline `69b6b8ea`; the source was already canonical and its remote closure checkpoint is `7148198c`. No new manually dispatched Actions or whole moving-FCI run was needed for metadata-only closure.


## Parked work and re-entry criteria

1. **SORPTION remainder:** preserve exponent 0.5..2. Widening to the full legacy reader domain requires an explicit numerical envelope, independent inverse, actual accepted-water transport and restart/rollback evidence. Nonlinear pond composition also requires qualifying the real pond route, which currently rejects any exponent other than one.
2. **DECAY/thermal remainder:** replace no immutable parameters implicitly. A future live-temperature adapter must bind actual accepted temperature, identity, rollback and independent-process restart to the chemical owner; validate the historical SWHEA=0 zero-factor branch separately from dynamic thermal composition.
3. **POND/application remainder:** keep unsupported snowmelt/exfiltration fail-closed. Any new source needs an accepted gross water receipt and constituent boundary contract; default-file/bootstrap/multicolumn activation needs real production reachability and end-to-end balances. Existing runon/runoff is already closed and must not be reopened.
4. **AGE remainder:** changing evaporation-age export or allowing complete drying requires a scientific decision about whether the state represents physical water age or a nonvolatile tracer moment, followed by an independently derived balance and dry-limit/restart qualification. Default/output/multicolumn or simultaneous companions need separately selected application evidence. Strictly positive pond and existing zero-pond routes are already closed.

These remainders are parked separately in the existing master/workunit records. None authorizes a new research line in this closure, and none is converted to ADMITTED by documentation. Aquifer stays rejected; RossFast stays optional only on its previously admitted domain.

## Actual canonical closure receipt

PR #1324 is merged at `860ff5fbe2b69d33caef7c471e8034e504d14d34`, qualified head `fa7375dee719c7d568f1bb47d0e3ee23fc818547`. Postmerge verification passes the actual current successor qualification, documentation source checks, complete capsule manifest and all 549 recorded age/matrix scientific input bindings. Production source tree remains `282e4504c8d1d31e9cdfa37041b6b06a48a90588`. No postmerge duplicate physical run is claimed.

PR #1288 is closed **unmerged** and supplies no production admission; the accepted private Reference surface formulation is PR #1304. PR #1308 is its merged documentation closeout. PR #1309 and the later #1315/#1317/#1321 admissions remain merged and source-bound. PR #1324 closes this bounded review; it does not admit the four parked historical envelopes. Master PR #1072 stays draft because the overall denominator and unrelated NUT receipt registrations are incomplete; its scoped SOL updates are `abb0045e` and `9215033e`.

Automatic Actions on the final PR #1324 head were still **queued**, without a PASS, at the closure observation. Relevant run IDs include documentation `39303672373`; the ten other queued automatic workflows cover unchanged interception/root/performance/groundwater routes. These were not manually dispatched and are not substitutes for the completed local scientific qualification. No global current-head hosted-green result is claimed.

## Terminal hosted follow-up, 2026-10-19

The earlier queued observation is superseded by terminal results: all 14 observed workflows completed, 11 SUCCESS and 3 FAILURE. All three actual canonical `565bc460` preservation workflows PASS: **F-CI51P WOF43A `39303981790`**, **F-CI58P F-SI35 `39303981822`**, and **F-GC fixed interface `39303981779`**. The F-GC log includes original coupled O0/O2 and independent process-split restart assertions ending in `F_GC_CLOSEOUT_FIXED_INTERFACE_GATE_PASS`. This is current canonical hosted preservation in addition to the local SOL qualification; it does not promote the four parked historical envelopes.

The three failed PR-head workflows are poison workspace `39303672136`, TIMEINT16 `39303672358` and F-CI110 `39303672209`. Six jobs stop during compilation because the explicit build recipe does not compile `mod_drainage_dramet3_response` before its consumer; two research jobs reject an obsolete declaration marker before candidate execution. The TIMEINT16 inverse/provider jobs and five F-CI110 subjobs pass. All 10 specific relevant production/build/instrumentation files are byte-identical to preclosure `e122ff8f`. No native numerical SOL regression follows from those pre-native failures, and **global CI is not green**. Their owners must repair/qualify their build or research-instrumentation routes separately; this closure does not silently widen performance, solver or RossFast scope.

Raw failed and successful job logs, all 14 terminal run identities and unchanged-input proof are sealed in `integration/audits/evidence/MC_SOL01_HOSTED_FOLLOWUP_20261019.tar.xz.b64`; the exact decoded hash and owner routing are in the existing trajectory3 final-closure record. No new manual Actions or repeated physical calculation was started for this follow-up.

## Native CI repair after terminal follow-up

The eight failed build/instrumentation routes above have now been executed locally. The repair starts at canonical `6bac7b1508e4b7c33bf887f61be4499268bac4da`; persisted source checkpoints are `1c5165783bc11177c05122b446f7f2439e4258d4` and `f90a35cae4bb1788e5f38fce699b96196807b973`. No production, reference, physical driver, tolerance or numerical script flag changes. Six build recipes use the existing complete dependency-order helper, preserving explicit providers. The old F-GC49D template also consumes the full symbol stream, matching the accepted live runner: the former `nm | grep -q` actually returned 141/0 for a defined symbol. Research instrumentation preserves every original residual term and rejects ambiguous insertion locations.

| Original route | Native result | Total successful seconds |
| --- | --- | ---: |
| `tests/fpe/run_fpe_zero_waste01_poison_workspace.sh` | PASS | 141.624 |
| `tests/fkt/run_fkt22_fmr_runtime_gate.sh` | PASS | 123.276 |
| `tests/fahl/run_fahl49_production_matrix.sh` | PASS | 19.089 |
| `tests/fahl/run_fahl49_application_optin.sh` | PASS | 146.267 |
| `tests/fahl/run_fahl49_application_scale.sh` | PASS | 145.222 |
| `tests/fahl/run_fahl49_failclosed.sh` | PASS | 137.448 |
| `tests/fpe/run_fpe_timeint16.sh` | PASS | 21.560 |
| `tests/fpe/run_fpe_timeint16b.sh` | PASS | 20.450 |

Poison, FKT22 and application opt-in retain their original O0/O2 output identity checks; the matrix retains its original O3 12-case gate, scale/fail-closed and research routes their original O2 selection. Both TIMEINT16 experiments complete, but their scientific classifications remain **CLOSED_TG_SECOND_ORDER_NOT_REPRODUCED** and **TG_ORDER_REDUCTION_PERSISTS_AFTER_STARTUP**. Harness PASS does not admit Thomas-Gladwell or second-order accuracy.

The exact source/evidence guard enforces the recipe transformations, eight original final assertions, selected successful compiler attempts, input hashes and materialization preservation. Four materializer negatives and nine new evidence negatives pass. Failed local sparse-checkout/linker attempts are retained; the final shared-library test uses a scratch runtime search prefix because the temporary compiler bundle lacks its shared Fortran runtime. The original repository flags remain unchanged. Native/validation time is not falsely separated from compound-runner overhead.

All raw results, failed attempts, compiler arguments/costs, environment repair, symbol controls, test input hashes and a complete manifest are in `integration/audits/evidence/MC_SOL01_CLOSURE_CI_REPAIR_20261019.tar.xz.b64`. Exact digest/costs and bounded qualification are in the existing AGE03-CI status; trajectory3 references that authority. Relevant previous integrated preservation remains bound to unchanged production/physical inputs. Full moving and highest low-air were not selected by this infrastructure repair. The four parked historical envelopes and all physical limitations above remain unchanged.

## Final preservation completion and exact external exceptions

[PR #1327](https://github.com/abhedwig-cell/SWAP5/pull/1327) owns the final repair and terminal hosted admission receipt. On its first source head `b8ce7d51`, all three originally failed workflows now **PASS**: poison `39322825535`, TIMEINT16 `39322825435` and complete eleven-job F-CI110 `39322825562`; standalone F-GC49D `39322825448` also PASS. All25 automatic observations are terminal:17success/8failure, individually recorded with raw failed logs in the supplemental capsule below. This is not global CI-green.

Two additional missing-dependency recipes were then addressed. F-KT22 production compilation passes original O0/O2 in126.586s. Paired runtime resolves historical/current providers separately, retaining all original flags,5000calls and ten pairs in **each** mode. Both complete original assertion bodies pass using one immutable shared build in114.818s, including exact checksums and iteration/constitutive counts. Six historical sources remain exact `82d9938976fd92ff3230e7739539e467c3243225` bytes and are bound to actual compiler digests. No new optimization, performance envelope or speed guarantee is admitted. Eight additional evidence-negative controls pass.

The new F-GC run `39322825439` stopped before MODFLOW execution with HTTP403 GitHub API rate limiting after its native application checks passed. The workflow now exposes its existing read-only `github.token` as `GITHUB_TOKEN`, as requested by the unchanged downloader. Pinned MODFLOW/dependency versions and all coupled O0/O2/restart assertions are unchanged. The exact two-line environment addition is enforced by the source guard. Terminal repaired hosted PASS is required before canonical admission; PR1327 records that actual result. No download failure is counted as physical PASS.

The remaining exceptions are concrete and outside the admitted MC-SOL01 domain:

| Existing route | Exact observation / disposition |
| --- | --- |
| Frozen F-CI73 `39322825512`, F-CI73P `39322825726`, F-VQ87 `39322825369` | Their original historical allowlists reject `.github/PULL_REQUEST_TEMPLATE.md`, already present unchanged before this repair. Existing current F-CI73 science and its immutable oracle remain validated separately. Do not refresh broad historical allowlists as a SOL admission. |
| F-CI75/F-KT21 `39322825397` | Pins direction contract blob `b5a0276d`; actual blob was already `5418b6a1` at pre-repair canonical6bac7b15. Owner must reconcile its historical admission route with current qualified successors. |
| ELASTIC65 `39322825469` | Native O0/O2 checks pass, then its research-scope check requires exactly one changed production file. This build-only PR changes none, yielding `SOURCE_SCOPE_FAIL=[]`. No new solver/optimization research is selected. |
| EB-I25 within F-KT22 `39322825494` | The original recipe omits DRAMET3. Scratch dependency completion reaches a reproducible O0 native failure: `EB_I25_TEST_FAIL external full-half outflow fixture rejected before commit`. The fixture expects rejection while current execution accepts. This requires separate energy-owner contract adjudication, not relaxed assertions or an invented SOL blocker. Execution92ece71b and the full failed log/source bindings are retained. Final EB-I25 production/test recipe remains unchanged; no EB-I25 native PASS or promotion is claimed. |

The supplemental capsule `integration/audits/evidence/MC_SOL01_CLOSURE_PRESERVATION_20261019.tar.xz.b64` contains all original compile/paired output, exact historical providers, compiler events/costs, the failed energy diagnostic, the shared-build script proof, eight negative controls and all prior hosted failures. Its exact digest is in the existing AGE03-CI and trajectory3 records. Actual canonical containment and repaired terminal hosted outcomes are the associated PR/Git admission receipt. These exceptions neither reopen nor extend the four explicitly parked historical SOL envelopes above.
