# A28 Work production configuration decision

Date: 2026-10-04. Decision: **COUPLED_RFM_BLOCKED**. This is a completed bounded falsification of the available field-depth production candidate, not canonical admission.

## Authority and scope

Baseline is `a96886f6a38a1805056fabe9d61bc59a725f83f4`. Work is persisted separately on `work/a28-rfm-production-work`, avoiding duplicate push-triggered diagnostic CI on the original branch. Canonical observed at `fae6d8d3d1687bfb220851f43603ab63d4989a29` has relevant RFM/backend differences; these results do not establish current-canonical preservation or production admission. Production source files are unchanged. Repairs are explicit generated build-local research postimages.

Controlling preregistrations are [original practical contract](PPA_WU05A28_COUPLED_PRACTICAL_PREREGISTRATION.md) and [Work continuation](PPA_WU05A28_WORK_PRODUCTION_PREREGISTRATION.md). Original strict failures and prior component status remain unchanged.

## Solver frontier: identify the confound before choosing a default

The original nominal solver-only probe changes two parameter fields but not only two effective criteria. `mod_fmr_serialized_reference_backend` also passes compartment convergence tolerance into RFM preparation. This affects surface admissibility, storage truncation, endpoint geometry and physical accounting. At 1e-8 the original test completes its first trial with aggregate mass residual -2.25966e-12 cm and fails the unchanged 1e-12 gate. At 1e-6 and 1e-5 it stalls after 681 accepted internal substeps at t=.00367483310269 day, with respectively 6944 and 7776 mass rejections. These remain negative results, but cannot establish that loose Richards convergence itself is responsible.

A generated backend freezes the RFM tolerance at its original 1e-12 cm and repeats the four exact fixed-64 levels. This makes the causal separation explicit without changing production source. Head absolute/relative and ponding convergence criteria remain 1e-12; transaction and post-trial mass remain 1e-12; temporal error remains 1e-5 cm; coupling flux convergence remains 1e-15 m/s.

| Internal compartment/total setting | Predictor completion | Nonlinear iterations | Attempts | Retries | Mass rejections | Max absolute trial mass, cm |
| --- | --- | --- | --- | --- | --- | --- |
| 1e-10 | PASS | 53900 | 5796 | 4648 | 0 | 2.18957e-14 |
| 1e-8 | PASS | 53900 | 5796 | 4648 | 0 | 2.18957e-14 |
| 1e-6 | PASS | 53900 | 5796 | 4648 | 0 | 2.18957e-14 |
| 1e-5 | PASS | 53900 | 5796 | 4648 | 0 | 2.18957e-14 |

Counts include all 28 qualification trials (two tiles, baseline/three centered deltas, replay). Jacobian builds, linear solves and backtracking counts also equal 53900 at each level. Maximum accepted step mass is 1.25036e-14 cm. Trial output and both tile response records are identical across all four levels. Lower-face heads are approximately .500000140779268 and .500000140766665 m; derivatives are 13.563961320794959 and 13.563961925866508 day. Snapshot immutability, provenance, discard and bitwise replay checks pass.

Fresh-process elapsed values 1.62 to 1.77 seconds include qualification overhead and concurrent workload; they are not a speed estimate. Direct work is identical. Therefore **1e-5 is not falsified by this separated, single-state predictor test, but has no demonstrated work advantage and is not qualified as a production default**. The remaining strict head/temporal criteria may be limiting; this experiment does not isolate their individual effects.

## Live exact coupling and partition preflight

Using internal balance 1e-10 and the frozen rain10/zero 24-window field-depth fixture, exact accepts three windows then fails predictor preparation for window 4. Holding RFM tolerance separately at 1e-12 reproduces this failure. Diagnostics identify pre-solver surface composition REFERENCE_REQUIRED: preflight classifies all incoming rain as matrix supply and predicts ponding before RFM partitions it. At the terminal retry, top head is -26.0063607875 cm, preferential supply is about 5.00706383 cm/day, prospective ponding is 1.67117e-9 cm, and the solver is not executed. Merely increasing Richards iterations cannot fix this pre-solver rejection.

