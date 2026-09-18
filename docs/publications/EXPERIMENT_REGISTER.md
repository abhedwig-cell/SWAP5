# Publication experiment register

Status: **living execution-readiness register**

Purpose: track which publication experiment families are ready for screening, reference construction or primary execution, and which prerequisites still block them.

This register does not contain scientific results. It is an execution map between the scientific contracts, experiment matrices and future run manifests.

## Status vocabulary

- `DESIGNED`: experiment family is specified but prerequisites are not all ready;
- `READY_FOR_SCREENING`: exploratory/supporting runs may begin;
- `READY_FOR_REFERENCE_CONSTRUCTION`: numerical-reference runs may begin;
- `READY_FOR_PRIMARY_FREEZE`: enough screening exists to freeze the primary matrix;
- `READY_FOR_PRIMARY_RUN`: primary matrix and all prerequisites are frozen;
- `BLOCKED`: a named scientific/technical prerequisite is missing;
- `COMPLETE`: run family completed under manifest control.

## Programme register

| Run family | Owner | Evidence role | Current status | Main blocker / next action |
| --- | --- | --- | --- | --- |
| `PUB-ME-E0` reference lineage | PUB-ME | supporting/foundational | READY_FOR_SCREENING | migration-slice candidate set frozen in `PUB-ME_MIGRATION_SLICES.md`; recover exact historical pre/post authorities for ME-S1/ME-S2/ME-S3 |
| `PUB-ME-E1` preservation reruns | PUB-ME | primary | DESIGNED | reconstruct exact historical build/input authorities for selected slices and freeze common benchmark set |
| `PUB-ME-E2` candidate-leak adversarial | PUB-ME | primary | DESIGNED | define qualification-only fault-injection harness; never production |
| `PUB-ME-E3` restart sufficiency | PUB-ME | primary | READY_FOR_SCREENING | select benchmark cases with/without prior retry and instantiate manifest |
| `PUB-ME-E4` semantic-successor evidence | PUB-ME | primary | READY_FOR_SCREENING | ME-S5 frozen as semantic-successor Case B; freeze exact unrelated-change Case A from ME-S6 before detailed extraction |
| `PUB-ME-E5` qualification-surface analysis | PUB-ME | supporting | DESIGNED | define repository-derived surface metrics; no person-hour claims |
| `PUB-ME-E6` extensibility cases | PUB-ME | supporting | READY_FOR_SCREENING | extract solver-seam and groundwater-seam dependency evidence |
| `PUB-SQ-E0` contract/fail-closed | PUB-SQ | prerequisite/supporting | COMPLETE | `PUB-SQ-E0-0001` completed under manifest control; continue with SQ-E1 common-domain/reference design, not additional post-hoc E0 cases |
| `PUB-SQ-E1` common-domain equivalence | PUB-SQ | primary | DESIGNED | freeze stratified case matrix and build `REF-HIGH` procedure |
| `PUB-SQ-E2` admissibility boundary | PUB-SQ | primary | DESIGNED | reconcile exact RossFast envelope and choose paired inside/boundary/outside cases |
| `PUB-SQ-E3` equal-error cost | PUB-SQ | primary | BLOCKED | accuracy thresholds + stable `REF-HIGH` required first |
| `PUB-SQ-E4` trajectory accumulation | PUB-SQ | primary | DESIGNED | choose common-domain forcing sequences after SQ-E1 screening |
| `PUB-SQ-E5` expanded scientific domain | PUB-SQ | future | BLOCKED | requires separate RossFast domain qualification |
| `PUB-GC-E0` interface conservation | PUB-GC | prerequisite/supporting | COMPLETE | `PUB-GC-E0-0002` completed under manifest control on the exact F-VQ87 postimage; do not add post-hoc E0 cases |
| `PUB-GC-E1` same-origin replay | PUB-GC | primary | COMPLETE | one-shot held-out primary `PUB-GC-E1-PRIMARY-0001` completed validly; both preregistered history discriminants exceeded their numerical floors while same-origin replay remained exact; H1 supported at operator-definition level only, practical materiality/generalization remain open |
| `PUB-GC-E2` whole-window vs terminal flux | PUB-GC | primary | READY_FOR_SCREENING | comparator and `GC-REF-A` are qualified; first nested reference screening is stable; next freeze and execute a small transient screening matrix, then select held-out primary cases by a predeclared rule |
| `PUB-GC-E3` window convergence | PUB-GC | primary | READY_FOR_SCREENING | multi-window `GC-REF-A` construction is demonstrated and the calm screening case is stable; next screen stronger transients, preserving full refinement ladders and excluding screening cases from held-out primary evidence |
| `PUB-GC-E4` robustness domain | PUB-GC | primary | BLOCKED | predeclared accuracy thresholds and GC-E3 reference required |
| `PUB-GC-E5` MODFLOW 6 transfer | PUB-GC | primary | BLOCKED | concrete scientifically admitted MODFLOW 6 backend |
| `PUB-GC-E6` bounded N:1 conservation | PUB-GC | supporting/primary table | READY_FOR_SCREENING | map existing F-GC25 cases into publication manifest without upscaling claims |
| `PUB-GC-E7` realistic demonstration | PUB-GC | supporting | BLOCKED | controlled GC-E1..E5 method evidence must exist first |
| `PUB-RC` response-assisted matrix | PUB-RC | future primary | BLOCKED | SWAP-side whole-window response / interface derivative method not yet established |
| `PUB-SG` heterogeneity matrix | PUB-SG | conditional future | BLOCKED | only start after PUB-GC coupling/reference basis is mature |

