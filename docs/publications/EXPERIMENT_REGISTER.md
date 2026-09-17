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
| `PUB-GC-E1` same-origin replay | PUB-GC | primary | READY_FOR_SCREENING | real-SWAP origin-policy harness qualified by `PUB-GC-E1-HARNESS-QUAL-0001`; perform separately labelled transient screening within the frozen broad bounds, then freeze the exact case/candidate sequence before primary E1 preregistration |
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

## Register update rule

Whenever a run family changes status, record:

- date/time;
- controlling commit;
- prerequisite newly satisfied or invalidated;
- next permitted action;
- whether the change affects another publication line.

The register should describe readiness, not rewrite past chronology.