The registered repair re-evaluates matrix preflight after partition only for an accepted unponded state with zero evaporation and the specific reference-required surface failure. Original total input is retained for partition/accounting. Existing post-partition ponding/regime checks remain hard. It does not add a ponded RFM formulation.

The repair advances exact through eleven published windows, then a window-12 corrector fails (participant status 6). All eleven accepted rows reproduce under observation-only replay. Accepted RFM storage remains exactly zero in both tiles. Thus the fixture does not satisfy the original activity gate even before considering its failure. No A28 paired execution or production timing is authorized by these outcomes.

The corrected concrete-FMR observer reproduces all eleven accepted rows bitwise: window12 fails at t=.11785515063514931, with 305 accepted substeps, 2670 attempts, 2364 retries, six solver rejections, 2359 temporal rejections and zero mass rejections. The 4096-substep cap is not the cause. The initial observer targeted the generic participant and emitted no corrector evidence; this instrumentation mistake is retained, rather than labelled a successful diagnostic.

## Head convergence and live balance policy

Separately declared head absolute/relative tolerances 1e-8 and1e-6 pass initial rain1 centered-FD qualification. Nonlinear/Jacobian/linear work falls from53900 to49616 and38808, respectively (7.95% and28.00%). Attempts/retries remain5796/4648; external maximum trial mass is2.32019e-14 cm. At head1e-6 the composed predictor is hcof=.073724774111140728, rhs=.036862397831620611, href=.50000014077108312 m, close to the strict reference hcof=.073724773121492254, rhs=.03686239733679636, href=.5000001407710758 m. These are initial-state work observations, not production runtime estimates.

Both relaxed-head live balance1e-10 runs still fail corrector12. HeadCalc observation at head1e-6 identifies internal balance residuals above1e-10 at16/16 iterations; typed invalidation is false and no head-failure marker appears. Thus the initial-state balance frontier did not cover the limiting later state.

| Exact live research policy | Completed windows | Failed operation | Partial completion day | Failure classes on final trial |
| --- | --- | --- | --- | --- |
| Balance1e-10, head1e-12 | 11 | corrector12 | .11785515063514931 | solver6, temporal2359, mass0 |
| Balance1e-10, head1e-8 | 11 | corrector12 | .11533832546729261 | solver5, temporal1568, mass0 |
| Balance1e-10, head1e-6 | 11 | corrector12 | .11558688788812405 | solver5, temporal1680, mass0 |
| Balance1e-5, head1e-6 | 14 | predictor15 | .14541163048437583 | solver0, temporal1781, mass0 |
| Balance1e-5, head1e-6, proposal cap1e-4 day | 14 | predictor15 | .14541271972656172 | solver0, temporal455, mass0 |
| Balance1e-6, head1e-6, same proposal cap | 14 | predictor15 | .14541271972656172 | solver0, temporal455, mass0 |
| Balance1e-8, head1e-6, same proposal cap | 14 | predictor15 | .14541269531249923 | solver3, temporal440, mass0 |

All use separated RFM1e-12, the partition repair and unchanged external gates. Balances1e-5/1e-6/1e-8 with capped proposals have identical fourteen accepted rows. The uncapped1e-5 candidate differs from the strict reference over their eleven-window overlap by at most3.997e-15 m head,4.326e-19 m/s weighted flux and8.527e-14 cm matrix storage. The proposal change differs by2.539e-8 m,7.680e-13 m/s and4.727e-6 cm over that overlap. Small accepted-prefix drift cannot establish completion or the frozen24-window accuracy envelope.