## Immediate executable tranche

The following work can begin without inventing new production science:

### Tranche A — evidence extraction and screening

1. `PUB-ME-E0`: recover exact authorities for the already frozen migration-slice candidate set;
2. `PUB-ME-E4`: freeze the exact unrelated-change Case A paired with frozen semantic-successor Case B;
3. `PUB-GC-E0`: complete; no further post-hoc E0 screening cases are added;
4. `PUB-GC-E6`: re-express bounded N:1 conservation cases under publication manifests;
5. `PUB-SQ-E0`: complete; no further screening cases are added post hoc; the family hands off to SQ-E1 reference/common-domain design.

These are primarily screening/foundational tasks. They should not be mistaken for final primary publication evidence.

### Tranche B — reference-construction preparation

In parallel:

- `PUB-SQ-REF-HIGH`: define the refinement procedure and stability criterion;
- `PUB-GC-GW-A`: **qualified research component** at research head `8a090fc9228574525e599817771aadb8ae176047`; receipt `PUB-GC-GW-A-QUAL-0001`;
- `PUB-GC-E1-HARNESS`: complete, including held-out E1 primary execution; preserve the one-shot evidence without post-hoc rerun;
- `PUB-GC-GC-REF-A`: **qualified reference machinery** at research head `4fc8f6e2a7569503594d0ecf91b651431c607df2`; receipt `PUB-GC-GC-REF-A-QUAL-0001`; next construct case-specific temporally refined reference trajectories;
- shared publication telemetry serialization: define before primary matrices are frozen.

No primary claim run should begin until the relevant definitions, implementation prerequisites and run manifest are frozen.

## Blocker policy

A `BLOCKED` experiment must fail closed. Do not substitute an easier method merely to obtain a green publication matrix.

Examples:

- no MODFLOW 6 claim without a scientifically conformed backend;
- no equal-error solver claim without a stable high-accuracy reference;
- no response-assisted claim without a qualified/defensible interface response;
- no subgrid-value claim without a credible effective comparator.

## Readiness chronology

### 2026-09-17T18:31Z — PUB-SQ-E0 screening completed

- controlling manifest commit: `892a7d13631dd226850a6c5f6869e1d7567bf909`;
- result receipt commit: `7cfe328e3fa46231837eb41cace5cab11fb05f84`;
- prerequisite satisfied: manifest-controlled contract/fail-closed screening executed;
- next permitted action: SQ-E1 reference/common-domain design;
- cross-publication effect: none; no GC, ME or RC primary claim is inherited.

### 2026-09-17T18:31Z — PUB-GC-E0 first execution invalidated

- controlling manifest commit: `9bdd605ad2d6189f431e513e955bbb53ce01f28a`;
- invalid-execution receipt commit: `aacbfceb2ca18145e693af952d177f3d4784fbaf`;
- prerequisite invalidated: the old owner runner was not a valid build harness for the later moving canonical source graph;
- next permitted action: new manifest required before changing execution route;
- cross-publication effect: none; no scientific GC result was admitted from the invalid attempts.

### 2026-09-17T18:34:20Z — PUB-GC-E0 replacement preregistered

- controlling manifest commit: `71b7904a3ddee39c7e3a92c5f1dc23d2feaeaafe`;
- prerequisite satisfied: exact independent F-VQ87 authority, runner blob and oracle-test blob frozen before execution;
- next permitted action at that boundary: execute `PUB-GC-E0-0002` unchanged on the pinned F-VQ87 postimage;
- chronology note: the manifest's internal `created_utc` field was inaccurate; Git commit time is the authoritative preregistration boundary and is preserved in the result receipt;
- cross-publication effect: none; this remains PUB-GC supporting evidence and does not establish current-canonical generalized runtime qualification.

