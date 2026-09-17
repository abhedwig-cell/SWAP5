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
| `PUB-GC-E2` whole-window vs terminal flux | PUB-GC | primary | DESIGNED | qualified GW-A is available; define and qualify a fair terminal-flux comparator with all non-exchange semantics matched |
| `PUB-GC-E3` window convergence | PUB-GC | primary | BLOCKED | qualified GW-A is available; converged replay method + `GC-REF` construction still required |
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
- `PUB-GC-E1-HARNESS`: reconcile the qualified real-SWAP prescribed-head/checkpoint execution surfaces, then implement the two origin policies in research-only code without modifying production semantics;
- `PUB-GC-GC-REF`: define the strict coupling reference procedure after the E1 harness boundary is qualified;
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