The capped failing trial uses201 accepted substeps,656 attempts,454 retries and6159 nonlinear/Jacobian/linear solves. It is still far below the substep cap. Observation-only temporal-component replay reproduces accepted rows and failure bitwise. The final rejected comparisons are dominated by pressure in saturated nodes5 through10. Pressure error grows approximately twofold per retry to .489053600245 cm while matrix-water differences fall to6.66e-15 cm; ponding, groundwater-level and RFM storage differences are zero. Merely reducing proposals or tightening balance to1e-8 does not resolve this failure. These observations localize a saturated-pressure response/temporal-certification problem; they do not prove a specific linear algebra defect or authorize ignoring the pressure gate.

**No practical solver tolerance is qualified across this live workload.** In particular1e-5 removes the earlier balance stop without material accepted-prefix hydrological drift, but does not yield a robust predictor. Its isolated initial test does not demonstrate a work advantage. Nor did the tighter live candidates provide a qualified alternative. This does not prove that1e-5 universally causes physical error.

## Complete water inventory and active-physics eligibility

An independent accepted-state inventory uses rainfall, actual initial matrix storage41.14839212285944 cm per tile, final matrix/RFM storage and published tile interface fluxes. It separately reconstructs each deep receipt from complete corrector mass totals, allowing both incoming and outgoing matrix-bottom water in one window. These two calculations agree within4.927e-16 cm; matrix-interface exchange agrees within2.603e-18 cm and accepted local mass residual is at most2.499e-16 cm.

At window14, applied rain is .8 cm, cumulative distinct deep receipts are .076079071523065 cm and .1973364409517715 cm, area weighted .1548963616517245 cm, or19.36% of rain. This is **accounted SWAP external water**, not a local SWAP mass failure. The backend adds it to total_out but publishes only matrix-bottom exchange in bottom_outward_exchange_native; the groundwater participant and fixture interface ledgers consume that matrix exchange. This fixture provides no receiver ledger or MODFLOW publication for the distinct receipt. Consequently its existing interface gates do not establish complete coupled RFM receipt ownership/global water closure.

The [leading MB contract](PPA_WU05A26I_MACRO_HEAD_CONTRACT.md) deliberately defines a distinct deep receipt. Assigning it implicitly to groundwater would change receiver ownership/physics. No such production change was made. A production profile must explicitly identify the receiver and its transaction/publication ledger, whether MODFLOW or an external sink.

Accepted RFM storage is exactly zero in each tile at every published window. The head excursion through the accepted prefix is only .03755 cm, below the frozen .1 cm floor. Preferential partition/deep-through physics is active, but the required nonzero preferential storage qualification is absent. The inherited endpoint exchange length .5 cm and fast release need a separately justified field geometry if persistent-storage behaviour is to be tested; no retrospective fixture tuning or seeded storage was used to manufacture eligibility.

## Production disposition and performance limits

Decision **COUPLED_RFM_BLOCKED** is supported by three independent findings: reproducible live exact predictor failure, absent distinct-receipt receiver ownership in this fixture, and failed preferential-storage eligibility. The original24-window exact correctness gate never passes. Therefore A28_V1 was not run on these field-depth postimages, the original2% envelope remains preregistered/unqualified, and neither production performance nor MultiSWAP scalability is claimed. Historical shallow-fixture/component results and strict-equivalence failures remain unchanged. A28 remains component-only.

Reducing qualification sampling to one centered middle-delta pair could avoid baseline/multiple-delta/replay work after separate stability calibration; this was not deployed against an unqualified live predictor. The measured head-policy work reductions and proposal retry savings identify potential numerical optimization, not a qualified end-to-end speedup. No build, download or setup time is used for a production timing claim, and no new GitHub Actions run was launched.

The bounded numerical ladder is complete. Resolving the saturated prescribed-qbot pressure response needs a separately owned numerical design/qualification; resolving deep receipt needs explicit receiver ownership; a representative persistent-storage fixture needs justified geometry and fresh preregistration. These are substantive requirements, not tolerance changes that can be hidden behind relaxed external acceptance. Current canonical differences must also be reconciled before any production trial.

Validation: local O2 Fortran builds with `-fcheck=all -fbacktrace` pass; generated bounded and observation-only postimages compile/link. Python syntax, documentation source checks and strict MkDocs build pass. The independent water-inventory checks pass for bounded balances1e-5/1e-6/1e-8 and temporal replay. The exact24 numerical qualification runs deliberately remain failures as recorded above; a successful build/documentation check does not override them.