### 2026-09-17T18:36:26Z — PUB-GC-E0 replacement screening completed

- controlling manifest commit: `71b7904a3ddee39c7e3a92c5f1dc23d2feaeaafe`;
- result receipt commit: `218c579d155887423343c0c5daef95a5f67a182c`;
- execution: GitHub Actions run `35259757727`, job `105332222414`, research head `b3f33f031bcf642e2cca3ecfb6d6ac1983257aab`;
- prerequisite satisfied: manifest-controlled independent interface-semantics screening completed on the pinned F-VQ87 postimage;
- admitted scope: bounded F-GC25 interface conservation, rollback, action/reaction and fail-closed topology/origin screening on the exact qualified postimage;
- next permitted action: define and freeze GW-A plus the GC-E1 history-contaminated diagnostic comparator and GC-REF reference procedure before primary replay/convergence runs;
- cross-publication effect: none; no ME, SQ, RC or SG primary claim is inherited, and MODFLOW/window-accuracy claims remain untested.

### 2026-09-17T21:01:45Z — PUB-GC GW-A component decision frozen

- scientific specification commit: `b6800d1337c2101b39d1c07e45ee808a35711926`;
- decision receipt commit: `9ab529a7d905f73b27513320dfdac537339b90e8`;
- reviewed historical fixture: `F-GC21@1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f`, source blob `d3cd07965f6fc0d0628557b18d65f3bbc9396888`;
- decision: the F-GC21 dummy remains a transactional qualification test double and is not admissible as `GW-A`, because its returned head is scripted rather than derived from a physical storage/exchange state;
- prerequisite newly satisfied: GW-A scientific equation, signs/units, transactional state semantics, diagnostic history-contamination boundary and minimum component qualification are frozen before implementation or E1 execution;
- next permitted action: implement and independently qualify the research-only GW-A component and diagnostic origin-policy harness; do not preregister or execute a primary E1 run until those prerequisites are green;
- cross-publication effect: none; no MODFLOW, production-backend, ME, SQ, RC or SG primary claim is created.

### 2026-09-17T21:06:31Z — PUB-GC GW-A research component qualified

- frozen scientific specification: `b6800d1337c2101b39d1c07e45ee808a35711926`;
- research branch/head: `research/pub-gc-gw-a@8a090fc9228574525e599817771aadb8ae176047`;
- qualification receipt: `docs/publications/results/PUB-GC-GW-A-QUAL-0001.yaml`, introduced by commit `dae4247162ee25233e149b5f5cb9790d2e2a73ef`;
- execution: GitHub Actions run `35274770691`, job `105382568910`, GNU Fortran 13.3.0 on Ubuntu 24.04.5;
- immutable research blobs: module `ac725a64ffa96f4f08998e9aac7537af5ca76ba0`, oracle `58711bc7eeab069ca937fd60e6e82e739bd5f156`, runner `48dab546bd6118e021f5ad2bfb1ed43f23a2ac97`;
- qualification result: analytic sign response, zero exchange, action/reaction assignment, same-checkpoint repeatability, nonpublishing prepare/abort, one-shot prepared commit, stale-checkpoint fail-closed behavior and O0/O2 oracle identity all PASS;
- prerequisite newly satisfied: a transparent, checkpointable, analytically qualified research groundwater component now exists before any E1 primary execution;
- next permitted action: implement and independently qualify the **real-SWAP** origin-policy research harness; freeze case/candidate sequence and preregister E1 only after that harness is green;
- cross-publication effect: none; this does not establish H1 or any MODFLOW, production-backend, ME, SQ, RC or SG primary claim.

### 2026-09-17T23:02:17Z — PUB-GC E1 real-SWAP origin harness qualified

- frozen harness specification: `2d0a9ea26dbb6048e60e67dcf6882a1b03664d61`, blob `554ebf5841b533b38f19dce533b2efb978348971`;
- qualified research branch/head: `research/pub-gc-gw-a@14ee1be3c221c973973a3fb3dcb450ff40d3f96a`;
- frozen production source tree used by the harness: `d7ef6c045263de821db7800459289efcd8a6420b`;
- qualification receipt: `docs/publications/results/PUB-GC-E1-HARNESS-QUAL-0001.yaml`, introduced by commit `a8676007e1adebbabd6235d08378ae5828fedb30`;
- execution: GitHub Actions run `35284904390`, job `105414974936`;
- qualification result: real B1.10 prescribed-head A/B/A same-origin replay, accepted-origin immutability, whole-window exchange availability, public snapshot+initialize history diagnostic, distinct research lineage, no production commit, fail-closed unsupported route, GW-A requalification and O0/O2 identity all PASS;
- chronology guard: the observed difference between same-origin and history-diagnostic qualification telemetry is retained for reproducibility only and is **not** H1 evidence;
- prerequisite newly satisfied: the composed E1 comparison harness is qualified before screening or primary-case selection;
- next permitted action: separately labelled transient screening within the broad bounds frozen in `PUB-GC_E1_ORIGIN_HARNESS_SPEC.md`; after screening freeze exact case, candidate heads, order permutations, metrics, thresholds and null interpretation before primary execution;
- cross-publication effect: none; no MODFLOW, PUB-ME, PUB-SQ, PUB-RC or PUB-SG primary claim is inherited.

### 2026-09-17T23:09:51Z — PUB-GC E1 SCREEN-0001 executed after supersession

- original manifest: `5c5d30273437bfc5082d2c91a75d25681cc8d15d`;
- superseding disjoint manifest: `bc8dca037912de10dbfce33d1ca7a62b34bc7761`, frozen at 2026-09-17T23:06:56Z, before SCREEN-0001 execution began;
- execution: GitHub Actions run `35285493995`, job `105416772498`;
- corrected receipt: `docs/publications/results/PUB-GC-E1-SCREEN-0001.yaml`;
- corrected status: `NON_AUTHORITATIVE_SUPERSEDED_BEFORE_EXECUTION`;
- authority consequence: no numeric result from SCREEN-0001 may be used for stress-class selection, primary numeric-point selection, thresholds or H1 inference;
- correction authority: `docs/publications/decisions/PUB-GC-E1-SCREENING_PROVENANCE_CORRECTION.md`.

### 2026-09-17T23:12:37Z — PUB-GC E1 disjoint SCREEN-0002 completed

- controlling manifest: `bc8dca037912de10dbfce33d1ca7a62b34bc7761`, blob `2aef35c16f1b7c87ebd7ff572adeb24e4e830ee4`;
- pre-execution trigger authority: `37e72ae755bce9920db7f157082fa13def3fea22`;
- immutable pre-trigger scientific code state: `research/pub-gc-e1-screening@a46acf93ae7918293f88f095c4138f617be1b64e`;
- execution head: `13bed3b93330bf403be96e0b7886274206c954b9`; its delta from the pre-trigger state changed only the workflow trigger;
- execution: GitHub Actions run `35285701916`, job `105417414871`;
- result receipt: `docs/publications/results/PUB-GC-E1-SCREEN-0002.yaml`;
- grid result: 21/21 PASS, 0 invalid, 18 noncontrol rows selection-eligible;
- predeclared class-selection result: `long + strong + drying-side`;
- selected screening row for class identification only: row 20, `dt=0.04 d`, `B=-100 cm`, endpoint-head diagnostic difference `7.78041462170561715 cm`, `|Delta Q|=3.06609633956691496e-02 cm`;
- holdout guard: that exact row, every SCREEN-0002 numeric point, every SCREEN-0001 numeric point and qualification-observed points are excluded from primary reuse;
- provenance note: the manifest's inline code-head placeholder was not populated before execution; the actual pre-trigger scientific code state and workflow-only trigger delta are recorded explicitly in the result/correction decision;
- interpretation guard: SCREEN-0002 selects only a broad stress class and is not H1 confirmation/falsification or a publication effect estimate;
- next permitted action: freeze new disjoint primary A/B/C numeric points, at least two order permutations, GW-A composition, primary metrics, thresholds and null interpretation before implementation/execution;
- cross-publication effect: none.

### 2026-09-17T23:26Z — PUB-GC E1 primary engine qualified