## Existing CI and persisted evidence

### Saturation event diagnosis and restricted prototype

Further continuation atc92997b0 observed the actual converged Newton equations for prescribed-qbot steps below1e-7 day. The15-window observation replay reproduces the fourteen accepted control rows bitwise. The pressure discrepancy is already in the converged physical solve, not introduced by serialization. Cell5 starts just below saturation and becomes saturated, with cells6:10 already saturated and zero sources/sinks. Positive qbot is into SWAP. Its balance implies:

```text
h5 = h4 + 10 - 10*(10*delta_theta5/dt - qbot)/K5
```

The independent reconstruction matches all12 observed crossing solves within3.553e-14 cm. At the final origin, h5_old=-1.380331e-5 cm and the remaining theta deficit is3.953151e-10. Filling that fixed deficit shifts whole-step pressure by100*delta_theta5/(dt*K5). The offset grows from .122264 cm atdt=9.765625e-8 day to .244528 and .489057 cm on halving. After the first half has filled the deficit, the second half has zero saturated storage increment and terminal algebraic pressure about1.384134 cm. Thus pressure discrepancy grows even though both endpoints have essentially identical stored water. This specifically identifies the discrete unsaturated-to-saturated transition with zero saturated storage; it is not evidence of an inaccurate tridiagonal solve. Earlier generic conditioning/cancellation hypotheses are superseded by this measured cell balance. This does not assert that continuous physical soil pressure should make the same jump.

The source/probe and reproducible analyzer are in `evidence/PPA_WU05A28_SATURATION_EVENT_PROBE.json.gz` and `tests/fpe/analyze_fpe_a28_saturation_event.py`. The reconstruction assertion is observational, not a changed transaction gate.

One preregistered research prototype reconstructs only the post-fill saturated terminal pressure for a prescribed-flux solve, using frozen Darcy conductivities and the preceding unsaturated head. Stored water, integrated fluxes and all existing acceptance budgets remain fixed. This is a changed terminal-state interpretation, not an admitted exact-preserving repair. The prototype reproduces the fourteen control rows bitwise, passes predictor15 and publishes window15; the corrector16 then fails at .15425146484375257 with3993 accepted substeps,31982 attempts,27989 temporal rejections,zero solver/mass rejections and240156 nonlinear iterations. No24-window correctness pass results. Evidence is `evidence/PPA_WU05A28_POSTFILL_PROTOTYPE.json.gz`; builder flag `A28_POSTFILL_TERMINAL_PRESSURE_PROTOTYPE=1` requires field-depth and stable-increment flags. The builder reproduces the compiled generated source bitwise.

The remaining corrector uses prescribed head, where qbot is an output. Its adapter materializes bottom exchange with the existing exact storage/flux arithmetic. Any event-aware integration or terminal-pressure reconstruction must preserve this integrated exchange, state ownership and mass contract, rather than substituting an instantaneous Darcy flux. The corrector16 rejection has not yet been localized to the same cell event; do not infer that simply extending the predictor reconstruction to prescribed head repairs it. Decision remains COUPLED_RFM_BLOCKED; registered strict completion remains14 windows, while15 is only an unqualified prototype result. Receipt ownership, nonzero RFM storage and A28/performance qualification remain unresolved independently.

Continuation after decision0890aac6 tested one concrete cancellation hypothesis, preregistered at1e12c53f. HeadCalc only dispatches the stable typed water-content increment when matrix-area scaling is active; the generated causal postimage dispatches it for all typed constitutive runs. Local bounds-checked incremental compilation/link succeeds. Exact24 again accepts fourteen windows and fails predictor15 at the identical partial time .14541271972656172 with identical final counts:201 accepted substeps,656 attempts,454 retries,455 temporal rejections,zero solver/mass rejections and6159 nonlinear iterations. Accepted-prefix differences relative to the capped control are only rounding scale (see bundled values). Therefore bypassing the existing stable increment does not explain or resolve this blocker. It is not admitted as a repair. Evidence is `evidence/PPA_WU05A28_STABLE_INCREMENT_PROBE.json.gz`, including full run log/result, comparison and object/library/source hashes. Decision remains COUPLED_RFM_BLOCKED. This additional falsification does not change the separate receiver/storage findings or authorize another tolerance ladder.