- qualification manifest: `bf62fc34ed603bf2fd551e8ea352310a1e823066`, blob `ea5042e51c61fbd6b11be87ded6198b8bdc44e81`;
- held-out primary manifest remained frozen at `c3114e455029ee5dee0d92dbc4814c3fc0923ef6`, blob `abf45b4a83f528eda69024e3d75a38edc4ce713f`;
- first qualification attempt: run `35286599570`, job `105420199550`, classified `INVALID_ENGINE_QUALIFICATION` after an O2 Fortran segfault caused by a strided polymorphic derived-type array temporary; no primary values were executed and no scientific conclusion was admitted;
- surgical research-only repair: remove the non-contiguous array-section handoff while preserving sequence semantics, fixtures, production source tree and primary holdout;
- controlling PASS execution: research head `98858378c2fcf48acbf1c2b34094056b7fc76c18`, run `35286757049`, job `105420678756`;
- immutable qualified blobs: engine `7214117cc64591bd4ced071561a19e37aab0de1b`, runner `1c8914b3b996ed455de91e9c8ffc5f2adf20bac8`;
- production source tree remained `d7ef6c045263de821db7800459289efcd8a6420b`; qualified origin-harness and GW-A bytes remained unchanged;
- Q1 and Q2 both passed O0/O2 exact scientific-output identity; their observed history-diagnostic magnitudes are qualification-only and may not be used for H1 effect estimation or primary tuning;
- qualification receipt: `docs/publications/results/PUB-GC-E1-PRIMARY-ENGINE-QUAL-0001.yaml`, introduced by commit `0bcbcad0dece1d4eada59f847bb0eb3908b56563`;
- prerequisite newly satisfied: a generic primary execution engine is frozen and independently qualified without executing the held-out primary tuple;
- next permitted action: freeze the separate primary execution authority against the qualified engine blobs, then execute `PUB-GC-E1-PRIMARY-0001` exactly once; no post-result changes to A/B/C, window or numerical discrimination floors;
- cross-publication effect: none; H1 remains untested by primary evidence at this boundary.

### 2026-09-17T23:32Z — PUB-GC E1 held-out primary completed

- frozen scientific primary manifest: `c3114e455029ee5dee0d92dbc4814c3fc0923ef6`, blob `abf45b4a83f528eda69024e3d75a38edc4ce713f`;
- frozen execution authority: `a2fab00d6076933972cee924d7d392ec6bc5024c`;
- pre-trigger primary execution head: `13753ee92c77f1492852500f5586f7fd7ae66773`; zero workflow runs existed on that head;
- one-time sentinel execution head: `936312659522fe4cacfd349b146d173caa07e5ab`;
- GitHub Actions run `35287247968`, job `105422209812`, conclusion `success`;
- primary raw output SHA-256: `514ccd628d4f4e8aff6de32022587c5018bc5d23a039e74b5fd0ca8e9d25ae4a`;
- artifact `10524847570`, digest `sha256:0370c5a17033d789e60576a4a0253a8edf3c50dba1b4ab4244a468fa05ccfab6`;
- same-origin repeated A/B/C response identity PASS, accepted-origin immutability PASS, GW-A same-checkpoint/no-commit PASS, and the history diagnostic remained explicitly non-production-valid;
- frozen discriminants: `Delta Q_A(after B vs C) = 3.07959298679549853e-3 cm` > `1e-9 cm`; `Delta endpoint head = 1.31893680771767663 cm` > `1e-8 cm`;
- preregistered interpretation: H1 is supported at the operator-definition level for this controlled held-out real-SWAP/GW-A case; E1 does not establish practical hydrologic materiality, MODFLOW6 transferability or generality beyond the tested case;
- result receipt: `docs/publications/results/PUB-GC-E1-PRIMARY-0001.yaml`, introduced by commit `e0d7c70d855d20665699ab3d86489b04144e01a7`;
- next permitted action: preserve E1 without rerun or retuning; proceed independently to E2 whole-window-versus-terminal-flux comparator design and E3 coupling-reference construction;
- cross-publication effect: E1 may later support thesis synthesis, but its primary claim remains owned by PUB-GC.

## Register update rule

Whenever a run family changes status, record:

- date/time;
- controlling commit;
- prerequisite newly satisfied or invalidated;
- next permitted action;
- whether the change affects another publication line.

The register should describe readiness, not rewrite past chronology.


### 2026-09-17T23:39:55Z — PUB-GC E2 terminal comparator qualified

- controlling specification commit: `4e9d891f9a4d1678e5fa4590adae13471597d72e`;
- controlling qualification manifest commit: `ceb695cbdbf08f5f8c6a97f1af3deac4da69ebc2`;
- qualification receipt commit: `d2ed6bd028a253e17e8bf48837647189922fd7ed`;
- research branch/head: `research/pub-gc-e2-terminal-comparator@188c863f560d8adacf255edb4f6f83edcac798f3`;
- successful execution: GitHub Actions run `35287826254`, job `105423983032`;
- invalid predecessor: run `35287702976` failed at compile time because the checkpoint origin-time accessor was called with the wrong public API form; it carries no scientific inference;
- qualification result: comparator authority locks, production-source preservation, no-SWAP-execution, no-groundwater-commit, exact terminal rectangle, synthetic selectivity controls, real frozen E1-B analytic projection, nonfinite fail-closed behavior and O0/O2 identity all PASS;
- primary H2 inference remains **not executed**; the frozen E1-B row is qualification-only and its near-zero whole-window/terminal difference is not an H2 effect estimate;
- next permitted action: define and freeze `GC-REF`; separately labelled E2 screening may proceed but cannot become primary evidence;
- cross-publication effect: none; no PUB-ME, PUB-SQ, PUB-RC or PUB-SG primary claim is inherited.


### 2026-09-17T23:49:53Z — PUB-GC GC-REF-A machinery qualified

- controlling specification commit: `c95d67c70dc16126797c6613affe641537e3655e`;
- controlling qualification manifest commit: `abb9d7b5a397abef1987ed8b6872064a13788c9b`;
- qualification receipt commit: `4d028af031bc506b33db9513552070a297ea4409`;
- research branch/head: `research/pub-gc-gc-ref-a@4fc8f6e2a7569503594d0ecf91b651431c607df2`;
- execution: GitHub Actions run `35288524091`, job `105426089799`;
- derivative-free same-origin bisection, invalid-bracket rejection, same-origin repeatability, final reconstruction, action/reaction closure, accepted-origin isolation, stable/unstable refinement adjudication and O0/O2 identity all PASS;
- the frozen real qualification bracket `[-80,-70] cm` contained a root without post-run retuning; reconstructed relative head `2.12579965591430664e-4 m`, residual `5.64160231581573544e-9 m`, whole-window exchange `4.25148647981838605e-3 cm`, 26 bisection evaluations;
- this qualifies the **reference machinery only**. No H2/H3 effect estimate or practical window threshold follows from the qualification fixture;
- next permitted action: freeze publication accuracy thresholds, construct case-specific nested L0/L1/L2 trajectories, and require L1-to-L2 stability before calling the finest trajectory a numerical reference;
- cross-publication firewall: no tangent/response acceleration inference belongs here; such efficiency claims remain `PUB-RC`.


### 2026-09-17T23:57:13Z — first nested GC-REF-A trajectory screening stable

- manifest: `PUB-GC-GC-REF-A-SCREEN-0001`, frozen at commit `a702dbd47bab84a634c49f3d3cdc4e63701317bd`;
- result receipt commit: `9235d67ae83bfda902eb0fbb0af3712b94078d97`;
- research branch/head: `research/pub-gc-reference-screening@c48ad3e09a7ab373e3ee424ae90fabbb65e83e4f`;
- execution: GitHub Actions run `35289048209`, job `105427691034`;
- exact O0/O2 scientific-output identity: PASS;
- accepted-state advancement used the normal SWAP commit-with-receipt route plus GW-A prepare/commit; root-search candidates remained discard-only;
- frozen nested ladder: 0.04 d / 3 windows, 0.02 d / 6 windows, 0.01 d / 12 windows over the same 0.12 d interval;
- L1→L2 differences: max matched GW head `1.08404898824178593e-7 m`, cumulative exchange `1.09111579993381724e-6 cm`, final max SWAP head-profile difference `7.49676515425790058e-4 cm`, max water-content difference `6.96306166836357932e-7`, storage difference `1.09111579993381724e-6 cm`;
- all prospectively frozen stability criteria PASS;
- this is supporting reference-construction evidence only; the calm case is permanently excluded from held-out E2/E3 primary evidence;
- next permitted action: preregister a small transient screening matrix, build stable references for those cases, and use a frozen selection rule before held-out primary case freeze.


### 2026-09-18T00:13:59Z — PUB-GC transient screening attempt 1 invalidated by reconstruction-forcing defect

- frozen manifest: `6096c24e91d6d9ab8ee8b812b0090123878a6cef`, blob `7aa93be2f6698ad6e655e70bf1024758e7516da4`;
- execution: `research/pub-gc-transient-screening@848d1414de10d7160841f59874a24ec14025773b`, GitHub Actions run `35290254007`, job `105431334545`;
- CI infrastructure and O0/O2 identity passed, but scientific execution was invalid because root evaluation applied the frozen transient `current_top_flux()` while accepted-root reconstruction reverted to the baseline forcing template;
- the four nonbaseline forcing cases therefore failed at `PUB_GC_REF_TRAJECTORY_RECONSTRUCTION_FAILED`;
- debugging outputs from the two baseline-only cases carry no screening selection authority;
- invalid-execution receipt: `docs/publications/results/PUB-GC-TRANSIENT-SCREEN-0001-ATTEMPT-0001.yaml`, commit `e7a112a8bdcf3a6962e47b464b4da8f9bba0e710`;
- no case value, threshold, root control, heldout candidate or promotion rule was changed;
- permitted repair was restricted to reapplying the already frozen top flux during reconstruction;
- cross-publication effect: none.