Frontier workflow37184823346 completed with failure at1e-8 and stopped under shell set-e; CI did not test1e-6/1e-5. Artifact11296921715 has SHA256 bcd23aa892d3e2693b469034214d02aaf572beaa058cc55e9036e68b4dd67e3a, but contains build/HeadCalc material rather than the missing frontier log. [CI metadata](evidence/PPA_WU05A28_FRONTIER_CI_METADATA.json) records this limitation. Local fresh-process evidence covers all four levels and the isolated repeat.

Evidence also includes `evidence/PPA_WU05A28_CORRECTOR_HEAD_PROBE.json.gz`, `evidence/PPA_WU05A28_LIVE_POLICY_EVIDENCE.json.gz` and its [manifest](evidence/PPA_WU05A28_LIVE_POLICY_MANIFEST.json). The temporal observer generated a95MB repetitive trace. All non-comparator output plus first16/last32 complete component/head-vector records are retained; the full log SHA256, size and comparator count are recorded. The full original is local, not completely archived. Local preregistration commit history is included in the bundle; remote checkpoints retain code/policies and evidence separately.

## Reproduction

Build with bounds checks:

```bash
A28_FIELD_DEPTH=1 A28_SEPARATE_RFM_TOLERANCE=1 \
  python3 tests/fpe/build_fpe_a28_coupled_local.py /tmp/a28-separated
FGC45_MULTISWAP_LIB=/tmp/a28-separated/libfgc45_multiswap.so \
  python3 tests/fpe/run_fpe_a28_solver_frontier.py /tmp/a28-frontier-evidence
```

For repaired live diagnostic add `A28_PARTITION_AWARE_PREFLIGHT=1 A28_RFM_PREPARER_DIAGNOSTICS=1 A28_CORRECTOR_DIAGNOSTICS=1` to the build. Use independently validated MODFLOW 6.8.0 LIBMF6; the existing release archive SHA256 is `33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e`.

```bash
A28_H0_CM=-45 A28_DT_DAY=.01 A28_RAIN_CM_DAY=10 \
  A28_SOLVER_BALANCE_TOL_CM=1e-10 \
  FGC45_MULTISWAP_LIB=/tmp/a28-repaired/libfgc45_multiswap.so \
  LIBMF6=/path/to/validated/libmf6.so A28_RESULT=/tmp/exact.json \
  python3 tests/fpe/test_fpe_a28_coupled_windows.py exact 12
```

The twelve-window run reproduces the failing prefix; it does not replace the original 24-window completion gate. Never run A28 after this failed exact prefix.

For the bounded live1e-5/1e-6/1e-8 falsification add `A28_BOUNDED_TRANSACTION_PROPOSAL=1` at build, set `A28_HEAD_ABS_TOL_CM=1e-6 A28_HEAD_REL_TOL=1e-6` and the respective balance setting at execution, and request24 windows. Add `A28_TEMPORAL_COMPONENT_DIAGNOSTICS=1` only for the observation replay (large log).

```bash
python3 tests/fpe/analyze_fpe_a28_water_inventory.py \
  /tmp/exact.json /tmp/exact.log /tmp/water-inventory.json
```

The inventory requires complete-water observer output and partial JSON with initial storage. Its independent reconstruction assertions verify consistency; they do not expand the coupled acceptance contract.

Evidence: [solver bundle manifest](evidence/PPA_WU05A28_WORK_SOLVER_MANIFEST.json), `evidence/PPA_WU05A28_WORK_SOLVER_EVIDENCE.json.gz`, and `evidence/PPA_WU05A28_PARTITION_PROBE.json.gz`. The partition bundle retains all FD/window/failure output, first/last eight repeated surface diagnostics, full-output SHA256 and counts. It deliberately omits 519674 repetitive repair confirmation lines and redundant surface traces; this is disclosed evidence bounding, not a complete raw-log archive.

## Final event/basepoint continuation (supersedes unresolved corrector16 diagnosis)

The observation-only corrector16 replay reproduced the fifteen published prototype rows bitwise. Cell5 again crosses from negative to positive head above an already saturated block. At the rejected endpoint the whole/half head discrepancy is about0.099202 cm while theta differs by only3.33e-15; sources/sinks are zero. This localizes the prescribed-head rejection to the same zero-storage saturation transition. The214MB observer trace is explicitly bounded in `evidence/PPA_WU05A28_CORRECTOR16_EVENT_PROBE.json.gz`: all ordinary output and first/last16 records per observer tag, full original digest/size/counts and generated source are retained.

A separately preregistered anchored reconstruction preserves the adapter's integrated bottom exchange and stored water, reconstructing only nonnegative saturated terminal heads between the preceding unsaturated head and prescribed lower-face head with frozen Darcy conductivities. It changes terminal-state interpretation and is not an exact-preserving or admitted production repair. With fixed predictor basepoint and4096 substeps it still fails corrector16, now at the substep cap. No acceptance tolerance was relaxed.

The independent accepted-flux basepoint uses only the last successfully committed tile exchange and checks the accepted revision. Every logged basepoint matches that prior committed flux bitwise. With original terminal semantics it fails predictor15 at4096 substeps. One preregistered resource-only increase to16384 permits15 accepted windows but predictor16 still fails temporal retry at4123 substeps. Raising ceilings again is not supported. The default fixed-basepoint initialization regression passes.

Combining accepted-flux basepoint,16384 resource ceiling and the unadmitted anchored prototype accepts16 windows. Corrector16 needs4323 substeps and246712 nonlinear iterations for tile1 in its final outer trial: this is not practical performance evidence. The next wet pulse fails predictor17 before any Richards iteration. An observation replay reproduces all sixteen accepted rows bitwise and measures genuine ponding after partition: top head -19.13048743158306 cm, accepted pond0, top conductivity1.0849365899776511 cm/day. Across13 retries, the preferential rate tends to0 and matrix rate to10 cm/day. At dt2.441406249387157e-8 day the candidate pond remains3.665216403829571e-8 cm, above the unchanged1e-12 gate. Thus this is the unsupported ponded/reference surface route, not the earlier pre-partition confound or an internal nonlinear tolerance failure. Relaxing the pond gate would hide an absent physical capability and is not a repair.

Independent sixteen-window inventory agrees with the direct receipt ledger within5.205e-16 cm; maximum local mass residual is2.498e-16 cm. This does not assign the distinct RFM deep receipt to a MODFLOW receiver. Accepted RFM storage remains0 in both tiles; head excursion is only0.056074 cm versus the registered0.1 cm activity gate. No prefix meets the complete24-window/activity/receiver contract.

Final disposition remains **COUPLED_RFM_BLOCKED**. Balance1e-5 is not a qualified production default; tightening to1e-6/1e-8 did not remove the previously observed event failure. A28 remains component-only, with its practical2% envelope untouched and untested on a qualified live field-depth run. No production predictor single-pair or MultiSWAP performance claim is made. Further progress requires a physically specified ponded RFM route, explicit deep-receipt receiver ownership and admitted saturation-event handling, rather than another tolerance/resource ladder.

The latest full bounds-checked local build and fresh initial FD regression pass. Raw ordinary logs/results, inventory, basepoint checks, source hashes, preregistration chronology and build/regression logs are in `evidence/PPA_WU05A28_EVENT_BASEPOINT_CONTINUATION.json.gz`, with `PPA_WU05A28_EVENT_BASEPOINT_MANIFEST.json`. No new Actions were launched.