### 2026-09-18T00:16:18Z — PUB-GC transient screening validly completed, zero families promoted

- unchanged frozen manifest: `6096c24e91d6d9ab8ee8b812b0090123878a6cef`, blob `7aa93be2f6698ad6e655e70bf1024758e7516da4`;
- surgical repair: `4a79ecc202d80f408eca1013b90270e40c316ec8`; only the missing frozen top-flux assignment was added to transient accepted-root reconstruction;
- execution: GitHub Actions run `35290434715`, job `105431877460`, conclusion `success`;
- exact O0/O2 scientific-output identity: PASS; output SHA-256 `3cf22738a31c64d4eade47a6d97f4a229e8a094adabc8b45dbda32f985b20be4`;
- artifact `10525269748`, digest `sha256:d2b5985f35f7d8e322dec2cc5ffc776b93de46543f81399bb511cc94bdc342a3`;
- classifications:
  - `TS-WET-5`: `VALID_UNSTABLE`;
  - `TS-DRY-1`: `VALID_UNSTABLE`;
  - `TS-REV`: `VALID_UNSTABLE`;
  - `TS-GW-UP`: `VALID_STABLE_UNRESOLVED`;
  - `TS-GW-DOWN`: `VALID_STABLE_UNRESOLVED`;
  - `TS-LOW-SY-WET`: `VALID_UNSTABLE`;
- every reported whole-window-versus-terminal surrogate mismatch was exactly zero;
- frozen promotion rule result: zero `VALID_STABLE_RESOLVED` families, therefore no heldout H2/H3 candidate is promoted;
- valid result receipt: `docs/publications/results/PUB-GC-TRANSIENT-SCREEN-0001.yaml`, commit `b08db7dab78681a60d4df9e589e6db30ba8d9b86`;
- H2 and H3 remain untested by primary evidence;
- next permitted action: freeze a separate scientific design decision before adding or reformulating any stress family.

### 2026-09-18T00:16Z — PUB-GC E2/E3 temporal-scale design adjudicated

- decision: `docs/publications/decisions/PUB-GC_E2_E3_MACRO_WINDOW_ADJUDICATION.md`, commit `29f3bf635d69e076926d6cb99cf3f7d058f67a63`;
- source-semantic finding: a single accepted native SWAP full step reports `Q_step = q_terminal * delta_t` by construction, while the qualified two-half route sums both half-step exchanges and retains the final half-step terminal flux;
- experimental consequence: the prior one-transaction-per-coupling-window design can make E2 algebraically unidentifiable and makes H3 refinement simultaneously alter coupling-window duration and native SWAP integration interval;
- scientific decision: future E2/E3 work separates external coupling macro-window `DeltaT_c` from native SWAP integration intervals `delta_t_j`;
- whole-window response will be the sum of native exchange contributions across a disposable same-origin macro-candidate trajectory; the terminal comparator remains final native terminal rate times the full macro-window duration;
- principal H3 comparisons must vary coupling-window duration under a separately frozen internal-integration policy;
- existing screening and reference results are preserved as supporting evidence and are not retroactively promoted;
- next permitted action: freeze and qualify a research-only macro-window response component before new E2/E3 screening;
- cross-publication firewall: no response/tangent acceleration claim is introduced; those remain `PUB-RC`.


### 2026-09-18T00:30:40Z — PUB-GC macro-window SWAP response qualified

- frozen design decision: `docs/publications/decisions/PUB-GC_E2_E3_MACRO_WINDOW_ADJUDICATION.md`, commit `29f3bf635d69e076926d6cb99cf3f7d058f67a63`;
- frozen specification: `PUB-GC_MACRO_WINDOW_RESPONSE_SPEC.md`, commit `1b54c6c6acfffd8bd71c368ae36bdf77f788850b`, blob `e7b042300c67e06163cbb27a603dc1ab70fa1834`;
- frozen qualification manifest: `PUB-GC-MACRO-WINDOW-QUAL-0001`, commit `8a688bf44addd8afee3977cce625c4ebaf1aa81b`, blob `09987670ad420e021fad5cb5e3b486b44c85f326`;
- qualified research head: `research/pub-gc-macro-window-response@32d1e9ae1bb3f0cda7a26e114eca0fe5fd900d12`;
- controlling PASS execution: GitHub Actions run `35291452130`, job `105434979678`, GNU Fortran 13.3.0;
- exact O0/O2 scientific-output identity: PASS; output SHA-256 `fcd7e241ba5495deed98e007d4547fc4f40be0b93f4988f0cbd4c2fa68d1373f`;
- artifact `10526361147`, digest `sha256:09758165fa673021dbb2d881abef4f1851c41caf0b9af500a1ef9c25dd07c1a1`;
- immutable qualified blobs: module `920b93b943ead1187887e683c50a84e0f4cb3a46`, test `5045dc35c253b6063229f8843452c21c2c8178c1`, runner `4114e5624480ad056aa25e298e75fa3f2e58d654`, workflow `233819d9f74ddd914f7b6a0effe6d2bb7f7ddba9`;
- frozen production source tree remained `d7ef6c045263de821db7800459289efcd8a6420b`; all previously qualified publication dependencies remained unchanged;
- Q0 one-step reduction, Q1 sequential equivalence, Q2 aggregate/terminal selectivity, Q3 A/B/A same-origin replay, Q5 continuation-history preservation, failure controls and O0/O2 identity all PASS;
- Q2 qualification-only telemetry demonstrated a nonzero distinction between `Q_whole` and `q_terminal*DeltaT_c`, but its magnitude is permanently excluded from H2/H3 primary estimation and case tuning;
- invalid predecessor run `35291116752` never compiled due a qualification-test declaration defect; invalid predecessor run `35291389064` used a literal-duration bitwise oracle inconsistent with the already frozen macro-duration definition; neither carries scientific inference and neither changed a fixture, threshold or scientific criterion;
- result receipt: `docs/publications/results/PUB-GC-MACRO-WINDOW-QUAL-0001.yaml`, introduced by commit `2b20b016a9512676f66f20c134521a381d3d13c7`;
- prerequisite newly satisfied: native SWAP responses can now be composed inside a disposable external coupling macro-window with independently observable integrated and terminal interface quantities;
- H2 and H3 remain untested by primary evidence;
- next permitted action: freeze and execute `PUB-GC-NATIVE-TIME-0001`, selecting a native SWAP internal-integration policy from endpoint-state and integrated-exchange convergence only; terminal-surrogate mismatch must not be a selection objective;
- cross-publication firewall: no PUB-RC tangent/acceleration claim, PUB-SQ solver claim, PUB-ME architecture claim or PUB-SG upscaling claim is created.


### 2026-09-18T00:36:15Z — PUB-GC native-time study returned NO_POLICY_SELECTED

- frozen specification: `PUB-GC_NATIVE_TIME_SPEC.md`, commit `9d8528af50bfa8450e5ec731bfdd47f7cd6c83d1`, blob `5f563ca26d602a56fdd82419265fa1bfea63399e`;
- frozen manifest: `PUB-GC-NATIVE-TIME-0001`, commit `e553ca282a31f221a23f9291c5670e73f3455b06`, blob `19c98e4ae7f97d029c9ce2d42d0fe4104a54f0bd`;
- execution: `research/pub-gc-native-time@6ad2c56c0e75a4b220e88b64510795a12f162285`, GitHub Actions run `35291849037`, job `105436176829`, conclusion `success`;
- exact O0/O2 scientific-output identity: PASS; output SHA-256 `2335cac984006f397cea843e5d23f909d68acabe109965e08139ff9df0c2259e`;
- artifact `10526451569`, digest `sha256:1a8234d76fc9924e8dd8fb3de74b4a8e99d03714099345ddf03a951bc393d58d`;
- N0 (0.01 d) and N1 (0.005 d) executed for all five frozen cases; N2 (0.0025 d) and N3 (0.00125 d) returned `PUB_GC_MACRO_INVALID` for all five cases;
- mechanical outcome: `NO_POLICY_SELECTED`; all-trajectories-valid = false; fine-level guard = false; no case, threshold or selection rule was changed after execution;
- root-cause adjudication: the research macro component advances absolute time by repeated `t1=t0+dt` and requires final `abs(t0-macro_t1)<=1e-12 d`; at macro origin 4200.125 d the repeated-addition closure errors are about `-6.37e-12 d` for 16 contributions and `+8.19e-12 d` for 32 contributions, while 4/8 contributions remain within the guard;
- scientific consequence: this is a time-coordinate/research-infrastructure envelope limit, not a Richards/native-SWAP physics failure; N0/N1 are **not** admitted as adequate simply because they ran;
- result receipt: `docs/publications/results/PUB-GC-NATIVE-TIME-0001.yaml`, introduced by commit `a7c89350305efc6019b469896782f4f91b5ba7e6`;
- H2/H3 remain untested;
- next permitted action: freeze a separate macro temporal-coordinate decision, requalify the research-only macro response under a new qualification ID, then preregister a new native-time study ID; do not overwrite or rerun NATIVE-TIME-0001 as though it had passed.
